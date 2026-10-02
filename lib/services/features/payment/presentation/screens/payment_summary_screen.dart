import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbox/database/db_helper.dart';

// --- PROVEEDORES DE ESTADO (Riverpod) ---
final receiptImageProvider = StateProvider<File?>((ref) => null);
final isLoadingProvider = StateProvider<bool>((ref) => false);
final selectedBankProvider = StateProvider<String>((ref) => 'Nequi');

class PaymentSummaryScreen extends ConsumerWidget {
  final String tripId = 'trip_1'; // Hardcoded for demo
  final double fareAmount = 5500.0;
  final String destination = "Barrio Centro, Lorica";

  const PaymentSummaryScreen({Key? key}) : super(key: key);

  Future<void> _pickImage(WidgetRef ref) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      ref.read(receiptImageProvider.notifier).state = File(pickedFile.path);
    }
  }

  Future<void> _submitPayment(BuildContext context, WidgetRef ref) async {
    final image = ref.read(receiptImageProvider);
    final bank = ref.read(selectedBankProvider);
    
    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, sube la captura del pago.')),
      );
      return;
    }

    ref.read(isLoadingProvider.notifier).state = true;

    try {
      // Guardar en la base de datos local
      await DBHelper().savePaymentReceipt(
        tripId, 
        image.path, 
        fareAmount, 
        bank
      );
      
      // Simular un poco de espera de red para el MVP visual
      await Future.delayed(const Duration(seconds: 1)); 
      
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Comprobante enviado ✅'),
            content: const Text('Estamos validando tu pago. En breve buscaremos tu conductor.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Cierra diálogo
                  // Aquí se resetearía el estado y navegaría a la pantalla de espera
                  ref.read(receiptImageProvider.notifier).state = null;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Estado de viaje: Buscando conductor...'))
                  );
                },
                child: const Text('Entendido'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      ref.read(isLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptImage = ref.watch(receiptImageProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final selectedBank = ref.watch(selectedBankProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen del Viaje'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text('Total a pagar', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      '\$${fareAmount.toStringAsFixed(0)} COP',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Destino:', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        Text(destination, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Transfiere a una de estas cuentas:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildBankOption(
              context, ref, selectedBank,
              'Nequi', '300 123 4567', 
              Colors.purple.shade50, Colors.purple
            ),
            const SizedBox(height: 12),
            _buildBankOption(
              context, ref, selectedBank,
              'Bancolombia Ahorros', '123-456789-00', 
              Colors.yellow.shade50, Colors.black87
            ),
            
            const SizedBox(height: 32),

            const Text(
              'Sube tu comprobante:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _pickImage(ref),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 2, style: BorderStyle.solid),
                ),
                child: receiptImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(receiptImage, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 60, color: Colors.blue.shade300),
                          const SizedBox(height: 12),
                          Text('Toca para seleccionar captura', style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : () => _submitPayment(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text('Enviar Comprobante', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBankOption(BuildContext context, WidgetRef ref, String currentSelection, String bankName, String account, Color bgColor, Color textColor) {
    final isSelected = currentSelection == bankName;
    return GestureDetector(
      onTap: () => ref.read(selectedBankProvider.notifier).state = bankName,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? textColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: textColor),
                const SizedBox(width: 12),
                Text(bankName, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
              ],
            ),
            Row(
              children: [
                Text(account, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Icon(Icons.copy, size: 20, color: textColor.withOpacity(0.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

