import 'package:flutter/material.dart';
import '../models/relay_device.dart';

class DeviceTile extends StatelessWidget {
  final RelayDevice device;
  final Function(int) onToggle; // Изменен для передачи id реле
  final VoidCallback onRefresh;
  final VoidCallback onDelete;
  final Function(int, String) onRenameRelay; // Новый коллбэк для переименования

  const DeviceTile({
    super.key,
    required this.device,
    required this.onToggle,
    required this.onRefresh,
    required this.onDelete,
    required this.onRenameRelay,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            // Индикатор состояния устройства (цветная полоса сбоку)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 8,
                color:
                    device.hasActiveRelays
                        ? const Color(
                          0xFF1ABC9C,
                        ) // зеленый для устройства с активными реле
                        : const Color(
                          0xFF7F8C8D,
                        ), // серый для устройства с выключенными реле
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDeviceHeader(context),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildDeviceStatus(),
                  const SizedBox(height: 20),
                  // Список всех реле устройства
                  ...device.relays.map(
                    (relay) => _buildRelayItem(context, relay),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3498DB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.electrical_services,
                color: Color(0xFF3498DB),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  device.ipAddress,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
        PopupMenuButton(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 4,
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(
                        Icons.refresh,
                        size: 20,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 12),
                      const Text('Обновить'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: const Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: 12),
                      Text('Удалить'),
                    ],
                  ),
                ),
              ],
          onSelected: (value) {
            if (value == 'refresh') {
              onRefresh();
            } else if (value == 'delete') {
              onDelete();
            }
          },
        ),
      ],
    );
  }

  Widget _buildDeviceStatus() {
    return Row(
      children: [
        _buildSignalIndicator(device.signalStrength),
        const SizedBox(width: 16),
        _buildActiveRelaysIndicator(device.activeRelaysCount),
      ],
    );
  }

  Widget _buildRelayItem(BuildContext context, Relay relay) {
    // Убедимся, что имя не пустое и не "_"
    String relayName = relay.name;
    if (relayName.isEmpty || relayName == "_" || relayName == "undefined") {
      relayName = "Реле ${relay.id + 1}";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: relay.isOn ? const Color(0xFF1ABC9C) : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    relayName, // Используем проверенное имя
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () => _showRenameDialog(context, relay),
                tooltip: 'Переименовать',
                color: Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                relay.isOn ? 'Включено' : 'Выключено',
                style: TextStyle(
                  color: relay.isOn ? const Color(0xFF1ABC9C) : Colors.grey,
                  fontWeight: relay.isOn ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => onToggle(relay.id),
                icon: Icon(relay.isOn ? Icons.power_settings_new : Icons.power),
                label: Text(relay.isOn ? 'Выключить' : 'Включить'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      relay.isOn ? Colors.redAccent : const Color(0xFF1ABC9C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Relay relay) {
    final TextEditingController controller = TextEditingController(
      text: relay.name,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Переименовать реле'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Введите новое имя для реле:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Имя реле',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newName = controller.text.trim();
                  if (newName.isNotEmpty) {
                    onRenameRelay(relay.id, newName);
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                ),
                child: const Text('Сохранить'),
              ),
            ],
          ),
    );
  }

  Widget _buildSignalIndicator(int signalStrength) {
    IconData icon;
    Color color;
    String label;

    // Определение уровня сигнала
    if (signalStrength > -50) {
      icon = Icons.signal_wifi_4_bar;
      color = Colors.green;
      label = 'Отличный';
    } else if (signalStrength > -70) {
      icon = Icons.network_wifi;
      color = Colors.amber;
      label = 'Хороший';
    } else {
      icon = Icons.signal_wifi_0_bar;
      color = Colors.redAccent;
      label = 'Слабый';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label ($signalStrength dBm)',
            style: TextStyle(color: color, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRelaysIndicator(int activeCount) {
    final total = device.relays.length;
    final color = activeCount > 0 ? const Color(0xFF1ABC9C) : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.highlight, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            'Активно: $activeCount из $total',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
