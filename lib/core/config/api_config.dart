import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider global para identificar el Flavor (CLIENT o COURIER)
final appRoleProvider = Provider<String>((ref) => 'CLIENT');

class ApiConfig {
  // Configurado con ADB Reverse (el celular redirige el tráfico USB a tu PC)
  static const String baseUrl = 'http://127.0.0.1:8000';
  static const String wsUrl = 'ws://127.0.0.1:8000';
}


