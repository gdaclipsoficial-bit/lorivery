import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/features/auth/presentation/screens/auth_screen.dart';

class ActiveTripScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> orderData;

  const ActiveTripScreen({Key? key, required this.orderData}) : super(key: key);

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen> {
  final MapController _mapController = MapController();
  bool _isLoading = false;
  String _currentStatus = 'READY'; 

  void _logout(BuildContext context) {
    ref.invalidate(authProvider);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _updateOrderStatus(String nextStatus, {String? pickupCode, String? deliveryCode}) async {
    setState(() => _isLoading = true);
    final orderId = widget.orderData['order_id'];
    final token = ref.read(authProvider).token;

    try {
      final Map<String, dynamic> bodyData = {'status': nextStatus};
      if (pickupCode != null) bodyData['pickup_code'] = pickupCode;
      if (deliveryCode != null) bodyData['delivery_code'] = deliveryCode;

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bodyData),
      );

      if (response.statusCode == 200) {
        if (nextStatus == 'DELIVERED') {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('¡Entrega completada con éxito!'), backgroundColor: Colors.green),
            );
          }
        } else {
          setState(() => _currentStatus = nextStatus);
        }
      } else {
        final errorResponse = jsonDecode(response.body);
        throw Exception(errorResponse['detail'] ?? 'Error al actualizar estado');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPinDialog(String nextStatus, {bool isDelivery = false}) {
    final TextEditingController pinController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isDelivery ? 'Confirmar Entrega al Cliente' : 'Confirmar Recogida'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: InputDecoration(
            labelText: isDelivery ? 'PIN de 4 dígitos del Cliente' : 'PIN de 4 dígitos del Restaurante',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancelar')
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (pinController.text.length == 4) {
                if (isDelivery) {
                  _updateOrderStatus(nextStatus, deliveryCode: pinController.text);
                } else {
                  _updateOrderStatus(nextStatus, pickupCode: pinController.text);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El PIN debe ser de 4 dígitos'), backgroundColor: Colors.orange),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: isDelivery ? Colors.green : Colors.orange),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extracción robusta de los datos de la orden
    final restaurantName = widget.orderData['restaurant_name'] ?? widget.orderData['restaurant'] ?? 'Restaurante Local';
    final restaurantAddress = widget.orderData['restaurant_address'] ?? 'Calle Principal #10-20, Lorica';
    final deliveryAddress = widget.orderData['delivery_address'] ?? widget.orderData['destination'] ?? 'Barrio Centro, Lorica';
    final earnings = widget.orderData['earnings'] ?? '\$3.000';

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(9.2389, -75.8139),
              initialZoom: 15.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.chatbox',
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.black87),
                    ),
                  ),
                  InkWell(
                    onTap: () => _logout(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('MODO RUTA / GPS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      Text(earnings, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                  const Divider(height: 30),
                  
                  // Parada 1: Restaurante
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.storefront_rounded, color: Colors.orange, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Paso 1: Recoger en', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(restaurantName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(restaurantAddress, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.only(left: 21, top: 4, bottom: 4),
                    child: Container(width: 2, height: 24, color: Colors.green.shade400),
                  ),

                  // Parada 2: Cliente
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.location_on_rounded, color: Colors.green, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Paso 2: Entregar a cliente en', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(deliveryAddress, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () {
                        if (_currentStatus == 'READY') {
                          _updateOrderStatus('AT_RESTAURANT');
                        } else if (_currentStatus == 'AT_RESTAURANT') {
                          _showPinDialog('PICKED_UP', isDelivery: false);
                        } else if (_currentStatus == 'PICKED_UP') {
                          _showPinDialog('DELIVERED', isDelivery: true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getButtonColor(),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _getButtonText(),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getButtonText() {
    switch (_currentStatus) {
      case 'READY': return 'LLEGUÉ AL RESTAURANTE';
      case 'AT_RESTAURANT': return 'INGRESAR PIN DE RECOGIDA';
      case 'PICKED_UP': return 'CONFIRMAR ENTREGA (PIN CLIENTE)';
      default: return 'PROCESANDO...';
    }
  }

  Color _getButtonColor() {
    switch (_currentStatus) {
      case 'READY': return Colors.blueAccent;
      case 'AT_RESTAURANT': return Colors.orange;
      case 'PICKED_UP': return Colors.green;
      default: return Colors.grey;
    }
  }
}