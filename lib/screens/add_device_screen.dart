import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/device_provider.dart';
import '../services/relay_service.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  bool _isDiscovering = false;
  bool _isTesting = false;
  String? _connectionTestResult;
  late AnimationController _animationController;

  // Сервис для тестирования соединения
  final RelayService _relayService = RelayService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Добавить устройство'),
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _animationController.value,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildManualAddSection(),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),
              _buildDiscoverSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualAddSection() {
    final provider = Provider.of<DeviceProvider>(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add_location_alt_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ручное добавление',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'IP-адрес устройства',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Введите IP-адрес устройства ESP8266 с реле:',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _ipController,
                    decoration: InputDecoration(
                      labelText: 'IP-адрес',
                      hintText: '192.168.1.100',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.router),
                      suffixIcon:
                          _isTesting
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : IconButton(
                                icon: const Icon(Icons.network_check),
                                tooltip: 'Проверить соединение',
                                onPressed: _testConnection,
                              ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Пожалуйста, введите IP-адрес';
                      }

                      // Простая проверка на формат IP-адреса
                      final RegExp ipRegex = RegExp(
                        r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
                      );

                      if (!ipRegex.hasMatch(value)) {
                        return 'Пожалуйста, введите корректный IP-адрес';
                      }

                      return null;
                    },
                  ),

                  // Отображение результата проверки соединения
                  if (_connectionTestResult != null)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            _connectionTestResult!.contains('Успешно')
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              _connectionTestResult!.contains('Успешно')
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _connectionTestResult!.contains('Успешно')
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            color:
                                _connectionTestResult!.contains('Успешно')
                                    ? Colors.green
                                    : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _connectionTestResult!,
                              style: TextStyle(
                                color:
                                    _connectionTestResult!.contains('Успешно')
                                        ? Colors.green
                                        : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  provider.isLoading
                      ? SpinKitThreeBounce(
                        color: Theme.of(context).colorScheme.secondary,
                        size: 24.0,
                      )
                      : ElevatedButton.icon(
                        onPressed: _addDeviceManually,
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить устройство'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                ],
              ),
            ),
            if (provider.error != null)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        provider.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1ABC9C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.wifi_find_outlined,
                    color: Color(0xFF1ABC9C),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Автоматический поиск',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Сканировать WiFi сеть',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Приложение выполнит поиск устройств ESP8266 с реле в вашей локальной сети:',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 24),
            _isDiscovering
                ? Center(
                  child: Column(
                    children: [
                      SpinKitRipple(color: const Color(0xFF1ABC9C), size: 80.0),
                      const SizedBox(height: 16),
                      const Text(
                        'Поиск устройств...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1ABC9C),
                        ),
                      ),
                    ],
                  ),
                )
                : SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _discoverDevices,
                    icon: const Icon(Icons.search),
                    label: const Text('Начать поиск'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1ABC9C),
                      side: const BorderSide(color: Color(0xFF1ABC9C)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _addDeviceManually() async {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<DeviceProvider>(context, listen: false);
      final success = await provider.addDeviceManually(_ipController.text);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Устройство успешно добавлено'),
            backgroundColor: Color(0xFF1ABC9C),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  // Новый метод для тестирования соединения
  Future<void> _testConnection() async {
    if (_ipController.text.isEmpty) {
      setState(() {
        _connectionTestResult = 'Введите IP-адрес для проверки';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _connectionTestResult = null;
    });

    try {
      final ipAddress = _ipController.text.trim();
      print('Testing connection to: $ipAddress');

      setState(() {
        _connectionTestResult = 'Попытка подключения к $ipAddress...';
      });

      final isReachable = await _relayService.pingDevice(ipAddress);

      if (isReachable) {
        print('Device is reachable');
        // Если устройство отвечает, проверяем, возвращает ли оно корректные данные
        try {
          final device = await _relayService.getStatus(ipAddress);

          // Проверяем имена реле на корректность
          bool hasEncodingIssues = device.relays.any(
            (relay) =>
                relay.name.contains('Ð') ||
                relay.name.contains('µ') ||
                relay.name == "_",
          );

          if (hasEncodingIssues) {
            setState(() {
              _connectionTestResult =
                  'Успешно! Устройство доступно, но обнаружены проблемы с кодировкой имен реле. Они будут отображаться как Relay X.';
            });
          } else {
            setState(() {
              _connectionTestResult =
                  'Успешно! Устройство доступно и отвечает корректно.';
            });
          }
        } catch (e) {
          print('Error getting status: $e');
          setState(() {
            _connectionTestResult =
                'Устройство доступно, но не удалось получить данные. Возможно это не наше устройство.';
          });
        }
      } else {
        print('Device is not reachable');
        setState(() {
          _connectionTestResult =
              'Устройство недоступно. Проверьте IP-адрес и подключение к сети.';
        });
      }
    } catch (e) {
      print('Connection test error: $e');
      setState(() {
        _connectionTestResult = 'Ошибка при проверке: $e';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  // Модифицированный метод discoverDevices с более подробной информацией
  Future<void> _discoverDevices() async {
    setState(() {
      _isDiscovering = true;
    });

    final provider = Provider.of<DeviceProvider>(context, listen: false);
    await provider.discoverDevices();

    if (mounted) {
      setState(() {
        _isDiscovering = false;
      });

      if (provider.devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Устройства не найдены. Проверьте, что устройства включены и подключены к той же WiFi сети.',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'ПОДРОБНЕЕ',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Не удалось найти устройства'),
                        content: const SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Возможные причины:'),
                              SizedBox(height: 8),
                              Text('• Устройство не подключено к Wi-Fi сети'),
                              Text('• Устройство подключено к другой сети'),
                              Text('• Брандмауэр блокирует соединение'),
                              Text('• mDNS не поддерживается в сети'),
                              SizedBox(height: 16),
                              Text(
                                'Попробуйте добавить устройство вручную, указав его IP-адрес.',
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('ЗАКРЫТЬ'),
                          ),
                        ],
                      ),
                );
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Найдено устройств: ${provider.devices.length}'),
            backgroundColor: const Color(0xFF1ABC9C),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    }
  }
}
