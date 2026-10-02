import 'package:flutter/material.dart';
import '../payment/presentation/screens/payment_transfer_screen.dart';

class MapQuoteScreen extends StatefulWidget {
  const MapQuoteScreen({Key? key}) : super(key: key);

  @override
  State<MapQuoteScreen> createState() => _MapQuoteScreenState();
}

class _MapQuoteScreenState extends State<MapQuoteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showQuoteBottomSheet();
    });
  }

  void _showQuoteBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => const _QuoteBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo del mapa (Mock)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('https://miro.medium.com/max/1400/1*qYUvh-dpTfwivz_ZJp3-xg.png'), // Mapa ilustrativo
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black12, BlendMode.darken),
              ),
            ),
          ),
          
          // Botón de regreso flotante
          Positioned(
            top: 50,
            left: 20,
            child: SafeArea(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context); // Cierra bottom sheet
                  Navigator.pop(context); // Vuelve al home
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteBottomSheet extends StatelessWidget {
  const _QuoteBottomSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).bottomSheetTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle del Bottom Sheet
          Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 24),
          
          // Origen y Destino
          _buildLocationInput(Icons.my_location_rounded, Colors.blue, 'Origen', 'Parque Principal, Lorica'),
          const Padding(padding: EdgeInsets.only(left: 20.0), child: SizedBox(height: 24, child: VerticalDivider(color: Colors.grey, thickness: 1))),
          _buildLocationInput(Icons.location_on_rounded, Theme.of(context).colorScheme.primary, 'Destino', 'Barrio Centro'),
          
          const SizedBox(height: 30),
          
          // Tarjeta de Precio
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Moto Económica', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('~3 mins de distancia', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  ],
                ),
                Text('\$5.500', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Botón Solicitar
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PaymentTransferScreen()));
            },
            child: const Text('Solicitar y Pagar'),
          ),
          const SizedBox(height: 10), // Padding inferior
        ],
      ),
    );
  }

  Widget _buildLocationInput(IconData icon, Color iconColor, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
}

