import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/device_provider.dart';
import 'providers/scenario_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => DeviceProvider()),
        ChangeNotifierProxyProvider<DeviceProvider, ScenarioProvider>(
          create: (context) => ScenarioProvider(),
          update: (context, deviceProvider, scenarioProvider) {
            if (scenarioProvider != null) {
              scenarioProvider.deviceProvider = deviceProvider;
            }
            return scenarioProvider ?? ScenarioProvider();
          },
        ),
      ],
      child: MaterialApp(
        title: 'Smart Home Control',
        debugShowCheckedModeBanner: false, // Убираем баннер debug
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2C3E50),
            primary: const Color(0xFF2C3E50),
            secondary: const Color(0xFF3498DB),
            tertiary: const Color(0xFF1ABC9C),
            background: const Color(0xFFF5F7FA),
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: Color(0xFF2C3E50),
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
          cardTheme: CardTheme(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: const BorderSide(color: Color(0xFF3498DB)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF3498DB), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          fontFamily: 'Roboto',
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
