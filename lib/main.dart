import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'services/features/auth/presentation/screens/auth_screen.dart';
import 'core/config/api_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  print('🚀 BASE URL CONFIGURADA: \${ApiConfig.baseUrl}');
  runApp(
    const ProviderScope(
      child: LoricaApp(),
    ),
  );
}

class LoricaApp extends StatelessWidget {
  const LoricaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lorica Delivery',
      theme: AppTheme.lightTheme,
      home: const AuthScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
