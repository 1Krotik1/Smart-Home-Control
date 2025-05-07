import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/scenario_provider.dart';
import '../widgets/scenario_tile.dart';
import 'edit_scenario_screen.dart';
import 'scenario_log_screen.dart';

class ScenarioListScreen extends StatefulWidget {
  const ScenarioListScreen({super.key});

  @override
  State<ScenarioListScreen> createState() => _ScenarioListScreenState();
}

class _ScenarioListScreenState extends State<ScenarioListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _buildBody(),
      // Убираем FloatingActionButton, так как она уже есть в HomeScreen
    );
  }

  Widget _buildBody() {
    return Consumer<ScenarioProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Center(
            child: SpinKitDoubleBounce(
              color: Theme.of(context).colorScheme.secondary,
              size: 60.0,
            ),
          );
        }

        if (provider.error != null) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ошибка',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${provider.error}',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        provider.clearError();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (provider.scenarios.isEmpty) {
          return Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _animationController.value,
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://cdn-icons-png.flaticon.com/512/2784/2784403.png',
                      width: 120,
                      height: 120,
                      errorBuilder:
                          (ctx, obj, stack) => const Icon(
                            Icons.auto_awesome,
                            size: 120,
                            color: Color(0xFF3498DB),
                          ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Сценарии не созданы',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Создайте сценарий для автоматизации управления устройствами',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 250,
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToEditScenario(context),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Создать сценарий'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: provider.scenarios.length,
            itemBuilder: (context, index) {
              final scenario = provider.scenarios[index];
              return ScenarioTile(
                scenario: scenario,
                onEdit: () => _navigateToEditScenario(context, scenario.id),
                onRun: () => _executeScenario(context, scenario.id),
                onDelete: () => _deleteScenario(context, scenario.id),
                onToggleActive:
                    (value) => _toggleScenarioActive(context, scenario.id),
              );
            },
          ),
        );
      },
    );
  }

  void _navigateToEditScenario(BuildContext context, [String? scenarioId]) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                EditScenarioScreen(scenarioId: scenarioId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(1.0, 0.0);
          var end = Offset.zero;
          var curve = Curves.ease;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _executeScenario(BuildContext context, String scenarioId) async {
    final provider = Provider.of<ScenarioProvider>(context, listen: false);
    final scenario = provider.getScenarioById(scenarioId);

    if (scenario == null) {
      return;
    }

    // Показываем индикатор выполнения
    final snackBar = ScaffoldMessenger.of(context).showSnackBar(
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
            Text('Выполнение сценария...'),
          ],
        ),
        duration: Duration(
          seconds: 10,
        ), // Уменьшаем максимальное время ожидания
      ),
    );

    try {
      final success = await provider.executeScenario(scenarioId);

      // Закрываем индикатор прогресса
      snackBar.close();

      // Показываем результат
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Сценарий успешно выполнен'
                : 'Ошибка при выполнении сценария',
          ),
          backgroundColor: success ? const Color(0xFF1ABC9C) : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Подробнее',
            textColor: Colors.white,
            onPressed: () {
              _navigateToLogScreen(context, scenarioId, scenario.name);
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // В случае ошибки закрываем индикатор и показываем сообщение об ошибке
      snackBar.close();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ошибка при выполнении сценария'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Подробнее',
            textColor: Colors.white,
            onPressed: () {
              _navigateToLogScreen(context, scenarioId, scenario.name);
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Переход к экрану лога выполнения сценария
  void _navigateToLogScreen(
    BuildContext context,
    String scenarioId,
    String scenarioName,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ScenarioLogScreen(
              scenarioId: scenarioId,
              scenarioName: scenarioName,
            ),
      ),
    );
  }

  void _deleteScenario(BuildContext context, String scenarioId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Удалить сценарий'),
            content: const Text(
              'Вы уверены, что хотите удалить этот сценарий?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Отмена',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Provider.of<ScenarioProvider>(
                    context,
                    listen: false,
                  ).deleteScenario(scenarioId);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Сценарий удален'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Удалить'),
              ),
            ],
          ),
    );
  }

  Future<void> _toggleScenarioActive(
    BuildContext context,
    String scenarioId,
  ) async {
    await Provider.of<ScenarioProvider>(
      context,
      listen: false,
    ).toggleScenarioActive(scenarioId);
  }
}
