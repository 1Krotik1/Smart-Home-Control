import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/device_provider.dart';
import '../providers/scenario_provider.dart'; // Добавляем импорт ScenarioProvider
import '../widgets/device_tile.dart';
import 'add_device_screen.dart';
import 'scenario_list_screen.dart'; // Добавляем импорт экрана сценариев
import 'edit_scenario_screen.dart'; // Добавляем импорт экрана редактирования сценария

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _selectedIndex = 0; // Добавляем индекс выбранной вкладки

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();

    // Загрузка устройств и сценариев при запуске приложения
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDevices(context);

      // Инициализируем загрузку сценариев
      Provider.of<ScenarioProvider>(context, listen: false).clearError();
    });
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
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar:
          _buildBottomNavigationBar(), // Добавляем нижнюю навигацию
    );
  }

  // Создаем метод для построения AppBar в зависимости от выбранной вкладки
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        _selectedIndex == 0 ? 'Система управления умным домом' : 'Сценарии',
      ),
      elevation: 2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      actions:
          _selectedIndex == 0
              ? [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _refreshDevices(context),
                  tooltip: 'Обновить устройства',
                ),
              ]
              : null,
    );
  }

  // Создаем метод для построения FloatingActionButton в зависимости от выбранной вкладки
  Widget? _buildFloatingActionButton() {
    return FloatingActionButton(
      heroTag: _selectedIndex == 0 ? 'devices_fab' : 'scenarios_fab',
      onPressed:
          _selectedIndex == 0
              ? () => _navigateToAddDevice(context)
              : () => _navigateToEditScenario(context),
      tooltip: _selectedIndex == 0 ? 'Добавить устройство' : 'Создать сценарий',
      backgroundColor: Theme.of(context).colorScheme.secondary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.add),
    );
  }

  // Создаем метод для построения BottomNavigationBar
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      selectedItemColor: Theme.of(context).colorScheme.secondary,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.devices), label: 'Устройства'),
        BottomNavigationBarItem(
          icon: Icon(Icons.auto_awesome),
          label: 'Сценарии',
        ),
      ],
    );
  }

  Widget _buildBody() {
    // В зависимости от выбранной вкладки показываем разные экраны
    return _selectedIndex == 0
        ? _buildDevicesScreen()
        : const ScenarioListScreen();
  }

  // Экран устройств (бывший _buildBody)
  Widget _buildDevicesScreen() {
    return Consumer<DeviceProvider>(
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
                    'Ошибка подключения',
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
                      onPressed: () => _refreshDevices(context),
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

        if (provider.devices.isEmpty) {
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
                      'https://cdn-icons-png.flaticon.com/512/2777/2777154.png',
                      width: 120,
                      height: 120,
                      errorBuilder:
                          (ctx, obj, stack) => const Icon(
                            Icons.devices,
                            size: 120,
                            color: Color(0xFF3498DB),
                          ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Устройства не найдены',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Добавьте новое устройство или выполните поиск в сети',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 250,
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToAddDevice(context),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Добавить устройство'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 250,
                      child: OutlinedButton.icon(
                        onPressed: () => _discoverDevices(context),
                        icon: const Icon(Icons.search),
                        label: const Text('Поиск устройств'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.secondary,
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

        return RefreshIndicator(
          onRefresh: () => _refreshDevices(context),
          color: Theme.of(context).colorScheme.secondary,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              itemCount: provider.devices.length,
              itemBuilder: (context, index) {
                final device = provider.devices[index];
                return DeviceTile(
                  device: device,
                  onToggle: (relayId) => _toggleRelay(context, index, relayId),
                  onRefresh: () => _refreshSingleDevice(context, index),
                  onDelete: () => _removeDevice(context, index),
                  onRenameRelay:
                      (relayId, newName) =>
                          _renameRelay(context, index, relayId, newName),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshDevices(BuildContext context) async {
    await Provider.of<DeviceProvider>(
      context,
      listen: false,
    ).refreshAllDevices();
  }

  Future<void> _refreshSingleDevice(BuildContext context, int index) async {
    await Provider.of<DeviceProvider>(
      context,
      listen: false,
    ).refreshDevice(index);
  }

  Future<void> _toggleRelay(
    BuildContext context,
    int deviceIndex,
    int relayId,
  ) async {
    await Provider.of<DeviceProvider>(
      context,
      listen: false,
    ).toggleRelay(deviceIndex, relayId);
  }

  Future<void> _renameRelay(
    BuildContext context,
    int deviceIndex,
    int relayId,
    String newName,
  ) async {
    await Provider.of<DeviceProvider>(
      context,
      listen: false,
    ).setRelayName(deviceIndex, relayId, newName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Имя реле успешно изменено'),
          backgroundColor: Color(0xFF1ABC9C),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _discoverDevices(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Поиск устройств в сети...'),
        duration: Duration(seconds: 2),
      ),
    );

    final provider = Provider.of<DeviceProvider>(context, listen: false);
    await provider.discoverDevices();

    if (mounted && provider.devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Устройства не найдены. Проверьте подключение к WiFi.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _removeDevice(BuildContext context, int index) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Удалить устройство'),
            content: const Text(
              'Вы уверены, что хотите удалить это устройство из списка?',
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
                  Provider.of<DeviceProvider>(
                    context,
                    listen: false,
                  ).removeDevice(index);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Устройство удалено'),
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

  void _navigateToAddDevice(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddDeviceScreen()),
    );
  }

  // Добавляем метод для перехода к созданию сценария
  void _navigateToEditScenario(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                const EditScenarioScreen(), // Переходим сразу к созданию сценария
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
}
