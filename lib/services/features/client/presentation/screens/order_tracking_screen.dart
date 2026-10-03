import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/services/features/auth/presentation/screens/auth_screen.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderTrackingScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  int _currentStep = 0; 
  String _deliveryCode = '...';
  Map<String, dynamic>? _courier;
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    // 1. Cargar inmediatamente al abrir la pantalla[cite: 7, 8]
    _fetchOrderData();
    
    // 2. Consultar a FastAPI cada 5 segundos por actualizaciones reales[cite: 7, 8]
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentStep < 6) {
        _fetchOrderData();
      } else {
        timer.cancel(); // Si ya se entregó, dejamos de consultar[cite: 7, 8]
      }
    });
  }

  Future<void> _fetchOrderData() async {
    try {
      final token = ref.read(authProvider).token;
      
      final uri = Uri.parse('${ApiConfig.baseUrl}/orders/${widget.orderId}');
      
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (mounted) {
          setState(() {
            _deliveryCode = data['delivery_code']?.toString() ?? '...';
            if (data['courier'] != null) {
              _courier = data['courier'];
            }
            _isLoading = false;
            
            // Normalizamos a minúsculas para que coincida perfectamente sin importar cómo lo envíe FastAPI
            final status = data['status']?.toString().toLowerCase() ?? '';
            
            switch (status) {
              case 'pending_payment':
                _currentStep = 0;
                break;
              case 'created':
              case 'approved':
              case 'ready':
                _currentStep = 1;
                break;
              case 'assigned':
              case 'at_restaurant':
                _currentStep = 2;
                break;
              case 'picked_up':
              case 'on_the_way':
                _currentStep = 3;
                break;
              case 'delivered':
                _currentStep = 4;
                _pollingTimer?.cancel();
                _showDeliveryCompleteDialog(context);
                break;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error consultando la orden: $e");
    }
  }

  void _showDeliveryCompleteDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Text('¡Pedido Entregado!'),
          ],
        ),
        content: const Text('Tu pedido ha sido entregado con éxito. ¡Esperamos que lo disfrutes!'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              // Cierra el diálogo y regresa limpiamente al inicio guardado en la pila
              Navigator.of(dialogContext, rootNavigator: true).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Volver al inicio', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Seguimiento de Pedido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, 
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
        : SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // TARJETA DE CÓDIGO DE ENTREGA Y ORDEN
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, Colors.blue.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Column(
                    children: [
                      Text('Orden: ${widget.orderId}', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                      const SizedBox(height: 8),
                      const Text('Código de Entrega', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(
                        _deliveryCode,
                        style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 4),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: const Text('Muéstrale este código al repartidor', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                const Text('Estado del pedido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),

                // LÍNEA DE TIEMPO INTERACTIVA
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      _buildTrackingStep(
                        context,
                        stepIndex: 1,
                        title: 'Pago Aprobado',
                        subtitle: 'Tu orden fue validada. Buscando repartidor...',
                        icon: Icons.check_circle_rounded,
                        isLast: false,
                      ),
                      _buildTrackingStep(
                        context,
                        stepIndex: 2,
                        title: 'En camino al restaurante',
                        subtitle: 'El repartidor aceptó tu pedido y va hacia el restaurante.',
                        icon: Icons.storefront_rounded,
                        isLast: false,
                      ),
                      _buildTrackingStep(
                        context,
                        stepIndex: 3,
                        title: 'En camino a tu domicilio',
                        subtitle: 'El repartidor ya ingresó el código del negocio y lleva tu comida.',
                        icon: Icons.motorcycle_rounded,
                        isLast: false,
                      ),
                      _buildTrackingStep(
                        context,
                        stepIndex: 4,
                        title: 'Pedido Entregado',
                        subtitle: '¡Disfruta tu pedido!',
                        icon: Icons.task_alt_rounded,
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // DATOS REALES DEL REPARTIDOR
                if (_currentStep >= 2 && _courier != null) ...[
                  const Text('Tu Repartidor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundImage: _courier!['photo_url'] != null 
                              ? NetworkImage('${ApiConfig.baseUrl}${_courier!['photo_url']}')
                              : const NetworkImage('https://i.pravatar.cc/150?img=11'), 
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_courier!['name'] ?? 'Repartidor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('${_courier!['vehicle_model'] ?? 'Moto'} - ${_courier!['plate'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.phone, color: Colors.green, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),
      ),
    );
  }

  Widget _buildTrackingStep(
    BuildContext context, {
    required int stepIndex,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isLast,
  }) {
    final theme = Theme.of(context);
    final isActive = _currentStep == stepIndex;
    final isCompleted = _currentStep > stepIndex;
    final isPending = _currentStep < stepIndex;

    Color iconColor = Colors.grey.shade400;
    Color circleColor = Colors.grey.shade100;
    
    if (isCompleted) {
      iconColor = Colors.white;
      circleColor = Colors.green;
    } else if (isActive) {
      iconColor = Colors.white;
      circleColor = theme.colorScheme.primary;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  border: isPending ? Border.all(color: Colors.grey.shade300, width: 2) : null,
                ),
                child: Icon(
                  isCompleted ? Icons.check_rounded : icon,
                  color: isPending ? Colors.grey.shade400 : iconColor,
                  size: 20,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? Colors.green : Colors.grey.shade200,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                      color: isPending ? Colors.grey.shade500 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isActive ? 'Actualizando...' : subtitle,
                    style: TextStyle(
                      color: isActive ? theme.colorScheme.primary : Colors.grey.shade500,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
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
}