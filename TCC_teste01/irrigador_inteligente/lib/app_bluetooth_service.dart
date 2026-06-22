// lib/app_bluetooth_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:irrigador_inteligente/models.dart';

class AppBluetoothService extends ChangeNotifier {
  // --- Propriedades de Estado ---
  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothCharacteristic? _targetCharacteristic;
  StreamSubscription<List<int>>? _valueSubscription;
  StreamSubscription<fbp.BluetoothConnectionState>? _connectionStateSubscription;

  bool _isConnected = false;
  String _deviceName = "Nenhum";
  List<fbp.BluetoothDevice> _availableDevices = [];
  List<Plant> _plants = [];
  String? _statusMessage; // <-- AQUI ESTÁ A VARIÁVEL QUE FALTAVA
  bool _isRtcOk = true; // <-- E ESTA TAMBÉM

  // --- Constantes ---
  final String serviceUUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String characteristicUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // --- Getters para a UI ---
  bool get isConnected => _isConnected;
  String get deviceName => _deviceName;
  List<fbp.BluetoothDevice> get availableDevices => _availableDevices;
  List<Plant> get plants => _plants;
  String? get statusMessage => _statusMessage; // <-- SEU GETTER
  bool get isRtcOk => _isRtcOk; // <-- E SEU GETTER

  // --- Padrão Singleton ---
  static final AppBluetoothService _instance = AppBluetoothService._internal();
  factory AppBluetoothService() => _instance;
  AppBluetoothService._internal();

  // --- AQUI ESTÁ O MÉTODO QUE FALTAVA ---
  void clearStatusMessage() {
    _statusMessage = null;
    notifyListeners();
  }

  Future<void> startScan() async {
    _availableDevices.clear();
    notifyListeners();
    try {
      await fbp.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
        androidUsesFineLocation: true,
      );
      fbp.FlutterBluePlus.scanResults.listen((results) {
        for (fbp.ScanResult result in results) {
          if (result.device.platformName.isNotEmpty && !_availableDevices.any((d) => d.remoteId == result.device.remoteId)) {
            _availableDevices.add(result.device);
          }
        }
        notifyListeners();
      });
    } catch (e) {
      _statusMessage = "Erro ao escanear: ${e.toString()}";
      notifyListeners();
    }
  }

  Future<void> connectToDevice(fbp.BluetoothDevice device) async {
    await fbp.FlutterBluePlus.stopScan();
    try {
      await device.connect(timeout: const Duration(seconds: 15));
    } catch (e) {
      _statusMessage = "Erro ao conectar: ${e.toString()}";
      notifyListeners();
      return;
    }

    _connectedDevice = device;
    _listenToConnectionState();

    try {
      List<fbp.BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUUID) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() == characteristicUUID) {
              _targetCharacteristic = char;
              break;
            }
          }
        }
      }

      if (_targetCharacteristic != null) {
        await _targetCharacteristic!.setNotifyValue(true);
        _valueSubscription = _targetCharacteristic!.onValueReceived.listen(_onDataReceived);
        _isConnected = true;
        _deviceName = device.platformName.isNotEmpty ? device.platformName : 'Dispositivo';
        _statusMessage = "Conectado com sucesso!";
        await requestPlantsList();
      } else {
        _statusMessage = "Característica BLE não encontrada!";
        await disconnect();
      }
    } catch (e) {
      _statusMessage = "Erro ao descobrir serviços: ${e.toString()}";
      await disconnect();
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _valueSubscription?.cancel();
    await _connectionStateSubscription?.cancel();
    _valueSubscription = null;
    _connectionStateSubscription = null;
    await _connectedDevice?.disconnect();
    _isConnected = false;
    _deviceName = "Nenhum";
    _plants.clear();
    _statusMessage = "Desconectado.";
    _connectedDevice = null;
    _targetCharacteristic = null;
    notifyListeners();
  }

  void _listenToConnectionState() {
    _connectionStateSubscription = _connectedDevice?.connectionState.listen((state) {
      if (state == fbp.BluetoothConnectionState.disconnected) {
        if (_isConnected) {
          disconnect();
        }
      }
    });
  }

  void _onDataReceived(List<int> data) {
    if (data.isEmpty) return;
    final message = utf8.decode(data);
    print("JSON Recebido do ESP32: $message");
    try {
      final jsonResponse = jsonDecode(message) as Map<String, dynamic>;
      final status = jsonResponse['status'] as String?;
      final action = jsonResponse['action'] as String?;
      final responseMessage = jsonResponse['message'] as String?;
      final payload = jsonResponse['payload'];

      if (status == 'SUCCESS') {
        _statusMessage = responseMessage ?? "Operação realizada com sucesso!";
        if (action == 'GET_PLANT_LIST' && payload != null) {
          final List<dynamic> jsonList = payload as List<dynamic>;
          _plants = jsonList.map((json) => Plant.fromJson(json)).toList();
        }
      } else if (status == 'ERROR') {
        _statusMessage = "Erro no ESP32: ${responseMessage ?? 'Desconhecido'}";
        if (action == "RTC_ERROR") {
          _isRtcOk = false;
        }
      }
    } catch (e) {
      _statusMessage = "Erro: Resposta inválida do dispositivo.";
      print("Falha ao decodificar JSON: $e");
    }
    notifyListeners();
  }

  Future<void> _sendCommand(Map<String, dynamic> command) async {
    if (_targetCharacteristic == null || !_isConnected) {
      _statusMessage = "Não conectado. Impossível enviar comando.";
      notifyListeners();
      return;
    }
    try {
      final jsonCommand = jsonEncode(command);
      print("Enviando JSON para ESP32: $jsonCommand");
      await _targetCharacteristic!.write(utf8.encode(jsonCommand));
    } catch (e) {
      _statusMessage = "Erro ao enviar dados: ${e.toString()}";
      notifyListeners();
    }
  }

  Future<void> requestPlantsList() async {
    await _sendCommand({'action': 'GET_PLANT_LIST'});
  }

  Future<void> createPlant({
    required String name,
    required int waterAmount,
    required int interval,
  }) async {
    await _sendCommand({
      'action': 'CREATE_PLANT',
      'payload': {
        'name': name,
        'water_mm': waterAmount,
        'interval_h': interval,
      }
    });
    await Future.delayed(const Duration(milliseconds: 500));
    await requestPlantsList();
  }
  
  Future<void> deletePlant(String plantName) async {
    await _sendCommand({
      'action': 'DELETE_PLANT',
      'payload': {'name': plantName}
    });
    await Future.delayed(const Duration(milliseconds: 500));
    await requestPlantsList();
  }
  
  // --- E FINALMENTE, O MÉTODO `configureRtc` QUE FALTAVA ---
  Future<void> configureRtc() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _sendCommand({
      'action': 'CONFIGURE_RTC',
      'payload': {'timestamp': timestamp}
    });
  }
}