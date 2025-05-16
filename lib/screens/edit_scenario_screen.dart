import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/scenario.dart';
import '../models/relay_device.dart';
import '../providers/device_provider.dart';
import '../providers/scenario_provider.dart';
import '../widgets/scenario_action_card.dart';

class EditScenarioScreen extends StatefulWidget {
  final String? scenarioId;

  const EditScenarioScreen({super.key, this.scenarioId});

  @override
  State<EditScenarioScreen> createState() => _EditScenarioScreenState();
}

class _EditScenarioScreenState extends State<EditScenarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _uuid = const Uuid();

  // Сценарий, который редактируется или создаётся
  Scenario? _scenario;
  List<ScenarioAction> _actions = [];
  bool _isActive = true;
  Color _selectedColor = const Color(0xFF3498DB);
  IconData _selectedIcon = Icons.auto_awesome;
  bool _isEditMode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScenario();
  }

  // Загрузка сценария для редактирования или создание нового сценария
  Future<void> _loadScenario() async {
    setState(() {
      _isLoading = true;
    });

    // Если передан ID сценария - загружаем существующий сценарий
    if (widget.scenarioId != null) {
      final scenarioProvider = Provider.of<ScenarioProvider>(
        context,
        listen: false,
      );
      _scenario = scenarioProvider.getScenarioById(widget.scenarioId!);

      if (_scenario != null) {
        _nameController.text = _scenario!.name;
        _descriptionController.text = _scenario!.description;
        _actions = List.from(_scenario!.actions);        _isActive = _scenario!.isActive;
        _selectedColor = _scenario!.color;
        _selectedIcon = const IconData(0xe0f7, fontFamily: 'MaterialIcons');  // Используем константное значение
        _isEditMode = true;
      }
    } else {
      // Создаём новый сценарий
      _isEditMode = false;
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Сохранение сценария
  void _saveScenario() {
    // Проверяем, заполнено ли название сценария
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, заполните название сценария'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Проверяем, добавлены ли действия в сценарий
    if (_actions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы одно действие в сценарий'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Показываем индикатор прогресса
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text('Сохранение сценария...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    final scenarioProvider = Provider.of<ScenarioProvider>(
      context,
      listen: false,
    );

    final scenarioToSave = Scenario(
      id: _isEditMode ? _scenario!.id : _uuid.v4(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      actions: _actions,
      isActive: _isActive,
      color: _selectedColor,
      iconCodePoint: _selectedIcon.codePoint,
      iconFontFamily: _selectedIcon.fontFamily!,
      lastRun: _isEditMode ? _scenario!.lastRun : null,
    );

    try {
      if (_isEditMode) {
        scenarioProvider
            .updateScenario(scenarioToSave)
            .then((_) {
              // Закрываем индикатор прогресса
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              // Показываем сообщение об успехе
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Сценарий успешно сохранен'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
              Navigator.of(context).pop();
            })
            .catchError((error) {
              // Закрываем индикатор прогресса
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              _showErrorDialog('Ошибка при обновлении сценария: $error');
            });
      } else {
        scenarioProvider
            .addScenario(scenarioToSave)
            .then((_) {
              // Закрываем индикатор прогресса
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              // Показываем сообщение об успехе
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Сценарий успешно создан'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
              Navigator.of(context).pop();
            })
            .catchError((error) {
              // Закрываем индикатор прогресса
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              _showErrorDialog('Ошибка при создании сценария: $error');
            });
      }
    } catch (e) {
      // Закрываем индикатор прогресса
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showErrorDialog('Возникла непредвиденная ошибка: $e');
    }
  }

  // Добавление нового действия в сценарий
  void _addAction() {
    _showAddActionDialog();
  }

  // Редактирование существующего действия
  void _editAction(int index) {
    _showAddActionDialog(existingAction: _actions[index], index: index);
  }

  // Удаление действия
  void _deleteAction(int index) {
    setState(() {
      _actions.removeAt(index);
    });
  }

  // Переключение активности действия
  void _toggleActionActive(int index, bool value) {
    setState(() {
      _actions[index] = _actions[index].copyWith(isActive: value);
    });
  }

  // Диалог добавления/редактирования действия
  void _showAddActionDialog({ScenarioAction? existingAction, int? index}) {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final devices = deviceProvider.devices;

    // Если нет устройств, показываем сообщение
    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала добавьте устройства')),
      );
      return;
    }

    // Выбранное устройство (начальное значение или первое в списке)
    RelayDevice selectedDevice = devices.first;

    // Выбранное реле (начальное значение или первое в списке)
    Relay selectedRelay = selectedDevice.relays.first;

    // Состояние для переключателя
    bool turnOn = existingAction?.turnOn ?? true;

    // Задержка в миллисекундах
    int delayMs = existingAction?.delay?.inMilliseconds ?? 0;

    // Если редактируем существующее действие, находим соответствующие устройство и реле
    if (existingAction != null) {
      // Находим устройство по IP
      int deviceIndex = devices.indexWhere(
        (d) => d.ipAddress == existingAction.deviceIp,
      );
      if (deviceIndex >= 0) {
        selectedDevice = devices[deviceIndex];

        // Находим реле по ID
        int relayIndex = selectedDevice.relays.indexWhere(
          (r) => r.id == existingAction.relayId,
        );
        if (relayIndex >= 0) {
          selectedRelay = selectedDevice.relays[relayIndex];
        }
      }
    }

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  existingAction == null
                      ? 'Добавление действия'
                      : 'Редактирование действия',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Выбор устройства
                      DropdownButtonFormField<RelayDevice>(
                        value: selectedDevice,
                        decoration: const InputDecoration(
                          labelText: 'Устройство',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            devices.map((device) {
                              return DropdownMenuItem<RelayDevice>(
                                value: device,
                                child: Text(device.name),
                              );
                            }).toList(),
                        onChanged: (device) {
                          if (device != null) {
                            setDialogState(() {
                              selectedDevice = device;
                              selectedRelay = device.relays.first;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Выбор реле
                      DropdownButtonFormField<Relay>(
                        value: selectedRelay,
                        decoration: const InputDecoration(
                          labelText: 'Реле',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            selectedDevice.relays.map((relay) {
                              return DropdownMenuItem<Relay>(
                                value: relay,
                                child: Text(relay.name),
                              );
                            }).toList(),
                        onChanged: (relay) {
                          if (relay != null) {
                            setDialogState(() {
                              selectedRelay = relay;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Выбор действия (включить/выключить)
                      Row(
                        children: [
                          const Text('Действие:'),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment<bool>(
                                  value: true,
                                  label: Text('Включить'),
                                  icon: Icon(Icons.power_settings_new),
                                ),
                                ButtonSegment<bool>(
                                  value: false,
                                  label: Text('Выключить'),
                                  icon: Icon(Icons.power_off),
                                ),
                              ],
                              selected: {turnOn},
                              onSelectionChanged: (Set<bool> value) {
                                setDialogState(() {
                                  turnOn = value.first;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Настройка задержки
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Задержка:'),
                              Text(
                                _formatDuration(
                                  Duration(milliseconds: delayMs),
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: delayMs.toDouble(),
                            min: 0,
                            max: 60000, // 1 минута в миллисекундах
                            divisions: 60,
                            label: _formatDuration(
                              Duration(milliseconds: delayMs),
                            ),
                            onChanged: (value) {
                              setDialogState(() {
                                delayMs = value.toInt();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final action = ScenarioAction(
                        id: existingAction?.id ?? _uuid.v4(),
                        deviceIp: selectedDevice.ipAddress,
                        deviceName: selectedDevice.name,
                        relayId: selectedRelay.id,
                        relayName: selectedRelay.name,
                        turnOn: turnOn,
                        isActive: existingAction?.isActive ?? true,
                        delay:
                            delayMs > 0
                                ? Duration(milliseconds: delayMs)
                                : null,
                      );

                      setState(() {
                        if (index != null) {
                          // Обновляем существующее действие
                          _actions[index] = action;
                        } else {
                          // Добавляем новое действие
                          _actions.add(action);
                        }
                      });

                      Navigator.of(context).pop();
                    },
                    child: Text(
                      existingAction == null ? 'Добавить' : 'Сохранить',
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  // Диалог выбора цвета сценария
  void _showColorPickerDialog() {
    final List<Color> colorOptions = [
      const Color(0xFF3498DB), // Синий
      const Color(0xFF1ABC9C), // Бирюзовый
      const Color(0xFF9B59B6), // Фиолетовый
      const Color(0xFFE74C3C), // Красный
      const Color(0xFFE67E22), // Оранжевый
      const Color(0xFFF1C40F), // Желтый
      const Color(0xFF2ECC71), // Зеленый
      const Color(0xFF34495E), // Темно-синий
    ];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Выберите цвет'),
            content: Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  colorOptions.map((color) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                _selectedColor == color
                                    ? Colors.white
                                    : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child:
                            _selectedColor == color
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                      ),
                    );
                  }).toList(),
            ),
          ),
    );
  }

  // Диалог выбора иконки сценария
  void _showIconPickerDialog() {
    final List<IconData> iconOptions = [
      Icons.auto_awesome,
      Icons.lightbulb_outline,
      Icons.home,
      Icons.nights_stay,
      Icons.wb_sunny_outlined,
      Icons.access_time,
      Icons.star_outline,
      Icons.movie,
      Icons.music_note,
      Icons.restaurant,
      Icons.tv,
      Icons.sports_esports,
      Icons.power_settings_new,
      Icons.water_drop,
    ];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Выберите иконку'),
            content: Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  iconOptions.map((icon) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIcon = icon;
                        });
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: _selectedColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                _selectedIcon == icon
                                    ? _selectedColor
                                    : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color:
                              _selectedIcon == icon
                                  ? _selectedColor
                                  : Colors.grey,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
    );
  }

  // Показ диалога с ошибкой
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Ошибка'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  // Форматирование длительности для отображения
  String _formatDuration(Duration duration) {
    if (duration.inMilliseconds == 0) {
      return "Без задержки";
    }
    if (duration.inSeconds < 60) {
      return "${duration.inSeconds} сек.";
    } else {
      return "${duration.inMinutes} мин. ${duration.inSeconds % 60} сек.";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditMode ? 'Редактирование сценария' : 'Создание сценария',
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Редактирование сценария' : 'Создание сценария',
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveScenario,
            icon: const Icon(Icons.save),
            label: const Text('Сохранить'),
          ),
        ],
      ),
      // Убираем FloatingActionButton, чтобы оставить только одну кнопку добавления действий
      // floatingActionButton: FloatingActionButton(
      //   heroTag: 'edit_scenario_fab',
      //   onPressed: _addAction,
      //   tooltip: 'Добавить действие',
      //   backgroundColor: Theme.of(context).colorScheme.secondary,
      //   child: const Icon(Icons.add),
      // ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: _saveScenario,
          icon: const Icon(Icons.save),
          label: const Text(
            'СОХРАНИТЬ СЦЕНАРИЙ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // Основная информация о сценарии
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Основная информация',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Название сценария
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Название сценария',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.label),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Введите название сценария';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Описание сценария
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Описание',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),

                      // Выбор цвета и иконки
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Цвет сценария'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _showColorPickerDialog,
                                  child: Container(
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: _selectedColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.color_lens,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Иконка сценария'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _showIconPickerDialog,
                                  child: Container(
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: _selectedColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _selectedColor),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        _selectedIcon,
                                        color: _selectedColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Активность сценария
                      SwitchListTile(
                        title: const Text('Активен'),
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                        secondary: Icon(
                          _isActive ? Icons.check_circle : Icons.cancel,
                          color: _isActive ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Секция действий сценария
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Действия',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _addAction,
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Список действий
                      if (_actions.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Добавьте действия для сценария',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      else
                        ...List.generate(_actions.length, (index) {
                          return ScenarioActionCard(
                            key: ValueKey(_actions[index].id),
                            action: _actions[index],
                            onEdit: () => _editAction(index),
                            onDelete: () => _deleteAction(index),
                            onToggleActive:
                                (value) => _toggleActionActive(index, value),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
