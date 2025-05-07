import 'package:flutter/material.dart';
import '../models/scenario.dart';

class ScenarioActionCard extends StatelessWidget {
  final ScenarioAction action;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;

  const ScenarioActionCard({
    super.key,
    required this.action,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  Color _getActionColor() {
    if (!action.isActive) return Colors.grey;
    return action.turnOn ? const Color(0xFF1ABC9C) : Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final actionColor = _getActionColor();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: actionColor, width: 6)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: actionColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              action.turnOn
                                  ? Icons.power_settings_new
                                  : Icons.power_off,
                              color: actionColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  action.deviceName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.electric_bolt,
                                      size: 14,
                                      color:
                                          action.isActive
                                              ? Colors.amber
                                              : Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        action.relayName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color:
                                              action.isActive
                                                  ? Colors.black87
                                                  : Colors.grey,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // Индикатор состояния
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: actionColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: actionColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            action.turnOn ? 'ВКЛ' : 'ВЫКЛ',
                            style: TextStyle(
                              color: actionColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Переключатель активности
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: action.isActive,
                            activeColor: actionColor,
                            onChanged: onToggleActive,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (action.delay != null &&
                    action.delay!.inMilliseconds > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDuration(action.delay!),
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit,
                        size: 20,
                        color: Colors.blueGrey,
                      ),
                      tooltip: 'Изменить действие',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      tooltip: 'Удалить действие',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds} сек. задержка';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes} мин. ${duration.inSeconds % 60} сек. задержка';
    } else {
      return '${duration.inHours} ч. ${duration.inMinutes % 60} мин. задержка';
    }
  }
}
