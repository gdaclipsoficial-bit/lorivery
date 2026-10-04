import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/services/features/auth/presentation/screens/auth_screen.dart';
import 'package:chatbox/services/features/support/support_modal.dart';

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
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F7),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE60000))),
      );
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Perfil')),
        body: const Center(child: Text('Error al cargar perfil')),
      );
    }

    final balance = _profile!['balance'] ?? 0.0;
    final rating = _profile!['rating'] ?? 5.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text(
          'Perfil & Calificaciones',
          style: TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_rounded, color: Color(0xFFE60000)),
            tooltip: 'Soporte Repartidor',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const SupportHelpModal(),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            
            // TARJETA DE REPUTACIÓN Y CALIFICACIÓN
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFE60000).withOpacity(0.1),
                    child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFFE60000), size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profile!['name'] ?? 'Repartidor',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF111111)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(980),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$rating / 5.0',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(980),
                              ),
                              child: const Text(
                                'Verificado',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF34C759)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // TARJETA DE GANANCIAS (BILLETERA LORIVERY)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 6)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE60000),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ganancias Acumuladas', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        '\$${balance.toStringAsFixed(0)} COP', 
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // DATOS DE LA CUENTA
            const Text('Información del Repartidor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111111))),
            const SizedBox(height: 10),
            
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: Colors.black54),
                    title: const Text('Correo Electrónico', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(_profile!['email'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined, color: Colors.black54),
                    title: const Text('Documento de Identidad', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(_profile!['national_id'] ?? 'En verificación', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined, color: Colors.black54),
                    title: const Text('Teléfono de Contacto', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(_profile!['phone_number'] ?? 'No registrado', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.two_wheeler_outlined, color: Colors.black54),
                    title: const Text('Vehículo', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(_profile!['vehicle_type'] == 'BICYCLE' ? 'Bicicleta' : 'Motocicleta', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // BOTÓN CERRAR SESIÓN
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFE60000),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFE60000), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(980)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                onPressed: () => AuthNotifier.performLogout(context, ref),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
