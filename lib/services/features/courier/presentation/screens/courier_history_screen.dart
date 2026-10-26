import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/services/features/auth/presentation/screens/auth_screen.dart';
import 'package:chatbox/theme/app_theme.dart';

class CourierOrderHistoryScreen extends ConsumerStatefulWidget {
  const CourierOrderHistoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CourierOrderHistoryScreen> createState() => _CourierOrderHistoryScreenState();
}

class _CourierOrderHistoryScreenState extends ConsumerState<CourierOrderHistoryScreen> {
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
        Uri.parse('${ApiConfig.baseUrl}/orders/courier/history'),
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
          _error = 'Error al cargar entregas: ${response.statusCode}';
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
        return AppColors.courierGreenNeon;
      case 'assigned':
      case 'at_restaurant':
      case 'picked_up':
      case 'on_the_way':
        return AppColors.courierCyan;
      default:
        return AppColors.courierTextSecondary;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return 'Entregado';
      case 'assigned':
      case 'at_restaurant':
        return 'Rumbo al negocio';
      case 'picked_up':
      case 'on_the_way':
        return 'En camino a cliente';
      default:
        return status.toUpperCase();
    }
  }

  String _formatCurrency(dynamic amount) {
    final val = (amount is num) ? amount.toDouble() : 3000.0;
    return '\$${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')} COP';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.courierScaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Historial de Entregas',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.courierSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.courierGreenNeon),
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.courierGreenNeon))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252), size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() { _isLoading = true; _error = null; });
                            _fetchHistory();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.courierGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Reintentar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                              color: AppColors.courierSurfaceElevated,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.courierBorder, width: 1.5),
                            ),
                            child: const Icon(Icons.two_wheeler_rounded, size: 40, color: AppColors.courierGreenNeon),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Aún no has completado entregas',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Conéctate al radar para recibir pedidos cercanos.',
                            style: TextStyle(color: AppColors.courierTextSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.courierGreenNeon,
                      backgroundColor: AppColors.courierSurface,
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

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: AppColors.courierCardBg,
                              borderRadius: BorderRadius.circular(AppRadius.card),
                              boxShadow: AppShadows.courierCard,
                              border: Border.all(color: AppColors.courierBorder, width: 1.2),
                            ),
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
                                              color: AppColors.courierGreenNeon.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: AppColors.courierGreenNeon, width: 1),
                                            ),
                                            child: const Icon(Icons.attach_money_rounded, color: AppColors.courierGreenNeon, size: 22),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _formatCurrency(item['delivery_fee']),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 18,
                                                  color: AppColors.courierGreenNeon,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                              Text(
                                                'Cliente: ${item['client_name'] ?? 'Cliente'}',
                                                style: const TextStyle(color: AppColors.courierTextSecondary, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: statusColor, width: 1),
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
                                    child: Divider(color: AppColors.courierBorder, height: 1),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.storefront_rounded, size: 14, color: AppColors.courierAmber),
                                              const SizedBox(width: 4),
                                              Text(
                                                item['restaurant_name'] ?? 'Restaurante',
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on_rounded, size: 14, color: AppColors.courierCyan),
                                              const SizedBox(width: 4),
                                              Text(
                                                item['delivery_address'] ?? 'Lorica',
                                                style: const TextStyle(fontSize: 12, color: AppColors.courierTextSecondary),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Recogida: ${item['pickup_code'] ?? '----'}',
                                            style: const TextStyle(fontSize: 11, color: AppColors.courierTextSecondary),
                                          ),
                                          Text(
                                            'Entrega: ${item['delivery_code'] ?? '----'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.courierCyan,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
