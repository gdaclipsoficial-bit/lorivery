import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:geolocator/geolocator.dart';
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/services/features/restaurants/providers/restaurant_provider.dart';
import 'package:chatbox/services/features/client/presentation/screens/order_tracking_screen.dart';
import 'package:chatbox/services/features/auth/presentation/screens/auth_screen.dart';
import 'package:chatbox/theme/app_theme.dart';

// Usamos autoDispose para que el carrito se limpie si el usuario vuelve atrás
final receiptImageProvider = StateProvider.autoDispose<File?>((ref) => null);
final isVerifyingProvider = StateProvider.autoDispose<bool>((ref) => false);
final selectedBankProvider = StateProvider.autoDispose<String>((ref) => 'Nequi');
final deliveryAddressProvider = StateProvider.autoDispose<String>((ref) => '');

class CheckoutScreen extends ConsumerWidget {
  final Restaurant restaurant;
  final double totalAmount;
  final int itemCount;

  const CheckoutScreen({
    Key? key,
    required this.restaurant,
    required this.totalAmount,
    required this.itemCount,
  }) : super(key: key);

  Future<void> _pickImage(WidgetRef ref) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      ref.read(receiptImageProvider.notifier).state = File(pickedFile.path);
    }
  }

  Future<Position?> _getLocation(BuildContext context) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 GPS desactivado: Usando ubicación central de Lorica'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      // Fallback seguro para Linux Desktop / Web / Emuladores sin plugin de GPS
      debugPrint('Geolocator no disponible en esta plataforma: $e');
      return null;
    }
  }

  Future<void> _confirmPayment(BuildContext context, WidgetRef ref) async {
    final imageFile = ref.read(receiptImageProvider);
    final bank = ref.read(selectedBankProvider);

    if (imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Adjunta el comprobante de transferencia para despachar tu orden'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.loriveryRed,
        ),
      );
      return;
    }

    ref.read(isVerifyingProvider.notifier).state = true;
    
    try {
      // Capturar GPS real del cliente
      final position = await _getLocation(context);
      double lat = 9.2389;
      double lng = -75.8139;
      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
      }

      final rawAddress = ref.read(deliveryAddressProvider).trim();
      final address = rawAddress.isNotEmpty
          ? rawAddress
          : 'Ubicación GPS (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';

      final token = ref.read(authProvider).token;
      final uri = Uri.parse('${ApiConfig.baseUrl}/orders/');
      
      const double deliveryFee = 3000.0; // Domicilio urbano Lorica ($3.000 COP)
      final double grandTotal = totalAmount + deliveryFee;

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['restaurant_id'] = restaurant.id.toString()
        ..fields['total_amount'] = grandTotal.toString()
        ..fields['delivery_fee'] = deliveryFee.toString()
        ..fields['items_count'] = itemCount.toString()
        ..fields['bank'] = bank
        ..fields['delivery_address'] = address
        ..fields['delivery_lat'] = lat.toString()
        ..fields['delivery_lng'] = lng.toString()
        ..fields['status'] = 'pending_payment';

      final mimeType = imageFile.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      request.files.add(await http.MultipartFile.fromPath(
        'payment_proof',
        imageFile.path,
        contentType: MediaType('image', mimeType),
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (context.mounted) {
          final responseData = jsonDecode(response.body);
          final orderId = responseData['order_id'] ?? 'ORD-001';
          _showSuccessDialog(context, ref, orderId.toString());
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar la orden: $e'),
            backgroundColor: AppColors.loriveryRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      ref.read(isVerifyingProvider.notifier).state = false;
    }
  }

  void _showSuccessDialog(BuildContext context, WidgetRef ref, String orderId) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 48),
            ),
            const SizedBox(height: 18),
            const Text(
              '¡Pedido Enviado al Radar!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.clientTextPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu comprobante está en verificación. Un repartidor en Lorica aceptará tu pedido en segundos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(receiptImageProvider.notifier).state = null;
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => OrderTrackingScreen(orderId: orderId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.loriveryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                  elevation: 3,
                  shadowColor: AppColors.loriveryRed.withValues(alpha: 0.4),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.radar_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Rastrear mi Pedido en Vivo',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double amount) {
    return '\$${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')} COP';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(receiptImageProvider);
    final isVerifying = ref.watch(isVerifyingProvider);
    final selectedBank = ref.watch(selectedBankProvider);

    return Scaffold(
      backgroundColor: AppColors.clientScaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Confirmar Pedido',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: AppColors.clientTextPrimary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.clientTextPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isVerifying
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.loriveryRed, strokeWidth: 3.5),
                  SizedBox(height: 20),
                  Text(
                    'Enviando orden al radar...',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.clientTextPrimary),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Conectando con repartidores cercanos',
                    style: TextStyle(fontSize: 13, color: AppColors.clientTextSecondary),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tarjeta 1: Dirección de Entrega
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      boxShadow: AppShadows.clientCard,
                      border: Border.all(color: AppColors.clientBorder, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.location_on_rounded, color: AppColors.loriveryRed, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Punto de Entrega',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.clientTextPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '📍 Tu GPS se asociará a la orden para que el motorizado llegue exacto.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.clientSearchBg,
                            borderRadius: BorderRadius.circular(AppRadius.input),
                            border: Border.all(color: AppColors.clientBorder, width: 1),
                          ),
                          child: TextField(
                            onChanged: (val) => ref.read(deliveryAddressProvider.notifier).state = val,
                            decoration: const InputDecoration(
                              hintText: 'Barrio, casa o referencia (Opcional)',
                              hintStyle: TextStyle(color: AppColors.clientTextSecondary, fontSize: 13),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Tarjeta 2: Resumen de Cuenta
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      boxShadow: AppShadows.clientCard,
                      border: Border.all(color: AppColors.clientBorder, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.receipt_long_rounded, color: AppColors.clientTextPrimary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                restaurant.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.clientTextPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subtotal ($itemCount ${itemCount == 1 ? 'item' : 'items'}):',
                              style: const TextStyle(color: AppColors.clientTextSecondary, fontSize: 14),
                            ),
                            Text(
                              _formatPrice(totalAmount),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFF2E7D32)),
                                SizedBox(width: 6),
                                Text(
                                  'Domicilio Lorica (Tarifa Plana):',
                                  style: TextStyle(color: AppColors.clientTextSecondary, fontSize: 14),
                                ),
                              ],
                            ),
                            Text(
                              '\$3.000 COP',
                              style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2E7D32), fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: AppColors.clientBorder, height: 1),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL A PAGAR',
                              style: TextStyle(
                                color: AppColors.clientTextPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              _formatPrice(totalAmount + 3000),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.loriveryRed,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Tarjeta 3: Métodos de Transferencia Bancaria
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      boxShadow: AppShadows.clientCard,
                      border: Border.all(color: AppColors.clientBorder, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pagar por Transferencia',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.clientTextPrimary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Transfiere el total exacto a cualquiera de nuestras cuentas oficiales:',
                          style: TextStyle(color: AppColors.clientTextSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        _BankSelectorTile(
                          bankName: 'Nequi',
                          account: '300 123 4567',
                          iconData: Icons.phone_android_rounded,
                          color: const Color(0xFF200020),
                          accentColor: const Color(0xFFFF247E),
                          isSelected: selectedBank == 'Nequi',
                          onTap: () => ref.read(selectedBankProvider.notifier).state = 'Nequi',
                        ),
                        const SizedBox(height: 10),
                        _BankSelectorTile(
                          bankName: 'Bancolombia A la Mano',
                          account: '123-456789-00',
                          iconData: Icons.account_balance_rounded,
                          color: const Color(0xFF1E2836),
                          accentColor: const Color(0xFFFDDA24),
                          isSelected: selectedBank == 'Bancolombia',
                          onTap: () => ref.read(selectedBankProvider.notifier).state = 'Bancolombia',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Tarjeta 4: Subida de Comprobante
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      boxShadow: AppShadows.clientCard,
                      border: Border.all(color: AppColors.clientBorder, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Comprobante de Pago',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.clientTextPrimary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Toma captura a la transferencia exitosa y súbela aquí:',
                          style: TextStyle(color: AppColors.clientTextSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => _pickImage(ref),
                          child: DottedBorder(
                            color: image != null ? const Color(0xFF00C853) : AppColors.loriveryRed,
                            strokeWidth: 1.8,
                            dashPattern: const [8, 4],
                            borderType: BorderType.RRect,
                            radius: const Radius.circular(AppRadius.card),
                            child: Container(
                              height: 140,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: image != null
                                    ? const Color(0xFF00C853).withValues(alpha: 0.05)
                                    : AppColors.loriveryRed.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(AppRadius.card),
                              ),
                              child: image != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(AppRadius.card),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.file(image, fit: BoxFit.cover),
                                          Positioned(
                                            bottom: 10,
                                            right: 10,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.black87,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 14),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Listo para verificar',
                                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.cloud_upload_outlined, size: 40, color: AppColors.loriveryRed),
                                        SizedBox(height: 8),
                                        Text(
                                          'Toca para seleccionar captura',
                                          style: TextStyle(
                                            color: AppColors.loriveryRed,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Botón CTA Principal Masivo
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _confirmPayment(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.loriveryRed,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppColors.loriveryRed.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'CONFIRMAR Y ENVIAR PEDIDO',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

class _BankSelectorTile extends StatelessWidget {
  final String bankName;
  final String account;
  final IconData iconData;
  final Color color;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _BankSelectorTile({
    required this.bankName,
    required this.account,
    required this.iconData,
    required this.color,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.08) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.loriveryRed : AppColors.clientBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconData, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bankName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isSelected ? AppColors.loriveryRed : AppColors.clientTextPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    account,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.clientTextSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.loriveryRed : Colors.grey.shade400,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
