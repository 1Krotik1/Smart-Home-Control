import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';
import '../models/relay_device.dart';
import '../models/scenario.dart';

class RelayService {
  static const String _serviceName = '_http._tcp.local';
  static const String _relayHostname = 'SmartRelay';
  static const int _connectionTimeout = 5; // Увеличиваем с 3 до 5 секунд

  // Получение статуса устройства с поддержкой UTF-8
  Future<RelayDevice> getStatus(String ipAddress) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://$ipAddress/status'),
            headers: {'Accept': 'application/json; charset=utf-8'},
          )
          .timeout(Duration(seconds: _connectionTimeout));

      if (response.statusCode == 200) {
        try {
          // Декодирование с использованием UTF-8
          // Попытка декодировать JSON с дополнительной обработкой ошибок
          final String cleanedJson = _cleanJsonString(
            const Utf8Decoder().convert(response.bodyBytes),
          );
          final Map<String, dynamic> data = json.decode(cleanedJson);

          print('JSON Response from $ipAddress: $cleanedJson');

          return RelayDevice.fromJson({
            ...data,
            'name': _relayHostname,
            'ip': ipAddress,
          });
        } catch (jsonError) {
          // Ошибка при разборе JSON
          print(
            'JSON parsing error: $jsonError for response: ${response.body}',
          );
          throw Exception('Invalid JSON response: $jsonError');
        }
      } else {
        throw Exception('Failed to get status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Очистка JSON-строки от некорректных символов
  String _cleanJsonString(String dirtyJson) {
    // Удаление непечатаемых символов, сохраняя кириллицу
    String cleanJson = dirtyJson.replaceAll(
      RegExp(r'[\u0000-\u0008\u000B-\u000C\u000E-\u001F]'),
      '',
    );

    // Проверка и исправление проблем с именами реле
    try {
      Map<String, dynamic> jsonData = json.decode(cleanJson);
      if (jsonData.containsKey('relays') && jsonData['relays'] is List) {
        List relays = jsonData['relays'] as List;
        for (int i = 0; i < relays.length; i++) {
          if (relays[i] is Map && relays[i].containsKey('name')) {
            String name = relays[i]['name'].toString();
            // Проверка на некорректные имена
            if (name.isEmpty || name == "_" || name == "undefined") {
              relays[i]['name'] = 'Реле ${i + 1}';
            }
          }
        }
        // Преобразуем исправленные данные обратно в JSON
        return json.encode(jsonData);
      }
    } catch (e) {
      print('Error fixing relay names in JSON: $e');
    }

    return cleanJson;
  }

  // Переключение состояния конкретного реле
  Future<bool> toggleRelay(String ipAddress, int relayId) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ipAddress/toggle?relay=$relayId'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 302) {
        // После переключения обновляем статус
        final device = await getStatus(ipAddress);
        // Находим реле по id и возвращаем его состояние
        final relay = device.relays.firstWhere(
          (relay) => relay.id == relayId,
          orElse: () => Relay(id: relayId, name: 'Реле $relayId', isOn: false),
        );
        return relay.isOn;
      } else {
        throw Exception('Failed to toggle relay: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  /// Установка реле в заданное состояние (включение или выключение) для сценариев
  Future<bool> toggleRelayToState(
    String ipAddress,
    int relayId,
    bool turnOn,
  ) async {
    try {
      // Сначала получаем текущее состояние реле
      final device = await getStatus(ipAddress);
      final relay = device.relays.firstWhere(
        (relay) => relay.id == relayId,
        orElse: () => Relay(id: relayId, name: 'Реле $relayId', isOn: false),
      );

      // Если текущее состояние совпадает с желаемым, ничего не делаем
      if (relay.isOn == turnOn) {
        return true;
      }

      // Переключаем состояние реле
      return await toggleRelay(ipAddress, relayId);
    } catch (e) {
      print('Error toggling relay to state: $e');
      throw Exception('Error toggling relay to state: $e');
    }
  }

  // Изменение имени реле с поддержкой UTF-8
  Future<bool> setRelayName(
    String ipAddress,
    int relayId,
    String newName,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('http://$ipAddress/set-name'),
            headers: {
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
            },
            body: {'relay': relayId.toString(), 'name': newName},
            encoding: Encoding.getByName('utf-8'),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Проверка доступности устройства (ping)
  Future<bool> pingDevice(String ipAddress) async {
    try {
      print('Pinging device at $ipAddress...');
      final response = await http
          .get(Uri.parse('http://$ipAddress/ping'))
          .timeout(Duration(seconds: _connectionTimeout));

      print('Ping response: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Ping failed for $ipAddress: $e');
      return false;
    }
  }

  // Поиск устройств в локальной сети с помощью сканирования IP-диапазона
  Future<List<RelayDevice>> scanNetworkForDevices() async {
    final List<RelayDevice> devices = [];
    final List<Future<void>> scanTasks = [];

    // Получаем информацию о текущей сети
    String localIp = await _getLocalIpAddress();
    if (localIp.isEmpty) {
      return devices; // Не удалось определить локальный IP
    }

    // Получаем основу IP-адреса (первые три октета)
    final parts = localIp.split('.');
    if (parts.length != 4) {
      return devices;
    }

    final baseIp = '${parts[0]}.${parts[1]}.${parts[2]}';
    print('Сканирование IP диапазона: $baseIp.1-254');

    // Сканируем диапазон IP-адресов
    for (int i = 1; i <= 254; i++) {
      final ip = '$baseIp.$i';

      // Пропускаем свой IP
      if (ip == localIp) continue;

      // Создаём задачу проверки каждого IP
      scanTasks.add(_checkDeviceAtIp(ip, devices));

      // Запускаем задачи группами по 10 для предотвращения перегрузки
      if (scanTasks.length >= 10) {
        await Future.wait(scanTasks);
        scanTasks.clear();
      }
    }

    // Ожидаем завершения оставшихся задач
    if (scanTasks.isNotEmpty) {
      await Future.wait(scanTasks);
    }

    return devices;
  }

  // Проверка наличия устройства по конкретному IP
  Future<void> _checkDeviceAtIp(String ip, List<RelayDevice> devices) async {
    try {
      // Быстрая проверка соединения
      print('Checking IP: $ip');
      final isReachable = await pingDevice(ip);

      if (isReachable) {
        print('Device at $ip is reachable, trying to get status');
        try {
          final device = await getStatus(ip);
          print('Successfully got status from $ip');
          devices.add(device);
          print('Added device: $ip - ${device.name}');
        } catch (e) {
          print('Error getting status from $ip: $e');
        }
      } else {
        print('Device at $ip is not reachable');
      }
    } catch (e) {
      print('Error checking device at $ip: $e');
    }
  }

  // Получение локального IP-адреса устройства
  Future<String> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      // Ищем активный Wi-Fi или Ethernet интерфейс
      for (var interface in interfaces) {
        // Пропускаем VPN и локальные интерфейсы
        if (interface.name.contains('tun') ||
            interface.name.contains('tap') ||
            interface.name.contains('lo')) {
          continue;
        }

        for (var addr in interface.addresses) {
          if (addr.address.startsWith('192.168.') ||
              addr.address.startsWith('10.') ||
              addr.address.startsWith('172.')) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error getting local IP: $e');
    }

    return '';
  }

  // Обновленный метод поиска устройств, использующий оба подхода
  Future<List<RelayDevice>> discoverDevices() async {
    List<RelayDevice> devices = [];

    // Сначала пробуем mDNS
    try {
      devices = await _discoverWithMdns();
    } catch (e) {
      print('mDNS discovery failed: $e');
    }

    // Если устройства не найдены через mDNS или произошла ошибка,
    // пробуем сканировать IP диапазон
    if (devices.isEmpty) {
      devices = await scanNetworkForDevices();
    }

    return devices;
  }

  // Старый метод поиска через mDNS вынесен в отдельную функцию
  Future<List<RelayDevice>> _discoverWithMdns() async {
    final List<RelayDevice> devices = [];
    final MDnsClient client = MDnsClient();

    try {
      await client.start();

      await client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(_serviceName),
          )
          .asyncMap((PtrResourceRecord ptr) async {
            client
                .lookup<SrvResourceRecord>(
                  ResourceRecordQuery.service(ptr.domainName),
                )
                .asyncMap((SrvResourceRecord srv) async {
                  client
                      .lookup<IPAddressResourceRecord>(
                        ResourceRecordQuery.addressIPv4(srv.target),
                      )
                      .listen((IPAddressResourceRecord ip) async {
                        // Проверяем, является ли это наше устройство
                        if (srv.name.contains(_relayHostname.toLowerCase())) {
                          try {
                            final device = await getStatus(ip.address.address);
                            devices.add(device);
                          } catch (e) {
                            print('Error getting device status: $e');
                          }
                        }
                      });
                });
          })
          .toList();
    } finally {
      client.stop();
    }

    return devices;
  }

  // Ручное добавление устройства по IP с более подробной информацией об ошибках
  Future<RelayDevice?> addDeviceByIp(String ipAddress) async {
    print('Attempting to add device manually at IP: $ipAddress');

    try {
      // Сначала проверяем доступность устройства
      bool isReachable = await pingDevice(ipAddress);

      if (!isReachable) {
        print('Device at $ipAddress is not reachable');
        return null;
      }

      print('Device at $ipAddress is reachable, attempting to get status');

      // Если устройство доступно, пробуем получить его статус
      try {
        final device = await getStatus(ipAddress);
        print('Successfully added device at $ipAddress');
        return device;
      } catch (statusError) {
        print('Error getting status from $ipAddress: $statusError');
        return null;
      }
    } catch (e) {
      print('Error adding device ($ipAddress): $e');
      return null;
    }
  }

  // Добавляем метод для выполнения сценария на устройстве ESP
  Future<bool> runScenarioOnDevice(
    String ipAddress,
    List<ScenarioAction> actions,
  ) async {
    try {
      print('Отправка сценария на устройство $ipAddress');

      // Преобразуем действия сценария в формат, понятный для ESP
      List<Map<String, dynamic>> formattedActions = [];

      for (final action in actions) {
        if (!action.isActive) continue; // Пропускаем неактивные действия

        formattedActions.add({
          'relayId': action.relayId,
          'turnOn': action.turnOn,
          'delayMs': action.delay?.inMilliseconds ?? 0,
        });
      }

      // Проверяем, есть ли действия для выполнения
      if (formattedActions.isEmpty) {
        print('Нет активных действий для выполнения сценария');
        return false;
      }

      // Формируем JSON для отправки
      final Map<String, dynamic> requestBody = {'actions': formattedActions};

      // Преобразуем в JSON строку
      final jsonData = json.encode(requestBody);

      // Отправляем POST-запрос на устройство
      final response = await http
          .post(
            Uri.parse('http://$ipAddress/run-scenario'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'text/plain; charset=utf-8',
            },
            body: jsonData,
          )
          .timeout(const Duration(seconds: 5));

      // Проверяем ответ
      if (response.statusCode == 200) {
        print('Сценарий успешно отправлен на устройство $ipAddress');
        return true;
      } else {
        print(
          'Ошибка при отправке сценария: ${response.statusCode} ${response.body}',
        );
        return false;
      }
    } catch (e) {
      print('Ошибка связи при отправке сценария: $e');
      return false;
    }
  }
}
