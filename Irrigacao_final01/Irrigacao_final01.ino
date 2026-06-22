#include <Wire.h>
#include "RTClib.h"
#include <ArduinoJson.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <string>

// Definição dos pinos
#define RTC_ERROR_LED_PIN 2

// UUIDs do serviço BLE
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Objetos BLE e flags
BLEServer* pServer = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Variáveis do RTC
bool rtcFound = false;
unsigned long lastBlinkTime = 0;
const long BLINK_INTERVAL = 2000;

// CONSTANTES DO SISTEMA
const float ML_POR_SEGUNDO         = 9.0;
const int   UMIDADE_LIMITE_SECO    = 3000;
const int   HORA_INICIO_IRRIGACAO  = 22;
const int   HORA_FIM_IRRIGACAO     = 6;

// Pausa entre o fim de uma irrigação e o início da próxima.
const unsigned long PAUSA_ENTRE_IRRIGACOES_MS = 2000;
unsigned long ultimaIrrigacaoConcluida = 0;

// Configuração do número máximo de plantas
#define MAX_PLANTAS 5
#define TAM_NOME    16

struct Planta {
  char nome[TAM_NOME];
  int quantidadeAgua_ml;       
  int tempoRega_intervalo;
  DateTime ultimaRega;
  int sensorPin;
  int pumpPin;
  bool isIrrigating;
  unsigned long irrigationStartTime;
  int irrigationDuration;
};

Planta plantas[MAX_PLANTAS];
int totalPlantas = 0;

const int SENSOR_PINS[MAX_PLANTAS] = {34, 35, 32, 33, 25};
const int PUMP_PINS[MAX_PLANTAS]   = {16, 18, 17, 19, 23};

RTC_DS3231 rtc;

// Protótipos
void processJsonCommand(std::string command);
void verificarIrrigacao();
void irrigar(Planta &planta);
bool algumIrrigando();

// CALLBACKS DO BLUETOOTH
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
    };
    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
    }
};

class MyCharacteristicCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String rxValueString = pCharacteristic->getValue();
    std::string rxValueStd = rxValueString.c_str();
    if (rxValueStd.length() > 0) {
      processJsonCommand(rxValueStd);
    }
  }
};

// FUNÇÕES DE RESPOSTA JSON
void sendJsonResponse(const JsonDocument& doc) {
  if (deviceConnected) {
    String jsonString;
    serializeJson(doc, jsonString);
    pCharacteristic->setValue(jsonString.c_str());
    pCharacteristic->notify();
  }
}

void sendErrorResponse(const char* action, const char* message) {
  DynamicJsonDocument doc(256);
  doc["status"]  = "ERROR";
  doc["action"]  = action;
  doc["message"] = message;
  sendJsonResponse(doc);
}

void sendSuccessResponse(const char* action, const char* message) {
  DynamicJsonDocument doc(256);
  doc["status"]  = "SUCCESS";
  doc["action"]  = action;
  doc["message"] = message;
  sendJsonResponse(doc);
}

// AÇÃO: CRIAR PLANTA
void handleCreatePlant(const JsonObject& payload) {
  if (totalPlantas >= MAX_PLANTAS) {
    sendErrorResponse("CREATE_PLANT", "Limite de plantas atingido");
    return;
  }
  const char* nome = payload["name"];
  if (!nome || strlen(nome) >= TAM_NOME) {
    sendErrorResponse("CREATE_PLANT", "Nome inválido ou longo");
    return;
  }

  strncpy(plantas[totalPlantas].nome, nome, TAM_NOME - 1);
  plantas[totalPlantas].nome[TAM_NOME - 1] = '\0';

  // Recebe water_ml (volume em mililitros) enviado pelo app
  plantas[totalPlantas].quantidadeAgua_ml  = payload["water_ml"];
  plantas[totalPlantas].tempoRega_intervalo = payload["interval_h"];
  plantas[totalPlantas].pumpPin            = PUMP_PINS[totalPlantas];
  plantas[totalPlantas].isIrrigating       = false;

  plantas[totalPlantas].sensorPin = SENSOR_PINS[totalPlantas];
  pinMode(plantas[totalPlantas].sensorPin, INPUT);

  pinMode(plantas[totalPlantas].pumpPin, OUTPUT);
  digitalWrite(plantas[totalPlantas].pumpPin, LOW);

  // MODO DE DEMONSTRAÇÃO: intervalo em segundos
  TimeSpan intervalo = TimeSpan(plantas[totalPlantas].tempoRega_intervalo);
  plantas[totalPlantas].ultimaRega = rtc.now() - intervalo;

  totalPlantas++;
  sendSuccessResponse("CREATE_PLANT", "Planta cadastrada!");
}

