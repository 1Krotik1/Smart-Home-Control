import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/scenario.dart';
import '../services/relay_service.dart';
import 'device_provider.dart';  // Добавлен импорт DeviceProvider

/// Вспомогательная функция для группировки элементов по ключу
Map<K, List<T>> groupBy<T, K>(Iterable<T> items, K Function(T) key) {
  final map = <K, List<T>>{};
  for (final item in items) {
    final k = key(item);
    (map[k] ??= []).add(item);
  }
  return map;
}

class ScenarioProvider with ChangeNotifier {
  final RelayService _relayService = RelayService();
  final List<Scenario> _scenarios = [];
  bool _isLoading = false;
  String? _error;
  final Uuid _uuid = const Uuid();
  List<String> _executionLog = [];
  DeviceProvider? _deviceProvider;  // Добавлено свойство deviceProvider
  
  // Геттер и сеттер для deviceProvider
  DeviceProvider? get deviceProvider => _deviceProvider;
  set deviceProvider(DeviceProvider? value) {
    _deviceProvider = value;
    notifyListeners();
  }

  ScenarioProvider() {
    _loadScenarios();
  }

  UnmodifiableListView<Scenario> get scenarios =>
      UnmodifiableListView(_scenarios);
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get executionLog => _executionLog;

  /// Загрузка сценариев из SharedPreferences
  Future<void> _loadScenarios() async {
    setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final scenariosJson = prefs.getStringList('scenarios') ?? [];

      if (scenariosJson.isNotEmpty) {
        _scenarios.clear();
        for (final json in scenariosJson) {
          try {
            final Map<String, dynamic> scenarioMap = jsonDecode(json);
            final scenario = Scenario.fromJson(scenarioMap);
            _scenarios.add(scenario);
          } catch (e) {
            print('Ошибка при загрузке сценария: $e');
          }
        }
      }
    } catch (e) {
      setError('Ошибка при загрузке сценариев: $e');
      print('Ошибка при загрузке сценариев: $e');
    } finally {
      setLoading(false);
    }
  }

  /// Сохранение сценариев в SharedPreferences
  Future<void> _saveScenarios() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scenariosJson =
          _scenarios.map((scenario) => jsonEncode(scenario.toJson())).toList();

      await prefs.setStringList('scenarios', scenariosJson);
    } catch (e) {
      setError('Ошибка при сохранении сценариев: $e');
      print('Ошибка при сохранении сценариев: $e');
    }
  }

  /// Установка состояния загрузки
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Установка ошибки
  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Добавление нового сценария
  Future<void> addScenario(Scenario scenario) async {
    setLoading(true);

    try {
      // Если ID не установлен или пустой, генерируем новый
      final newScenario =
          scenario.id.isEmpty || scenario.id.trim().isEmpty
              ? Scenario(
                id: _uuid.v4(),
                name: scenario.name,
                description: scenario.description,
                actions: scenario.actions,
                isActive: scenario.isActive,
                color: scenario.color,
                iconCodePoint: scenario.iconCodePoint,
                iconFontFamily: scenario.iconFontFamily,
              )
              : scenario;

      _scenarios.add(newScenario);
      await _saveScenarios();
      notifyListeners();
    } catch (e) {
      setError('Ошибка при добавлении сценария: $e');
    } finally {
      setLoading(false);
    }
  }

  /// Обновление существующего сценария
  Future<void> updateScenario(Scenario updatedScenario) async {
    setLoading(true);

    try {
      final index = _scenarios.indexWhere((s) => s.id == updatedScenario.id);

      if (index >= 0) {
        _scenarios[index] = updatedScenario;
        await _saveScenarios();
        notifyListeners();
      } else {
        setError('Сценарий не найден');
      }
    } catch (e) {
      setError('Ошибка при обновлении сценария: $e');
    } finally {
      setLoading(false);
    }
  }

  /// Удаление сценария
  Future<void> deleteScenario(String id) async {
    setLoading(true);

    try {
      _scenarios.removeWhere((s) => s.id == id);
      await _saveScenarios();
      notifyListeners();
    } catch (e) {
      setError('Ошибка при удалении сценария: $e');
    } finally {
      setLoading(false);
    }
  }

  /// Включение/выключение сценария
  Future<void> toggleScenarioActive(String id) async {
    final index = _scenarios.indexWhere((s) => s.id == id);

    if (index >= 0) {
      final scenario = _scenarios[index];
      final updatedScenario = scenario.copyWith(isActive: !scenario.isActive);

      await updateScenario(updatedScenario);
    }
  }

  /// Выполнение сценария
  Future<bool> executeScenario(String id) async {
    setLoading(true);
    setError(null);
    _executionLog = []; // Очищаем лог перед выполнением

    try {
      final index = _scenarios.indexWhere((s) => s.id == id);

      if (index < 0) {
        setError('Сценарий не найден');
        _executionLog.add('🔴 Сценарий не найден');
        return false;
      }

      final scenario = _scenarios[index];
      _executionLog.add('🔵 Начало выполнения сценария: ${scenario.name}');

      if (!scenario.isActive) {
        setError('Сценарий отключен');
        _executionLog.add('🔴 Сценарий отключен');
        return false;
      }

      if (scenario.actions.isEmpty) {
        setError('Сценарий не содержит действий');
        _executionLog.add('🔴 Сценарий не содержит действий');
        return false;
      }

      // Проверка на активные действия
      final activeActions = scenario.actions.where((a) => a.isActive).toList();
      if (activeActions.isEmpty) {
        setError('Сценарий не содержит активных действий');
        _executionLog.add('🔴 Сценарий не содержит активных действий');
        return false;
      }

      // Обновляем время последнего запуска
      _scenarios[index] = scenario.copyWith(lastRun: DateTime.now());
      await _saveScenarios();
      notifyListeners();

      int successActions = 0;
      int failedActions = 0;

      // Группируем действия по IP устройств для оптимизации
      final deviceGroups = groupBy(activeActions, (action) => action.deviceIp);

      // Выполняем действия для каждого устройства параллельно
      await Future.wait(
        deviceGroups.entries.map((entry) async {
          final deviceIp = entry.key;
          final actions = entry.value;

          try {
            _executionLog.add(
              '🔹 Отправка действий на устройство ${actions.first.deviceName}',
            );

            // Пытаемся отправить действия как единый сценарий
            final result = await _relayService.runScenarioOnDevice(
              deviceIp,
              actions,
            );

            if (result) {
              successActions += actions.length;
              _executionLog.add(
                '✅ Действия успешно выполнены на ${actions.first.deviceName}',
              );
            } else {
              // Если не удалось выполнить как сценарий, выполняем действия последовательно
              for (final action in actions) {
                try {
                  if (action.delay != null) {
                    _executionLog.add(
                      '⏱️ Задержка: ${_formatDuration(action.delay!)}',
                    );
                    await Future.delayed(action.delay!);
                  }

                  await _relayService.toggleRelayToState(
                    action.deviceIp,
                    action.relayId,
                    action.turnOn,
                  );

                  _executionLog.add(
                    '✅ Действие "${action.relayName}" выполнено',
                  );
                  successActions++;
                } catch (e) {
                  _executionLog.add(
                    '❌ Ошибка действия "${action.relayName}": $e',
                  );
                  failedActions++;
                }
              }
            }
          } catch (e) {
            _executionLog.add(
              '❌ Ошибка устройства ${actions.first.deviceName}: $e',
            );
            failedActions += actions.length;
          }
        }),
      );

      final totalActions = activeActions.length;
      _executionLog.add(
        '📊 Итоги: выполнено $successActions из $totalActions действий',
      );

      if (failedActions > 0) {
        if (successActions == 0) {
          setError('Не удалось выполнить ни одно действие');
          return false;
        }
        setError('Некоторые действия не были выполнены');
      }

      return successActions > 0;
    } catch (e) {
      _executionLog.add('🔴 Ошибка при выполнении сценария: $e');
      setError('Ошибка при выполнении сценария: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }


  /// Получение лога последнего выполнения
  List<String> getExecutionLog() {
    return List.from(_executionLog);
  }

  /// Очистка лога выполнения
  void clearExecutionLog() {
    _executionLog.clear();
    notifyListeners();
  }

  /// Форматирование длительности для отображения
  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return "${duration.inSeconds} сек.";
    } else {
      return "${duration.inMinutes} мин. ${duration.inSeconds % 60} сек.";
    }
  }

  /// Получение сценария по ID
  Scenario? getScenarioById(String id) {
    final index = _scenarios.indexWhere((s) => s.id == id);
    return index >= 0 ? _scenarios[index] : null;
  }

  /// Сброс ошибки
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}
