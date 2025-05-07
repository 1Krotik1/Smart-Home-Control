import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';
import '../models/scenario.dart';

class ScenarioTile extends StatelessWidget {
  final Scenario scenario;
  final VoidCallback onEdit;
  final VoidCallback onRun;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;

  const ScenarioTile({
    super.key,
    required this.scenario,
    required this.onEdit,
    required this.onRun,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: scenario.isActive ? scenario.color : Colors.grey,
                width: 8,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildScenarioHeader(context),
                const SizedBox(height: 12),
                if (scenario.description.isNotEmpty) ...[
                  Text(
                    scenario.description,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                ],
                const Divider(),
                const SizedBox(height: 8),
                _buildScenarioDetails(),
                const SizedBox(height: 16),
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    scenario.isActive
                        ? scenario.color.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: scenario.iconWidget(
                color: scenario.isActive ? scenario.color : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scenario.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scenario.isActive ? 'Активен' : 'Отключен',
                  style: TextStyle(
                    color: scenario.isActive ? scenario.color : Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        Switch(
          value: scenario.isActive,
          activeColor: scenario.color,
          onChanged: onToggleActive,
        ),
      ],
    );
  }

  Widget _buildScenarioDetails() {
    return Row(
      children: [
        _buildDetailChip(
          icon: Icons.touch_app,
          label: '${scenario.actions.length} действий',
          color: scenario.isActive ? scenario.color : Colors.grey,
        ),
        const SizedBox(width: 8),
        if (scenario.lastRun != null)
          _buildDetailChip(
            icon: Icons.access_time,
            label: 'Запущен: ${_formatLastRun(scenario.lastRun!)}',
            color: scenario.isActive ? scenario.color : Colors.grey,
          ),
      ],
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
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
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Изменить'),
          style: OutlinedButton.styleFrom(
            foregroundColor: scenario.isActive ? scenario.color : Colors.grey,
            side: BorderSide(
              color: scenario.isActive ? scenario.color : Colors.grey,
            ),
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              tooltip: 'Удалить сценарий',
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: scenario.isActive ? onRun : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Запустить'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    scenario.isActive ? scenario.color : Colors.grey.shade300,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatLastRun(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return DateFormat('dd.MM.yy HH:mm').format(dateTime);
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ч. назад';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} мин. назад';
    } else {
      return 'только что';
    }
  }
}
