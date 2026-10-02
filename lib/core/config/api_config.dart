import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider global para identificar el Flavor (CLIENT o COURIER)
final appRoleProvider = Provider<String>((ref) => 'CLIENT');

class ApiConfig {
  // Producción en Render
  static const String baseUrl = 'https://lorivery.onrender.com';
  static const String wsUrl = 'wss://lorivery.onrender.com';
}


