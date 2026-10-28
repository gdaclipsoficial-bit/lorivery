import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbox/theme/app_theme.dart';
import 'package:chatbox/services/features/auth/presentation/screens/auth_screen.dart';
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/services/notification_service.dart';
import 'package:chatbox/services/background_service.dart';

import 'package:chatbox/services/features/splash/splash_screen.dart';

/// Entry point para la App del CLIENTE
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializar notificaciones y servicio de background
  await NotificationService().initialize();
  await initBackgroundService();
  print('🛒 LORICA CLIENTE - URL: ${ApiConfig.baseUrl}');
  runApp(
    ProviderScope(
      overrides: [
        appRoleProvider.overrideWithValue('CLIENT'),
      ],
      child: const LoricaClienteApp(),
    ),
  );
}

class LoricaClienteApp extends StatelessWidget {
  const LoricaClienteApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lorica Delivery',
      theme: AppTheme.clientTheme,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

