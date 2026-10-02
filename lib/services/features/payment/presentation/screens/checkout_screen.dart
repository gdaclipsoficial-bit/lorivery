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
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Activa el GPS de tu celular'), backgroundColor: Colors.orange),
        );
      }
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Permiso de GPS necesario'), backgroundColor: Colors.orange),
          );
        }
        return null;
      }
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _confirmPayment(BuildContext context, WidgetRef ref) async {
    final imageFile = ref.read(receiptImageProvider);
    final bank = ref.read(selectedBankProvider);

    if (imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Sube la captura de tu transferencia'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.redAccent,
        )
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
      
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['restaurant_id'] = restaurant.id.toString()
        ..fields['total_amount'] = totalAmount.toString()
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
          SnackBar(content: Text('Error al enviar la orden: $e'), backgroundColor: Colors.red),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text('¡Pago Registrado!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Estamos verificando tu pago en el radar central. Te asignaremos un repartidor en breve.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Limpiamos el estado de la imagen
                  ref.read(receiptImageProvider.notifier).state = null;
                  
                  // Usamos push normal para conservar el inicio al fondo de la pila de navegación
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => OrderTrackingScreen(orderId: orderId)
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Rastrear mi Pedido', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(receiptImageProvider);
    final isVerifying = ref.watch(isVerifyingProvider);
    final selectedBank = ref.watch(selectedBankProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar Pedido', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: isVerifying
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: theme.colorScheme.primary, strokeWidth: 4),
                const SizedBox(height: 24),
                const Text('Enviando al Radar...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Dirección de Entrega (Opcional)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('📍 Tu ubicación GPS exacta se incluirá automáticamente en la orden', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (val) => ref.read(deliveryAddressProvider.notifier).state = val,
                  decoration: InputDecoration(
                    hintText: 'Barrio, casa o referencia (Opcional)',
                    prefixIcon: const Icon(Icons.location_on, color: Colors.redAccent),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Resumen: ${restaurant.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    children: [
                      Text('Total a Transferir ($itemCount items)', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('\$${totalAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      const SizedBox(height: 20),
                      const Divider(thickness: 1),
                      const SizedBox(height: 20),
                      _BankSelectorTile(
                        bankName: 'Nequi', account: '300 123 4567',
                        iconData: Icons.phone_android_rounded,
                        color: Colors.purple.shade600,
                        isSelected: selectedBank == 'Nequi',
                        onTap: () => ref.read(selectedBankProvider.notifier).state = 'Nequi',
                      ),
                      const SizedBox(height: 12),
                      _BankSelectorTile(
                        bankName: 'Bancolombia', account: '123-456789-00',
                        iconData: Icons.account_balance_rounded,
                        color: Colors.black87,
                        isSelected: selectedBank == 'Bancolombia',
                        onTap: () => ref.read(selectedBankProvider.notifier).state = 'Bancolombia',
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                const Text('Comprobante de Pago', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _pickImage(ref),
                  child: DottedBorder(
                    color: image != null ? Colors.green : theme.colorScheme.primary,
                    strokeWidth: 2,
                    dashPattern: const [8, 4],
                    borderType: BorderType.RRect,
                    radius: const Radius.circular(16),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: image != null ? Colors.green.withOpacity(0.05) : theme.colorScheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16)
                      ),
                      child: image != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(image, fit: BoxFit.cover))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_outlined, size: 48, color: theme.colorScheme.primary),
                              const SizedBox(height: 12),
                              Text('Toca para subir captura', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                ElevatedButton(
                  onPressed: () => _confirmPayment(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Confirmar y Enviar Pedido', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
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
  final bool isSelected;
  final VoidCallback onTap;

  const _BankSelectorTile({required this.bankName, required this.account, required this.iconData, required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(iconData, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bankName, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
                  Text(account, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle_rounded, color: color),
          ],
        ),
      ),
    );
  }
}