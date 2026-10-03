import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/services/features/auth/presentation/screens/auth_screen.dart';
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
        return Colors.green;
      case 'assigned':
      case 'at_restaurant':
      case 'picked_up':
      case 'on_the_way':
        return Colors.blue;
      case 'created':
      case 'approved':
      case 'ready':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return 'Entregado';
      case 'assigned':
      case 'at_restaurant':
        return 'En camino al restaurante';
      case 'picked_up':
      case 'on_the_way':
        return 'En camino a tu domicilio';
      case 'created':
      case 'approved':
      case 'ready':
        return 'Buscando repartidor';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Mis Pedidos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() { _isLoading = true; _error = null; });
              _fetchHistory();
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () { setState(() { _isLoading = true; _error = null; }); _fetchHistory(); },
                        child: const Text('Reintentar'),
                      )
                    ],
                  ),
                )
              : _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('Aún no has realizado pedidos', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
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
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: primaryColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Icon(Icons.restaurant, color: primaryColor, size: 20),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item['restaurant_name'] ?? 'Restaurante',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                  Text(
                                                    'Orden #${item['order_id'].toString().substring(0, item['order_id'].toString().length > 8 ? 8 : item['order_id'].toString().length)}',
                                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              statusText,
                                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text(
                                                item['delivery_address'] ?? 'Lorica',
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Text('Código: ', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                                              Text(
                                                '${item['delivery_code'] ?? '----'}',
                                                style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 14),
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
