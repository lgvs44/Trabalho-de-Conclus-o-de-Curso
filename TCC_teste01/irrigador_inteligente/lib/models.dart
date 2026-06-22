// @dart=2.17
import 'package:intl/intl.dart';

class Plant {
  String name;
  int waterAmountMm;
  int irrigationIntervalHours;
  DateTime lastIrrigation;
  int sensorPin;
  int pumpPin;
  bool isIrrigating;
  int currentHumidityRaw; // Valor bruto do sensor de umidade

  Plant({
    required this.name,
    required this.waterAmountMm,
    required this.irrigationIntervalHours,
    required this.lastIrrigation,
    required this.sensorPin,
    required this.pumpPin,
    this.isIrrigating = false,
    this.currentHumidityRaw = 0,
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      name: json['name'] as String,
      waterAmountMm: json['water_mm'] as int,
      irrigationIntervalHours: json['interval_h'] as int,
      lastIrrigation: DateTime.fromMillisecondsSinceEpoch(
          (json['last_irrigation_ts'] as int? ?? 0) * 1000), // Unix timestamp em segundos
      isIrrigating: json['is_irrigating'] as bool? ?? false,
      currentHumidityRaw: json['humidity_raw'] as int? ?? 0,
      // Pins não precisam vir do ESP32 para o app
      sensorPin: 0, 
      pumpPin: 0,
    );
  }

  double get humidityPercentage {
    const int dryValue = 4095; // Valor máximo (seco) para ESP32 ADC (12-bit)
    const int wetValue = 1000; // Valor mínimo (úmido) para ESP32 ADC

    if (currentHumidityRaw <= wetValue) return 100.0;
    if (currentHumidityRaw >= dryValue) return 0.0;

    return ((dryValue - currentHumidityRaw) / (dryValue - wetValue)) * 100.0;
  }

  Duration get timeUntilNextIrrigation {
    final nextIrrigationTime =
        lastIrrigation.add(Duration(hours: irrigationIntervalHours));
    final now = DateTime.now();
    if (nextIrrigationTime.isBefore(now)) {
      return Duration.zero;
    }
    return nextIrrigationTime.difference(now);
  }

  String get formattedTimeUntilNextIrrigation {
    final duration = timeUntilNextIrrigation;
    if (duration == Duration.zero) {
      return 'Agora!';
    }
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitHours = twoDigits(duration.inHours.remainder(24));
    String twoDigitDays = twoDigits(duration.inDays);

    if (duration.inDays > 0) {
      return '$twoDigitDays dias, $twoDigitHours horas';
    } else if (duration.inHours > 0) {
      return '$twoDigitHours horas, $twoDigitMinutes min';
    } else {
      return '$twoDigitMinutes min';
    }
  }

  String get formattedLastIrrigation {
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(lastIrrigation);
  }
}

enum ErrorCode {
  INVALID_OPTION(1),
  PLANT_LIMIT_REACHED(2),
  INVALID_QA_FORMAT(3),
  INVALID_BLUETOOTH_COMMAND(4),
  PLANT_NOT_FOUND(5),
  INVALID_RTC_FORMAT(6),
  INTERNAL(7),
  RTC_NOT_FOUND(8);

  final int code;
  const ErrorCode(this.code);

  factory ErrorCode.fromCode(int code) {
    return ErrorCode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ErrorCode.INTERNAL,
    );
  }

  String get message {
    switch (this) {
      case ErrorCode.INVALID_OPTION:
        return "Opção de menu inválida.";
      case ErrorCode.PLANT_LIMIT_REACHED:
        return "Limite máximo de plantas atingido.";
      case ErrorCode.INVALID_QA_FORMAT:
        return "Formato QA incorreto (ex: QA100T24).";
      case ErrorCode.INVALID_BLUETOOTH_COMMAND:
        return "Comando Bluetooth inválido.";
      case ErrorCode.PLANT_NOT_FOUND:
        return "Planta não encontrada.";
      case ErrorCode.INVALID_RTC_FORMAT:
        return "Formato de data/hora do RTC inválido (YYYYMMDDHHMMSS).";
      case ErrorCode.INTERNAL:
        return "Erro interno no ESP32.";
      case ErrorCode.RTC_NOT_FOUND:
        return "RTC não encontrado ou desconectado.";
      default:
        return "Erro desconhecido.";
    }
  }
}
