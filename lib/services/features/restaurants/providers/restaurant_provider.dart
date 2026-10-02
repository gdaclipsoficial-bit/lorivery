import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:chatbox/core/config/api_config.dart';

// Modelo de datos para el Restaurante
class Restaurant {
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;

  Restaurant({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Sin nombre',
      description: json['description'],
      logoUrl: json['logo_url'], // Asegúrate de que coincida con el nombre del campo en PostgreSQL/FastAPI
    );
  }
}

// Provider que consume el endpoint de FastAPI
final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  try {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/restaurants'));

    if (response.statusCode == 200) {
      // Si el backend usa UTF-8, forzamos la decodificación para evitar caracteres raros en español
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Restaurant.fromJson(json)).toList();
    } else {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
  } catch (e) {
    print('🔥 ERROR REAL DE CONEXIÓN: $e');
    throw Exception('No se pudo conectar al servidor. Revisa tu ApiConfig y conexión de red.');
  }
});