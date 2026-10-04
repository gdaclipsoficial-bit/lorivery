import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/services/features/auth/presentation/screens/auth_screen.dart';
import 'package:chatbox/services/features/chat/order_chat_dialog.dart';
import 'package:chatbox/services/websocket_service.dart';
import 'package:chatbox/services/features/support/support_modal.dart';
import 'package:chatbox/services/features/rating/courier_rating_modal.dart';

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
  bool _ratingShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(webSocketServiceProvider).connectToOrder(widget.orderId);
    });
    _fetchOrderData();
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_currentStep < 5) {
        _fetchOrderData();
      } else {
        timer.cancel();
      }
    });
  }

  void _applyStatus(String status) {
    final s = status.toLowerCase().trim();
    int newStep = _currentStep;

    if (s == 'created' || s == 'pending_payment') {
      newStep = 0;
    } else if (s == 'approved_by_admin') {
      newStep = 1; // En preparación en restaurante
    } else if (s == 'ready') {
      newStep = 2; // Listo / Asignando repartidor
    } else if (s == 'assigned' || s == 'at_restaurant') {
      newStep = 3; // Repartidor en camino al restaurante
    } else if (s == 'picked_up' || s == 'on_the_way') {
      newStep = 4; // En camino a tu domicilio
    } else if (s == 'delivered') {
      newStep = 5; // Entregado
    }

    if (newStep != _currentStep) {
      setState(() => _currentStep = newStep);
      if (newStep == 5 && !_ratingShown) {
        _ratingShown = true;
        _pollingTimer?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showDeliveryCompleteDialog(context);
        });
      }
    }
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
          });
          
          final status = data['status']?.toString() ?? '';
          _applyStatus(status);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('¡Pedido Entregado!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Tu comida ha sido entregada. ¡Buen provecho!\n\n¿Deseas calificar la atención y rapidez de tu repartidor?',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext, rootNavigator: true).pop();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CourierRatingModal(
                  orderId: widget.orderId,
                  courierName: _courier?['name'] ?? 'Repartidor',
                ),
              );
            },
            child: const Text('⭐ Calificar Repartidor', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE60000),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(980)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () {
              Navigator.of(dialogContext, rootNavigator: true).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Inicio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    // Escuchar websocket para cambios instantáneos
    final wsService = ref.watch(webSocketServiceProvider);
    final lastStatus = wsService.lastStatusUpdate;
    if (lastStatus != null && lastStatus['status'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyStatus(lastStatus['status']);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text(
          'Rastreo del Pedido',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF111111)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_rounded, color: Color(0xFFE60000), size: 26),
            tooltip: 'Soporte y Quejas',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => SupportHelpModal(orderId: widget.orderId),
              );
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFE60000)))
        : SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                // TARJETA DE CÓDIGO DE ENTREGA ESTILO IOS
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ORDEN #${widget.orderId.substring(0, widget.orderId.length > 8 ? 8 : widget.orderId.length).toUpperCase()}',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE60000),
                              borderRadius: BorderRadius.circular(980),
                            ),
                            child: const Text('En Vivo', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Código de Entrega al Repartidor',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _deliveryCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Dile este número al domiciliario cuando llegue a tu casa',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                const Text('Progreso de la Orden', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF111111))),
                const SizedBox(height: 14),

                // LÍNEA DE TIEMPO DEL NUEVO FLUJO
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      // Paso 0: Verificación Pago
                      _buildTrackingStep(
                        context,
                        stepIndex: 0,
                        title: '1. Verificación del Pago',
                        subtitle: _currentStep == 0 
                            ? 'Esperando que la administración apruebe tu pago Nequi/Efectivo.'
                            : 'Pago verificado correctamente.',
                        icon: Icons.receipt_long_rounded,
                        isLast: false,
                      ),

                      // Paso 1: En Preparación
                      _buildTrackingStep(
                        context,
                        stepIndex: 1,
                        title: '2. En Preparación en Restaurante',
                        subtitle: _currentStep == 1
                            ? 'Pago aprobado. El restaurante está cocinando tus platos.'
                            : 'Comida preparada por el negocio.',
                        icon: Icons.soup_kitchen_rounded,
                        isLast: false,
                      ),

                      // Paso 2: Listo / Asignando Repartidor
                      _buildTrackingStep(
                        context,
                        stepIndex: 2,
                        title: '3. Listo / Asignando Repartidor',
                        subtitle: _currentStep == 2
                            ? 'El restaurante finalizó la preparación. Buscando domiciliario en radar...'
                            : 'Domiciliario encontrado.',
                        icon: Icons.radar_rounded,
                        isLast: false,
                      ),

                      // Paso 3: En camino al restaurante
                      _buildTrackingStep(
                        context,
                        stepIndex: 3,
                        title: '4. En camino al restaurante',
                        subtitle: _currentStep == 3
                            ? 'El repartidor aceptó tu pedido y va hacia el negocio a recogerlo.'
                            : 'Pedido retirado del restaurante.',
                        icon: Icons.storefront_rounded,
                        isLast: false,
                      ),

                      // Paso 4: En camino a tu domicilio
                      _buildTrackingStep(
                        context,
                        stepIndex: 4,
                        title: '5. En camino a tu domicilio',
                        subtitle: _currentStep == 4
                            ? 'El repartidor ya lleva tu comida en la moto hacia tu dirección.'
                            : 'En entrega final.',
                        icon: Icons.electric_moped_rounded,
                        isLast: false,
                      ),

                      // Paso 5: Pedido Entregado
                      _buildTrackingStep(
                        context,
                        stepIndex: 5,
                        title: '6. Pedido Entregado',
                        subtitle: '¡Disfruta tu comida! Califica a tu repartidor.',
                        icon: Icons.task_alt_rounded,
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // DATOS DEL REPARTIDOR (VISIBLE TRAS ASIGNACIÓN)
                if (_currentStep >= 3 && _courier != null) ...[
                  const Text('Tu Repartidor Asignado', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF111111))),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFFE60000).withOpacity(0.1),
                          child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFFE60000), size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_courier!['name'] ?? 'Repartidor Lorivery', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                  Text(
                                    ' ${_courier!['rating'] ?? '5.0'} • ${_courier!['vehicle_type'] ?? 'Motocicleta'}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => OrderChatModal(
                                    orderId: widget.orderId,
                                    otherPartyName: _courier!['name'] ?? 'Repartidor',
                                    otherPartyPhone: _courier!['phone_number'] ?? '3000000000',
                                    userRole: 'CLIENT',
                                  ),
                                );
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: const Color(0xFFE60000).withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFFE60000), size: 20),
                              ),
                              tooltip: 'Chat con Repartidor',
                            ),
                          ],
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
    final isActive = _currentStep == stepIndex;
    final isCompleted = _currentStep > stepIndex;
    final isPending = _currentStep < stepIndex;

    Color iconColor = Colors.grey.shade400;
    Color circleColor = Colors.grey.shade100;
    
    if (isCompleted) {
      iconColor = Colors.white;
      circleColor = const Color(0xFF34C759); // Verde iOS
    } else if (isActive) {
      iconColor = Colors.white;
      circleColor = const Color(0xFFE60000); // Rojo Lorivery
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  border: isPending ? Border.all(color: Colors.grey.shade300, width: 1.5) : null,
                ),
                child: Icon(
                  isCompleted ? Icons.check_rounded : icon,
                  color: isPending ? Colors.grey.shade400 : iconColor,
                  size: 18,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? const Color(0xFF34C759) : Colors.grey.shade200,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isActive || isCompleted ? FontWeight.w800 : FontWeight.w500,
                      fontSize: 15,
                      color: isPending ? Colors.grey.shade400 : const Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isActive ? const Color(0xFFE60000) : Colors.grey.shade600,
                      fontSize: 12,
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