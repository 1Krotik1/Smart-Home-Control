import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/relay_device.dart';
import '../services/relay_service.dart';

class DeviceProvider with ChangeNotifier {
  final RelayService _relayService = RelayService();
  final List<RelayDevice> _devices = [];
  bool _isLoading = false;
  String? _error;

  DeviceProvider() {
    _loadSavedDevices();
  }

  UnmodifiableListView<RelayDevice> get devices =>
      UnmodifiableListView(_devices);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Загрузка сохраненных устройств
  Future<void> _loadSavedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceIps = prefs.getStringList('device_ips') ?? [];

    if (deviceIps.isNotEmpty) {
      setLoading(true);
      for (final ip in deviceIps) {
        try {
          final device = await _relayService.addDeviceByIp(ip);
          if (device != null && !_deviceExists(device)) {
            _devices.add(device);
          }
        } catch (e) {
          // Пропускаем недоступные устройства
        }
      }
      setLoading(false);
      notifyListeners();
    }
  }

  // Сохранение устройств
  Future<void> _saveDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceIps = _devices.map((device) => device.ipAddress).toList();
    await prefs.setStringList('device_ips', deviceIps);
  }

  // Установка состояния загрузки
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Установка ошибки
  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Проверка наличия устройства в списке
  bool _deviceExists(RelayDevice device) {
    return _devices.any((d) => d.ipAddress == device.ipAddress);
  }

  // Обновление состояния устройства
  Future<void> refreshDevice(int index) async {
    if (index < 0 || index >= _devices.length) return;

    try {
      final device = await _relayService.getStatus(_devices[index].ipAddress);
      _devices[index] = device;
      notifyListeners();
    } catch (e) {
      setError('Failed to refresh device: $e');
    }
  }

  // Обновление всех устройств
  Future<void> refreshAllDevices() async {
    setLoading(true);
    setError(null);

    for (int i = 0; i < _devices.length; i++) {
      try {
        await refreshDevice(i);
      } catch (e) {
        // Продолжаем обновление остальных устройств
      }
    }

    setLoading(false);
  }

  // Переключение состояния конкретного реле
  Future<void> toggleRelay(int deviceIndex, int relayId) async {
    if (deviceIndex < 0 || deviceIndex >= _devices.length) return;

    setLoading(true);
    setError(null);

    try {
      final isOn = await _relayService.toggleRelay(
        _devices[deviceIndex].ipAddress,
        relayId,
      );

      // Обновляем состояние реле в локальном списке
      final relayIndex = _devices[deviceIndex].relays.indexWhere(
        (r) => r.id == relayId,
      );
      if (relayIndex >= 0) {
        _devices[deviceIndex].relays[relayIndex].isOn = isOn;
        notifyListeners();
      } else {
        // Если реле не найдено, обновляем всё устройство
        await refreshDevice(deviceIndex);
      }
    } catch (e) {
      setError('Failed to toggle relay: $e');
    } finally {
      setLoading(false);
    }
  }

  // Изменение имени реле
  Future<void> setRelayName(
    int deviceIndex,
    int relayId,
    String newName,
  ) async {
    if (deviceIndex < 0 || deviceIndex >= _devices.length) return;

    setLoading(true);
    setError(null);

    try {
      final success = await _relayService.setRelayName(
        _devices[deviceIndex].ipAddress,
        relayId,
        newName,
      );

      if (success) {
        // Обновляем имя реле в локальном списке
        final relayIndex = _devices[deviceIndex].relays.indexWhere(
          (r) => r.id == relayId,
        );
        if (relayIndex >= 0) {
          // Поскольку нам нужно только имя обновить, а не перезагружать всё устройство,
          // мы просто обновляем это поле и уведомляем слушателей
          _devices[deviceIndex].relays[relayIndex] = Relay(
            id: relayId,
            name: newName,
            isOn: _devices[deviceIndex].relays[relayIndex].isOn,
          );
          notifyListeners();
        } else {
          // Если реле не найдено, обновляем всё устройство
          await refreshDevice(deviceIndex);
        }
      } else {
        setError('Failed to set relay name');
      }
    } catch (e) {
      setError('Failed to set relay name: $e');
    } finally {
      setLoading(false);
    }
  }

  // Поиск устройств
  Future<void> discoverDevices() async {
    setLoading(true);
    setError(null);

    try {
      final discoveredDevices = await _relayService.discoverDevices();

      for (final device in discoveredDevices) {
        if (!_deviceExists(device)) {
          _devices.add(device);
        }
      }

      _saveDevices();
      notifyListeners();
    } catch (e) {
      setError('Failed to discover devices: $e');
    } finally {
      setLoading(false);
    }
  }

  // Добавление устройства вручную
  Future<bool> addDeviceManually(String ipAddress) async {
    setLoading(true);
    setError(null);

    print('Attempting to add device manually: $ipAddress');

    try {
      // Диагностика доступности устройства
      print('Testing if device is reachable');
      final isReachable = await _relayService.pingDevice(ipAddress);

      if (!isReachable) {
        print('Device is not reachable');
        setError(
          'Не удается подключиться к устройству. Проверьте IP-адрес и доступность устройства.',
        );
        return false;
      }

      print('Device is reachable, getting status');
      final device = await _relayService.addDeviceByIp(ipAddress);

      if (device != null) {
        print('Device status received successfully');
        if (!_deviceExists(device)) {
          _devices.add(device);
          _saveDevices();
          notifyListeners();
          print('Device added successfully');
          return true;
        } else {
          print('Device already exists');
          setError('Устройство с таким IP уже существует');
        }
      } else {
        print('Device is reachable but failed to get status');
        setError(
          'Не удается получить данные с устройства. Убедитесь, что это устройство ESP8266 Relay.',
        );
      }
      return false;
    } catch (e) {
      print('Error adding device: $e');
      setError('Ошибка при добавлении устройства: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // Удаление устройства
  void removeDevice(int index) {
    if (index < 0 || index >= _devices.length) return;

    _devices.removeAt(index);
    _saveDevices();
    notifyListeners();
  }
}
