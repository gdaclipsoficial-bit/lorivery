import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/services/features/auth/presentation/screens/auth_screen.dart';
import 'package:chatbox/theme/app_theme.dart';
import 'order_tracking_screen.dart';

class ClientOrderHistoryScreen extends ConsumerStatefulWidget {
  const ClientOrderHistoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ClientOrderHistoryScreen> createState() => _ClientOrderHistoryScreenState();
}

class _ClientOrderHistoryScreenState extends ConsumerState<ClientOrderHistoryScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final token = ref.read(authProvider).token;
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/orders/my-orders'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _orders = data['orders'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error al cargar historial: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error de conexión: $e';
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return const Color(0xFF2E7D32);
      case 'assigned':
      case 'at_restaurant':
      case 'picked_up':
      case 'on_the_way':
        return const Color(0xFF00B0FF);
      case 'created':
      case 'approved':
      case 'ready':
      case 'pending_payment':
        return const Color(0xFFFF9100);
      default:
        return Colors.grey.shade600;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return 'Entregado';
      case 'assigned':
      case 'at_restaurant':
        return 'En restaurante';
      case 'picked_up':
      case 'on_the_way':
        return 'En camino';
      case 'created':
      case 'approved':
      case 'ready':
        return 'Buscando motorizado';
      case 'pending_payment':
        return 'Verificando pago';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.clientScaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Mis Pedidos',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: AppColors.clientTextPrimary,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.clientTextPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.loriveryRed),
            onPressed: () {
              setState(() { _isLoading = true; _error = null; });
              _fetchHistory();
            },
            tooltip: 'Actualizar',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.loriveryRed))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.loriveryRed, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() { _isLoading = true; _error = null; });
                            _fetchHistory();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.loriveryRed,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.loriveryRedLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.receipt_long_rounded, size: 40, color: AppColors.loriveryRed),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Aún no tienes pedidos registrados',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.clientTextPrimary),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '¡Pide tus platos favoritos y recíbelos en minutos!',
                            style: TextStyle(color: AppColors.clientTextSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.loriveryRed,
                      onRefresh: _fetchHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final item = _orders[index];
                          final status = item['status']?.toString() ?? '';
                          final statusColor = _getStatusColor(status);
                          final statusText = _getStatusText(status);
                          final orderIdStr = item['order_id']?.toString() ?? item['id']?.toString() ?? '';
                          final shortId = orderIdStr.length > 8 ? orderIdStr.substring(0, 8) : orderIdStr;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppRadius.card),
                              boxShadow: AppShadows.clientCard,
                              border: Border.all(color: AppColors.clientBorder, width: 0.8),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadius.card),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppRadius.card),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OrderTrackingScreen(orderId: item['order_id']),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: AppColors.loriveryRedLight,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Icon(Icons.restaurant_rounded, color: AppColors.loriveryRed, size: 22),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item['restaurant_name'] ?? 'Restaurante Local',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 16,
                                                      color: AppColors.clientTextPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Orden #$shortId',
                                                    style: const TextStyle(color: AppColors.clientTextSecondary, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1),
                                            ),
                                            child: Text(
                                              statusText,
                                              style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Divider(color: AppColors.clientBorder, height: 1),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on_rounded, size: 16, color: AppColors.clientTextSecondary),
                                              const SizedBox(width: 4),
                                              Text(
                                                item['delivery_address'] ?? 'Lorica Centro',
                                                style: const TextStyle(
                                                  color: AppColors.clientTextSecondary,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              const Text(
                                                'PIN Entrega: ',
                                                style: TextStyle(color: AppColors.clientTextSecondary, fontSize: 13),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.loriveryRedLight,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: AppColors.loriveryRed.withValues(alpha: 0.3)),
                                                ),
                                                child: Text(
                                                  '${item['delivery_code'] ?? '----'}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: AppColors.loriveryRed,
                                                    fontSize: 14,
                                                    letterSpacing: 1.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
