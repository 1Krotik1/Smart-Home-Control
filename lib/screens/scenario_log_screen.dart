import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/scenario_provider.dart';

class ScenarioLogScreen extends StatelessWidget {
  final String scenarioId;
  final String scenarioName;

  const ScenarioLogScreen({
    super.key,
    required this.scenarioId,
    required this.scenarioName,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ScenarioProvider>(context);
    final logEntries = provider.executionLog;

    return Scaffold(
      appBar: AppBar(title: const Text('Отчет о выполнении')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scenarioName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Отчет о выполнении сценария',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (provider.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (logEntries.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Нет информации о выполнении',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: logEntries.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final entry = logEntries[index];

                  // Определяем иконку и цвет в зависимости от типа записи
                  IconData icon = Icons.info_outline;
                  Color color = Colors.blue;
                  bool isHeader = false;

                  if (entry.contains('🔵')) {
                    icon = Icons.play_circle_outline;
                    color = Colors.blue;
                    isHeader = true;
                  } else if (entry.contains('✅')) {
                    icon = Icons.check_circle_outline;
                    color = Colors.green;
                  } else if (entry.contains('❌') || entry.contains('🔴')) {
                    icon = Icons.error_outline;
                    color = Colors.red;
                  } else if (entry.contains('⚠️')) {
                    icon = Icons.warning_amber_outlined;
                    color = Colors.orange;
                  } else if (entry.contains('⏱️')) {
                    icon = Icons.timer_outlined;
                    color = Colors.amber;
                  } else if (entry.contains('🔹')) {
                    icon = Icons.electric_bolt;
                    color = Colors.blue[300]!;
                  } else if (entry.contains('📊')) {
                    icon = Icons.assessment_outlined;
                    color = Colors.purple;
                    isHeader = true;
                  }

                  // Очищаем эмодзи из текста
                  final cleanEntry =
                      entry
                          .replaceAll('🔵', '')
                          .replaceAll('✅', '')
                          .replaceAll('❌', '')
                          .replaceAll('🔴', '')
                          .replaceAll('⚠️', '')
                          .replaceAll('⏱️', '')
                          .replaceAll('🔹', '')
                          .replaceAll('📊', '')
                          .trim();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      elevation: isHeader ? 2 : 1,
                      color: isHeader ? color.withOpacity(0.1) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side:
                            isHeader
                                ? BorderSide(color: color.withOpacity(0.3))
                                : BorderSide.none,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, color: color, size: 20),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                cleanEntry,
                                style: TextStyle(
                                  fontSize: isHeader ? 16 : 14,
                                  fontWeight:
                                      isHeader
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (provider.error != null)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
