class RelayDevice {
  final String name;
  final String ipAddress;
  final int signalStrength; // RSSI в дБ
  final List<Relay> relays;
  final Map<String, dynamic>?
  rawData; // Добавляем поле для хранения исходных данных

  RelayDevice({
    required this.name,
    required this.ipAddress,
    this.signalStrength = 0,
    required this.relays,
    this.rawData,
  });

  factory RelayDevice.fromJson(Map<String, dynamic> json) {
    List<dynamic>? relaysJson = json['relays'] as List<dynamic>?;
    List<Relay> relaysList = [];

    if (relaysJson != null) {
      relaysList = relaysJson.map((relay) => Relay.fromJson(relay)).toList();
    } else {
      // Совместимость со старой версией API (одно реле)
      relaysList = [Relay(id: 0, name: 'Реле', isOn: json['relay'] == 'on')];
    }

    return RelayDevice(
      name: json['name'] ?? 'Smart Relay',
      ipAddress: json['ip'] ?? '0.0.0.0',
      signalStrength: json['rssi'] ?? 0,
      relays: relaysList,
      rawData: json, // Сохраняем исходные данные
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ip': ipAddress,
      'rssi': signalStrength,
      'relays': relays.map((relay) => relay.toJson()).toList(),
    };
  }

  // Проверка, есть ли хотя бы одно активное реле
  bool get hasActiveRelays => relays.any((relay) => relay.isOn);

  // Получение количества активных реле
  int get activeRelaysCount => relays.where((relay) => relay.isOn).length;

  // Проверка поддержки сценариев устройством
  bool get supportsScenarios {
    if (rawData == null ||
        !rawData!.containsKey('scenarios') ||
        rawData!['scenarios'] is! Map) {
      return false;
    }

    final scenarios = rawData!['scenarios'] as Map;
    return scenarios.containsKey('supported') && scenarios['supported'] == true;
  }

  // Проверка, выполняется ли сценарий на устройстве
  bool get isRunningScenario {
    if (!supportsScenarios) return false;

    final scenarios = rawData!['scenarios'] as Map;
    return scenarios.containsKey('running') && scenarios['running'] == true;
  }

  // Получение прогресса выполнения сценария (0-100)
  int get scenarioProgress {
    if (!isRunningScenario) return 0;

    final scenarios = rawData!['scenarios'] as Map;
    return scenarios.containsKey('progress')
        ? (scenarios['progress'] as num).toInt()
        : 0;
  }
}

class Relay {
  final int id;
  final String name;
  bool isOn;

  Relay({required this.id, required this.name, this.isOn = false});

  factory Relay.fromJson(Map<String, dynamic> json) {
    // Улучшенная защитная проверка имени реле
    String name = '';
    try {
      if (json['name'] != null) {
        name = json['name'].toString();

        // Более строгая проверка невалидных имен
        if (name.trim().isEmpty || name == "_" || name == "undefined") {
          name = 'Реле ${json['id'] + 1}';
        }
      } else {
        name = 'Реле ${json['id'] + 1}';
      }
    } catch (e) {
      print('Error parsing relay name: $e');
      name = 'Реле ${json['id'] + 1}';
    }

    return Relay(id: json['id'] ?? 0, name: name, isOn: json['state'] == 'on');
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'state': isOn ? 'on' : 'off'};
  }
}