// AÇÃO: DELETAR PLANTA
void handleDeletePlant(const JsonObject& payload) {
  const char* nomeBusca = payload["name"];
  if (!nomeBusca) {
    sendErrorResponse("DELETE_PLANT", "Nome da planta não fornecido.");
    return;
  }

  int indexToDelete = -1;
  for (int i = 0; i < totalPlantas; i++) {
    if (strcmp(nomeBusca, plantas[i].nome) == 0) {
      indexToDelete = i;
      break;
    }
  }

  if (indexToDelete != -1) {
    if (plantas[indexToDelete].isIrrigating) {
      digitalWrite(plantas[indexToDelete].pumpPin, LOW);
    }
    for (int i = indexToDelete; i < totalPlantas - 1; i++) {
      plantas[i] = plantas[i + 1];
    }
    totalPlantas--;
    Serial.printf("Planta '%s' deletada com sucesso.\n", nomeBusca);
    sendSuccessResponse("DELETE_PLANT", "Planta deletada!");
  } else {
    Serial.printf("Erro: Planta '%s' não encontrada.\n", nomeBusca);
    sendErrorResponse("DELETE_PLANT", "Planta não encontrada.");
  }
}

// AÇÃO: LISTAR PLANTAS
void handleGetPlantList(const JsonObject& payload) {
  DynamicJsonDocument doc(3000);
  doc["status"] = "SUCCESS";
  doc["action"] = "GET_PLANT_LIST";
  doc["rtc_ok"] = rtcFound;
  JsonArray plantsArray = doc.createNestedArray("payload");
  for (int i = 0; i < totalPlantas; i++) {
    JsonObject plantObj = plantsArray.createNestedObject();
    plantObj["name"]               = plantas[i].nome;
    plantObj["water_ml"]           = plantas[i].quantidadeAgua_ml;  
    plantObj["interval_h"]         = plantas[i].tempoRega_intervalo;
    plantObj["last_irrigation_ts"] = plantas[i].ultimaRega.unixtime();
    plantObj["humidity_raw"]       = analogRead(plantas[i].sensorPin);
    plantObj["is_irrigating"]      = plantas[i].isIrrigating;
  }
  sendJsonResponse(doc);
}

// AÇÃO: CONFIGURAR RTC
void handleConfigureRtc(const JsonObject& payload) {
  long timestamp = payload["timestamp"];
  rtc.adjust(DateTime(timestamp));
  rtcFound = true;
  digitalWrite(RTC_ERROR_LED_PIN, LOW);
  sendSuccessResponse("CONFIGURE_RTC", "RTC configurado!");
}

// PROCESSAMENTO DO COMANDO JSON RECEBIDO VIA BLE
void processJsonCommand(std::string command) {
  DynamicJsonDocument doc(512);
  DeserializationError error = deserializeJson(doc, command);
  if (error) {
    sendErrorResponse("UNKNOWN", "Comando JSON inválido.");
    return;
  }
  const char* action   = doc["action"];
  JsonObject  payload  = doc["payload"];

  if      (strcmp(action, "CREATE_PLANT")  == 0) handleCreatePlant(payload);
  else if (strcmp(action, "DELETE_PLANT")  == 0) handleDeletePlant(payload);
  else if (strcmp(action, "GET_PLANT_LIST")== 0) handleGetPlantList(payload);
  else if (strcmp(action, "CONFIGURE_RTC") == 0) handleConfigureRtc(payload);
  else sendErrorResponse(action, "Ação desconhecida.");
}

// LÓGICA DE IRRIGAÇÃO
void irrigar(Planta &planta) {
  if (planta.pumpPin == -1) {
    Serial.printf("ERRO: Planta %s sem pino de bomba válido.\n", planta.nome);
    return;
  }
  int tempoRega_seg = (int)(planta.quantidadeAgua_ml / ML_POR_SEGUNDO);
  Serial.printf("Irrigando '%s': %d ml → %d segundos (válvula GPIO %d)\n",
                planta.nome, planta.quantidadeAgua_ml, tempoRega_seg, planta.pumpPin);

  digitalWrite(planta.pumpPin, HIGH);
  planta.isIrrigating       = true;
  planta.irrigationStartTime = millis();
  planta.irrigationDuration  = tempoRega_seg;
}

// FILA SEQUENCIAL DE IRRIGAÇÃO
bool algumIrrigando() {
  for (int i = 0; i < totalPlantas; i++) {
    if (plantas[i].isIrrigating) return true;
  }
  return false;
}


