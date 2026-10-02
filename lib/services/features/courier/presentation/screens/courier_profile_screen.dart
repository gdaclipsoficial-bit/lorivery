import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/services/features/auth/presentation/screens/auth_screen.dart';

class CourierProfileScreen extends ConsumerStatefulWidget {
  const CourierProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CourierProfileScreen> createState() => _CourierProfileScreenState();
}

class _CourierProfileScreenState extends ConsumerState<CourierProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final token = ref.read(authProvider).token;
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/couriers/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _profile = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_profile == null) {
      return const Scaffold(body: Center(child: Text('Error al cargar perfil')));
    }

    final theme = Theme.of(context);
    final balance = _profile!['balance'] ?? 0.0;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Mi Perfil y Ganancias', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Tarjeta de Ganancias
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.white, size: 50),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ganancias Totales', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      Text('\$${balance.toStringAsFixed(0)} COP', 
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Datos del Perfil
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: const Text('Nombre'),
                    subtitle: Text(_profile!['name']),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Correo'),
                    subtitle: Text(_profile!['email']),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.badge),
                    title: const Text('Cédula'),
                    subtitle: Text(_profile!['national_id'] ?? 'No registrada'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.phone),
                    title: const Text('Teléfono'),
                    subtitle: Text(_profile!['phone_number'] ?? 'No registrado'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.two_wheeler),
                    title: const Text('Vehículo'),
                    subtitle: Text(_profile!['vehicle_type'] == 'BICYCLE' ? 'Bicicleta' : 'Motocicleta'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: const Text('Calificación'),
                    subtitle: Text('${_profile!['rating']} / 5.0'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

