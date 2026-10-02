import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/services/features/restaurants/providers/restaurant_provider.dart';
import 'package:chatbox/services/features/payment/presentation/screens/checkout_screen.dart';

class RestaurantMenuScreen extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantMenuScreen({super.key, required this.restaurant});

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class Product {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final bool isAvailable;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    required this.isAvailable,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Sin nombre',
      description: json['description'],
      price: (json['price'] ?? 0).toDouble(),
      imageUrl: json['image_url'],
      isAvailable: json['is_available'] ?? true,
    );
  }
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  // Carrito: mapa de productId -> {product, quantity}
  final Map<String, Map<String, dynamic>> _cart = {};

  int get _cartItemCount => _cart.values.fold(0, (sum, item) => sum + (item['qty'] as int));
  double get _cartTotal => _cart.values.fold(0.0, (sum, item) => sum + (item['product'] as Product).price * (item['qty'] as int));

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/restaurants/${widget.restaurant.id}/products'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _products = data
              .map((j) => Product.fromJson(j))
              .where((p) => p.isAvailable)
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() { _error = 'Error del servidor: ${response.statusCode}'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'No se pudo conectar: $e'; _isLoading = false; });
    }
  }

  void _addToCart(Product product) {
    setState(() {
      if (_cart.containsKey(product.id)) {
        _cart[product.id]!['qty'] = (_cart[product.id]!['qty'] as int) + 1;
      } else {
        _cart[product.id] = {'product': product, 'qty': 1};
      }
    });
  }

  void _removeFromCart(Product product) {
    setState(() {
      if (_cart.containsKey(product.id)) {
        final qty = (_cart[product.id]!['qty'] as int) - 1;
        if (qty <= 0) {
          _cart.remove(product.id);
        } else {
          _cart[product.id]!['qty'] = qty;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() { _isLoading = true; _error = null; });
          await _loadProducts();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // Encabezado con imagen del restaurante
            SliverAppBar(
              expandedHeight: 220.0,
              pinned: true,
              backgroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.black),
              actions: [
                IconButton(
                  onPressed: () {
                    setState(() { _isLoading = true; _error = null; });
                    _loadProducts();
                  },
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  tooltip: 'Actualizar menú',
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  widget.restaurant.name,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
                background: widget.restaurant.logoUrl != null
                    ? Image.network(
                        '${ApiConfig.baseUrl}${widget.restaurant.logoUrl}',
                        fit: BoxFit.cover,
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

          // Descripción del restaurante
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

          // Lista de Platos desde la API
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () { setState(() { _isLoading = true; _error = null; }); _loadProducts(); },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          else if (_products.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Este restaurante aún no tiene platos disponibles',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = _products[index];
                  final qty = (_cart[product.id]?['qty'] as int?) ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            // Imagen del plato
                            if (product.imageUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  '${ApiConfig.baseUrl}${product.imageUrl}',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 80, height: 80,
                                    color: Colors.grey.shade100,
                                    child: const Icon(Icons.fastfood, color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 80, height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.fastfood, color: Colors.grey, size: 36),
                              ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  if (product.description != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      product.description!,
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    '\$${product.price.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')} COP',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                            // Controles cantidad
                            Column(
                              children: [
                                if (qty > 0) ...[
                                  IconButton(
                                    onPressed: () => _removeFromCart(product),
                                    icon: const Icon(Icons.remove_circle_outline),
                                    color: Colors.red,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  Text('$qty', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                                ],
                                IconButton(
                                  onPressed: () => _addToCart(product),
                                  icon: const Icon(Icons.add_circle),
                                  color: primaryColor,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _products.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    ),

      // Barra del Carrito
      bottomSheet: _cartItemCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5))],
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
                        Text('$_cartItemCount ${_cartItemCount == 1 ? 'item' : 'items'}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                        Text(
                          '\$${_cartTotal.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')} COP',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
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
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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