// VERIFICAÇÃO DO CICLO DE IRRIGAÇÃO
void verificarIrrigacao() {
  if (!rtcFound || totalPlantas == 0) return;

  // FILA SEQUENCIAL: se qualquer válvula estiver aberta, aguarda.
  if (algumIrrigando()) return;

  // PAUSA PÓS-IRRIGAÇÃO: aguarda o circuito estabilizar após o fechamento da última válvula antes de abrir uma nova.
  if (millis() - ultimaIrrigacaoConcluida < PAUSA_ENTRE_IRRIGACOES_MS) return;

  // MODO PRODUÇÃO: descomentar o bloco abaixo para restringir a irrigação à janela horária configurada
  /*
  DateTime agora     = rtc.now();
  int      horaAtual = agora.hour();
  bool     horarioBom = (horaAtual >= HORA_INICIO_IRRIGACAO ||
                         horaAtual < HORA_FIM_IRRIGACAO);
  if (!horarioBom) return;
  */

  for (int i = 0; i < totalPlantas; i++) {
    DateTime agora = rtc.now();
    TimeSpan diff  = agora - plantas[i].ultimaRega;

    // Condição 2: intervalo de tempo decorrido
    if (diff.totalseconds() >= plantas[i].tempoRega_intervalo) {

      // Condição 3: solo seco
      int umidadeSolo = analogRead(plantas[i].sensorPin);
      Serial.printf("Sensor planta '%s' (GPIO %d): %d (limiar: %d)\n",
                    plantas[i].nome, plantas[i].sensorPin,
                    umidadeSolo, UMIDADE_LIMITE_SECO);

      if (umidadeSolo > UMIDADE_LIMITE_SECO) {
        irrigar(plantas[i]);
        // Inicia apenas uma irrigação por ciclo de verificação.
        // As demais plantas aguardam o próximo ciclo (fila sequencial).
        return;
      }
    }
  }
}

// SETUP
void setup() {
  Serial.begin(115200);
  Serial.println("\n--- Irrigador Inteligente (MODO DEMONSTRAÇÃO) ---");
  Serial.printf("Taxa de vazão: %.1f ml/s\n", ML_POR_SEGUNDO);
  Serial.printf("Capacidade máxima: %d plantas\n", MAX_PLANTAS);

  // Inicializa BLE
  BLEDevice::init("ESP32_IRRIGADOR");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_WRITE  |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
  pCharacteristic->addDescriptor(new BLE2902());
  pCharacteristic->setCallbacks(new MyCharacteristicCallbacks());
  pService->start();
  BLEDevice::startAdvertising();
  Serial.println("BLE: aguardando conexão...");

  // Inicializa RTC
  Wire.begin(21, 22);
  pinMode(RTC_ERROR_LED_PIN, OUTPUT);
  if (!rtc.begin()) {
    Serial.println("ERRO: RTC não encontrado no barramento I²C!");
    rtcFound = false;
  } else if (rtc.lostPower()) {
    Serial.println("ERRO: RTC perdeu energia — hora não confiável!");
    Serial.println("Sincronize o RTC pelo aplicativo para continuar.");
    rtcFound = false;
  } else {
    Serial.println("RTC: OK.");
    rtcFound = true;
  }
  for (int i = 0; i < MAX_PLANTAS; i++) {
    pinMode(PUMP_PINS[i], OUTPUT);
    digitalWrite(PUMP_PINS[i], LOW);
  }

  Serial.println("Setup concluído.");
}

// LOOP PRINCIPAL
void loop() {
  // Reinicia advertising ao desconectar
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
  }
  oldDeviceConnected = deviceConnected;
.
  if (!rtcFound) {
    if (millis() - lastBlinkTime >= BLINK_INTERVAL) {
      lastBlinkTime = millis();
      digitalWrite(RTC_ERROR_LED_PIN, !digitalRead(RTC_ERROR_LED_PIN));
    }
  }

  // Verifica condições de irrigação para cada planta
  verificarIrrigacao();

  // Controla o encerramento das irrigações em andamento
  for (int i = 0; i < totalPlantas; i++) {
    if (plantas[i].isIrrigating) {
      if (millis() - plantas[i].irrigationStartTime >=
          (unsigned long)plantas[i].irrigationDuration * 1000UL) {
        digitalWrite(plantas[i].pumpPin, LOW);
        plantas[i].isIrrigating = false;
        plantas[i].ultimaRega   = rtc.now();
        ultimaIrrigacaoConcluida = millis();
        Serial.printf("Irrigação de '%s' concluída. Aguardando %lums antes da próxima.\n",
                      plantas[i].nome, PAUSA_ENTRE_IRRIGACOES_MS);
      }
    }
  }

  delay(1000);
}
