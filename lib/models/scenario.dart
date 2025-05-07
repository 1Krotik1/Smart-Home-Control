import 'package:flutter/material.dart';

class Scenario {
  final String id;
  final String name;
  final String description;
  final List<ScenarioAction> actions;
  final bool isActive;
  final DateTime? lastRun;
  final Color color;
  final int iconCodePoint;
  final String iconFontFamily;
  
  const Scenario({
    required this.id,
    required this.name,
    required this.description,
    required this.actions,
    required this.isActive,
    required this.color,
    this.lastRun,
    this.iconCodePoint = 0xe0f7, // Icons.auto_awesome.codePoint
    this.iconFontFamily = 'MaterialIcons',
  });

  // Геттер для получения IconData
  IconData get icon => IconData(iconCodePoint, fontFamily: iconFontFamily);
  
  // Метод для создания виджета иконки с заданными параметрами
  Widget iconWidget({Color? color, double? size}) {
    return Icon(
      icon,
      color: color,
      size: size,
    );
  }

  Scenario copyWith({
    String? id,
    String? name,
    String? description,
    List<ScenarioAction>? actions,
    bool? isActive,
    DateTime? lastRun,
    Color? color,
    int? iconCodePoint,
    String? iconFontFamily,
  }) {
    return Scenario(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      actions: actions ?? this.actions,
      isActive: isActive ?? this.isActive,
      lastRun: lastRun ?? this.lastRun,
      color: color ?? this.color,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'actions': actions.map((a) => a.toJson()).toList(),
    'isActive': isActive,
    'lastRun': lastRun?.toIso8601String(),
    'color': color.value,
    'iconCodePoint': iconCodePoint,
    'iconFontFamily': iconFontFamily,
  };

  factory Scenario.fromJson(Map<String, dynamic> json) => Scenario(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    actions: (json['actions'] as List)
        .map((a) => ScenarioAction.fromJson(a))
        .toList(),
    isActive: json['isActive'] as bool,
    lastRun: json['lastRun'] != null
        ? DateTime.parse(json['lastRun'])
        : null,
    color: Color(json['color'] as int),
    iconCodePoint: json['iconCodePoint'] as int? ?? 0xe0f7,
    iconFontFamily: json['iconFontFamily'] as String? ?? 'MaterialIcons',
  );
}

class ScenarioAction {
  final String id;
  final String deviceIp;
  final String deviceName;
  final int relayId;
  final String relayName;
  final bool turnOn;
  final bool isActive;
  final Duration? delay;

  ScenarioAction({
    required this.id,
    required this.deviceIp,
    required this.deviceName,
    required this.relayId,
    required this.relayName,
    required this.turnOn,
    this.isActive = true,
    this.delay,
  });

  /// Конструктор для создания копии с измененными параметрами
  ScenarioAction copyWith({
    String? deviceIp,
    String? deviceName,
    int? relayId,
    String? relayName,
    bool? turnOn,
    bool? isActive,
    Duration? delay,
  }) {
    return ScenarioAction(
      id: id,
      deviceIp: deviceIp ?? this.deviceIp,
      deviceName: deviceName ?? this.deviceName,
      relayId: relayId ?? this.relayId,
      relayName: relayName ?? this.relayName,
      turnOn: turnOn ?? this.turnOn,
      isActive: isActive ?? this.isActive,
      delay: delay ?? this.delay,
    );
  }

  /// Создание действия из JSON
  factory ScenarioAction.fromJson(Map<String, dynamic> json) {
    return ScenarioAction(
      id: json['id'] as String,
      deviceIp: json['deviceIp'] as String,
      deviceName: json['deviceName'] as String,
      relayId: json['relayId'] as int,
      relayName: json['relayName'] as String,
      turnOn: json['turnOn'] as bool,
      isActive: json['isActive'] as bool,
      delay:
          json['delayMs'] != null
              ? Duration(milliseconds: json['delayMs'] as int)
              : null,
    );
  }

  /// Преобразование действия в JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceIp': deviceIp,
      'deviceName': deviceName,
      'relayId': relayId,
      'relayName': relayName,
      'turnOn': turnOn,
      'isActive': isActive,
      'delayMs': delay?.inMilliseconds,
    };
  }

  /// Текстовое описание действия
  String get actionDescription =>
      '$deviceName - $relayName: ${turnOn ? 'Включить' : 'Выключить'}';
}
