import 'package:flutter/material.dart';
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/features/restaurants/providers/restaurant_provider.dart'; // Importamos el modelo
import 'package:chatbox/features/payment/presentation/screens/checkout_screen.dart'; // Importamos tu pantalla de pago

class RestaurantMenuScreen extends StatefulWidget {
  final Restaurant restaurant; // Cambiado a Restaurant para mayor seguridad

  const RestaurantMenuScreen({Key? key, required this.restaurant}) : super(key: key);

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  // Datos de prueba para el menú (luego los conectaremos a FastAPI)
  final List<Map<String, dynamic>> _mockProducts = [
    {'name': 'Hamburguesa Sencilla', 'description': 'Carne de res 150g, queso, lechuga y tomate.', 'price': 15000},
    {'name': 'Hamburguesa Especial', 'description': 'Doble carne, tocineta, queso cheddar y salsa de la casa.', 'price': 22000},
    {'name': 'Papas Fritas', 'description': 'Porción de papas a la francesa crujientes.', 'price': 6000},
    {'name': 'Gaseosa 400ml', 'description': 'Coca-Cola, Postobón o Sprite.', 'price': 4000},
  ];

  int _cartItemCount = 0;
  double _cartTotal = 0.0;

  void _addToCart(double price) {
    setState(() {
      _cartItemCount++;
      _cartTotal += price;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Encabezado con imagen estilo Rappi/UberEats
          SliverAppBar(
            expandedHeight: 220.0,
            pinned: true,
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.black),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.restaurant.name,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              background: widget.restaurant.logoUrl != null
                  ? Image.network(
                      '${ApiConfig.baseUrl}${widget.restaurant.logoUrl}',
                      fit: BoxFit.cover,
                      // Protección por si la URL de la imagen está rota
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(child: Icon(Icons.broken_image, size: 60, color: Colors.grey)),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: const Center(child: Icon(Icons.restaurant, size: 80, color: Colors.grey)),
                    ),
            ),
          ),
          
          // Información extra del restaurante
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.restaurant.description != null) ...[
                    Text(
                      widget.restaurant.description!,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Divider(),
                  const SizedBox(height: 10),
                  Text('Menú Disponible', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // Lista de Platos
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = _mockProducts[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(
                                  product['description'],
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '\$${product['price']}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Botón para agregar al carrito
                          ElevatedButton(
                            onPressed: () => _addToCart(product['price'].toDouble()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor.withOpacity(0.1),
                              foregroundColor: primaryColor,
                              elevation: 0,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                            ),
                            child: const Icon(Icons.add),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: _mockProducts.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // Espacio al final
        ],
      ),
      
      // Barra inferior del Carrito (Solo aparece si hay productos)
      bottomSheet: _cartItemCount > 0
          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$_cartItemCount items', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                        Text('\$$_cartTotal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // NAVEGACIÓN A CHECKOUT
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CheckoutScreen(
                              restaurant: widget.restaurant,
                              totalAmount: _cartTotal,
                              itemCount: _cartItemCount,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Ver Carrito', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}