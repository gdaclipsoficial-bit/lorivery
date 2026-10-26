import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/services/features/auth/presentation/screens/auth_screen.dart';
import 'package:chatbox/services/features/chat/order_chat_dialog.dart';
import 'package:chatbox/services/websocket_service.dart';

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

  @override
  void initState() {
    super.initState();
    // Conectar al WebSocket del pedido para chat en tiempo real
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderId = widget.orderData['order_id']?.toString() ?? widget.orderData['id']?.toString() ?? '';
      if (orderId.isNotEmpty) {
        ref.read(webSocketServiceProvider).connectToOrder(orderId);
      }
    });
  }

  void _logout(BuildContext context) {
    AuthNotifier.performLogout(context, ref);
  }

  Future<String?> _sendOrderStatusUpdate(String nextStatus, {String? pickupCode, String? deliveryCode}) async {
    final orderId = widget.orderData['order_id']?.toString() ?? widget.orderData['id']?.toString();
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
        return null; // Éxito sin errores
      } else {
        try {
          final errorResponse = jsonDecode(response.body);
          return errorResponse['detail'] ?? 'Error al actualizar estado.';
        } catch (_) {
          return 'Error en el servidor (${response.statusCode})';
        }
      }
    } catch (e) {
      return 'Error de conexión: $e';
    }
  }

  Future<void> _updateOrderStatus(String nextStatus) async {
    setState(() => _isLoading = true);
    final error = await _sendOrderStatusUpdate(nextStatus);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      setState(() => _currentStatus = nextStatus);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFE60000),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPinDialog(String nextStatus, {bool isDelivery = false}) {
    final controllers = List.generate(4, (_) => TextEditingController());
    final focusNodes = List.generate(4, (_) => FocusNode());
    String? errorMessage;
    bool isSubmitting = false;

    final accentColor = isDelivery ? const Color(0xFF00E676) : const Color(0xFFFF9100);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submitPin() async {
              final pin = controllers.map((c) => c.text.trim()).join();
              if (pin.length < 4) {
                setDialogState(() {
                  errorMessage = 'Debes ingresar los 4 dígitos del PIN.';
                });
                return;
              }

              setDialogState(() {
                isSubmitting = true;
                errorMessage = null;
              });

              final error = await _sendOrderStatusUpdate(
                nextStatus,
                pickupCode: isDelivery ? null : pin,
                deliveryCode: isDelivery ? pin : null,
              );

              if (!mounted) return;

              if (error == null) {
                // Éxito: cerrar el diálogo y actualizar el estado
                Navigator.of(dialogContext).pop();
                if (nextStatus == 'DELIVERED') {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🎉 ¡Entrega completada y verificada con éxito!'),
                      backgroundColor: Color(0xFF00C853),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  setState(() => _currentStatus = nextStatus);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Recogida verificada con el restaurante.'),
                      backgroundColor: Color(0xFFFF9100),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                HapticFeedback.vibrate();
                setDialogState(() {
                  isSubmitting = false;
                  errorMessage = error;
                  // Limpiar los campos para nuevo intento
                  for (var c in controllers) {
                    c.clear();
                  }
                });
                focusNodes[0].requestFocus();
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF151A21),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFF263238), width: 1.2),
              ),
              titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDelivery ? Icons.verified_user_rounded : Icons.storefront_rounded,
                      color: accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isDelivery ? 'PIN del Cliente' : 'PIN de Recogida',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    isDelivery
                        ? 'Solicita al cliente el PIN de 4 dígitos que aparece en su pantalla de seguimiento.'
                        : 'Solicita al personal del restaurante el PIN de 4 dígitos impreso en la orden.',
                    style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(4, (index) {
                      final hasFocus = focusNodes[index].hasFocus;
                      return Container(
                        width: 52,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2632),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: errorMessage != null
                                ? const Color(0xFFFF5252)
                                : (hasFocus ? accentColor : const Color(0xFF37474F)),
                            width: hasFocus ? 2.0 : 1.2,
                          ),
                          boxShadow: hasFocus
                              ? [BoxShadow(color: accentColor.withValues(alpha: 0.3), blurRadius: 8)]
                              : null,
                        ),
                        child: Center(
                          child: TextField(
                            controller: controllers[index],
                            focusNode: focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                            ),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (value) {
                              setDialogState(() {
                                errorMessage = null;
                              });
                              if (value.isNotEmpty) {
                                if (index < 3) {
                                   focusNodes[index + 1].requestFocus();
                                } else {
                                  focusNodes[index].unfocus();
                                  submitPin();
                                }
                              } else {
                                if (index > 0) {
                                  focusNodes[index - 1].requestFocus();
                                }
                              }
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFF5252), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252), size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFFF5252),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : submitPin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Verificar PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extracción robusta de los datos de la orden
    final restaurantName = widget.orderData['restaurant_name'] ?? widget.orderData['restaurant'] ?? 'Restaurante Local';
    final restaurantAddress = widget.orderData['restaurant_address'] ?? 'Calle Principal #10-20, Lorica';
    final deliveryAddress = widget.orderData['delivery_address'] ?? widget.orderData['destination'] ?? 'Barrio Centro, Lorica';
    final earnings = widget.orderData['earnings'] ?? '\$3.000 COP';
    final orderId = widget.orderData['order_id']?.toString() ?? widget.orderData['id']?.toString() ?? '';

    return Scaffold(
      body: Stack(
        children: [
          // Mapa a pantalla completa
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
              MarkerLayer(
                markers: [
                  // Marcador Restaurante
                  Marker(
                    point: const LatLng(9.2389, -75.8139),
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9100),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 26),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Header de Navegación Flotante
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141920),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF263238), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                  ),

                  // Pill de estado de la ruta
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141920),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getButtonColor(), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getButtonColor(),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getStatusPillText(),
                          style: TextStyle(
                            color: _getButtonColor(),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _logout(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141920),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF263238), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.logout_rounded, color: Color(0xFFFF5252)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Cockpit Operativo de Despacho Inferior (Soy Rappi Trip Dispatch Panel)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
              decoration: BoxDecoration(
                color: const Color(0xFF12161D),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                border: Border.all(color: const Color(0xFF222B36), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Manija
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D3748),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header de Ganancia y Estado del Pedido
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.two_wheeler_rounded, color: Color(0xFF00E676), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            orderId.isNotEmpty ? 'ORDEN #$orderId' : 'ORDEN EN CURSO',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF8B9BB4),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00E676), width: 1),
                        ),
                        child: Text(
                          earnings,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00E676),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Paradas tácticas (Restaurante y Cliente)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A212A),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF2A3644), width: 1),
                    ),
                    child: Column(
                      children: [
                        // Parada 1: Restaurante
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9100).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFFF9100), width: 1.2),
                              ),
                              child: const Icon(Icons.storefront_rounded, color: Color(0xFFFF9100), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PASO 1: RECOGER EN TIENDA',
                                    style: TextStyle(
                                      color: Color(0xFFFF9100),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    restaurantName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    restaurantAddress,
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        Padding(
                          padding: const EdgeInsets.only(left: 17, top: 4, bottom: 4),
                          child: Row(
                            children: [
                              Container(width: 2, height: 18, color: const Color(0xFF37474F)),
                            ],
                          ),
                        ),

                        // Parada 2: Cliente
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF00E676), width: 1.2),
                              ),
                              child: const Icon(Icons.location_on_rounded, color: Color(0xFF00E676), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PASO 2: ENTREGA AL CLIENTE',
                                    style: TextStyle(
                                      color: Color(0xFF00E676),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    deliveryAddress,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Acciones rápidas (Chat con Cliente + Llamada)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => OrderChatModal(
                                  orderId: orderId,
                                  otherPartyName: 'Cliente',
                                  otherPartyPhone: '3000000000',
                                  userRole: 'COURIER',
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF37474F), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF00B0FF)),
                            label: const Text(
                              'Chat Cliente',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF151A21),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: Color(0xFF263238)),
                                ),
                                title: const Text('Llamar al Cliente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                content: const Text('Teléfono de contacto: 3000000000', style: TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cerrar', style: TextStyle(color: Color(0xFF00E676))),
                                  ),
                                ],
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF00E676), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            foregroundColor: const Color(0xFF00E676),
                          ),
                          icon: const Icon(Icons.phone_in_talk_rounded, size: 16, color: Color(0xFF00E676)),
                          label: const Text(
                            'Llamar',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Botón Operativo Masivo de Despacho
                  SizedBox(
                    width: double.infinity,
                    height: 58,
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
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: _getButtonColor().withValues(alpha: 0.5),
                      ),
                      child: _isLoading 
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_getButtonIcon(), size: 22),
                              const SizedBox(width: 8),
                              Text(
                                _getButtonText(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
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

  String _getStatusPillText() {
    switch (_currentStatus) {
      case 'READY': return 'RUMBO AL RESTAURANTE';
      case 'AT_RESTAURANT': return 'EN TIENDA';
      case 'PICKED_UP': return 'EN CAMINO AL CLIENTE';
      default: return 'DESPACHO ACTIVO';
    }
  }

  IconData _getButtonIcon() {
    switch (_currentStatus) {
      case 'READY': return Icons.storefront_rounded;
      case 'AT_RESTAURANT': return Icons.pin_rounded;
      case 'PICKED_UP': return Icons.check_circle_rounded;
      default: return Icons.check_rounded;
    }
  }

  String _getButtonText() {
    switch (_currentStatus) {
      case 'READY': return 'LLEGUÉ AL RESTAURANTE';
      case 'AT_RESTAURANT': return 'INGRESAR PIN DE RECOGIDA';
      case 'PICKED_UP': return 'CONFIRMAR ENTREGA (PIN)';
      default: return 'PROCESANDO...';
    }
  }

  Color _getButtonColor() {
    switch (_currentStatus) {
      case 'READY': return const Color(0xFF00B0FF);
      case 'AT_RESTAURANT': return const Color(0xFFFF9100);
      case 'PICKED_UP': return const Color(0xFF00C853);
      default: return Colors.grey;
    }
  }
}
