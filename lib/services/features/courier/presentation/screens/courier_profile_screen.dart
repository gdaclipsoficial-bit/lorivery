import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/services/features/auth/presentation/screens/auth_screen.dart';
import 'package:chatbox/services/features/support/support_modal.dart';
import 'package:chatbox/theme/app_theme.dart';

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

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _profile = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(dynamic amount) {
    final val = (amount is num) ? amount.toDouble() : 0.0;
    return '\$${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')} COP';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.courierScaffoldBg,
        body: Center(child: CircularProgressIndicator(color: AppColors.courierGreenNeon)),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: AppColors.courierScaffoldBg,
        appBar: AppBar(
          title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.courierSurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text('Error al cargar perfil del repartidor', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final balance = _profile!['balance'] ?? 0.0;
    final rating = _profile!['rating'] ?? 5.0;

    return Scaffold(
      backgroundColor: AppColors.courierScaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Perfil & Ganancias',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        backgroundColor: AppColors.courierSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_rounded, color: AppColors.courierCyan),
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
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TARJETA DE REPUTACIÓN Y CALIFICACIÓN
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.courierCardBg,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.courierBorder, width: 1.2),
                boxShadow: AppShadows.courierCard,
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.courierGreenNeon.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.courierGreenNeon, width: 1.5),
                    ),
                    child: const Icon(Icons.two_wheeler_rounded, color: AppColors.courierGreenNeon, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profile!['name'] ?? 'Repartidor Lorivery',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB300).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFFB300), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 15),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$rating / 5.0',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFFFFB300)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.courierGreenNeon.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.courierGreenNeon, width: 1),
                              ),
                              child: const Text(
                                'Verificado',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.courierGreenNeon),
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

            const SizedBox(height: 18),

            // TARJETA DE GANANCIAS (BILLETERA OPERATIVA SOY RAPPI)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E2836), Color(0xFF151C24)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: const Color(0xFF2E3D4F), width: 1.2),
                boxShadow: AppShadows.courierCard,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.courierGreenNeon.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.courierGreenNeon, width: 1.2),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.courierGreenNeon, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GANANCIAS ACUMULADAS',
                        style: TextStyle(
                          color: AppColors.courierTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatCurrency(balance),
                        style: const TextStyle(
                          color: AppColors.courierGreenNeon,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // DATOS DE LA CUENTA
            const Text(
              'Información del Repartidor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3),
            ),
            const SizedBox(height: 12),
            
            Container(
              decoration: BoxDecoration(
                color: AppColors.courierCardBg,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.courierBorder, width: 1.2),
                boxShadow: AppShadows.courierCard,
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_rounded, color: AppColors.courierCyan),
                    title: const Text('Correo Electrónico', style: TextStyle(fontSize: 11, color: AppColors.courierTextSecondary)),
                    subtitle: Text(_profile!['email'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                  ),
                  const Divider(height: 1, indent: 56, color: AppColors.courierBorder),
                  ListTile(
                    leading: const Icon(Icons.badge_rounded, color: AppColors.courierAmber),
                    title: const Text('Documento de Identidad', style: TextStyle(fontSize: 11, color: AppColors.courierTextSecondary)),
                    subtitle: Text(_profile!['national_id'] ?? 'En verificación', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                  ),
                  const Divider(height: 1, indent: 56, color: AppColors.courierBorder),
                  ListTile(
                    leading: const Icon(Icons.phone_rounded, color: AppColors.courierGreenNeon),
                    title: const Text('Teléfono de Contacto', style: TextStyle(fontSize: 11, color: AppColors.courierTextSecondary)),
                    subtitle: Text(_profile!['phone_number'] ?? 'No registrado', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                  ),
                  const Divider(height: 1, indent: 56, color: AppColors.courierBorder),
                  ListTile(
                    leading: const Icon(Icons.two_wheeler_rounded, color: Colors.white),
                    title: const Text('Vehículo', style: TextStyle(fontSize: 11, color: AppColors.courierTextSecondary)),
                    subtitle: Text(_profile!['vehicle_type'] == 'BICYCLE' ? 'Bicicleta' : 'Motocicleta', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // BOTÓN CERRAR SESIÓN
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                  foregroundColor: const Color(0xFFFF5252),
                ),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
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
