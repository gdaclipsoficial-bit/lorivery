import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbox/theme/app_theme.dart';
import 'package:chatbox/services/features/auth/presentation/screens/auth_screen.dart';
import 'package:chatbox/core/config/api_config.dart';

/// Entry point para la App del REPARTIDOR
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  print('🏍️ LORICA REPARTIDOR - URL: ${ApiConfig.baseUrl}');
  runApp(
    ProviderScope(
      overrides: [
        appRoleProvider.overrideWithValue('COURIER'),
      ],
      child: const LoricaRepartidorApp(),
    ),
  );
}

class LoricaRepartidorApp extends StatelessWidget {
  const LoricaRepartidorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lorica Repartidor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        fontFamily: 'Poppins',
        useMaterial3: true,
      ),
      home: const AuthScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

