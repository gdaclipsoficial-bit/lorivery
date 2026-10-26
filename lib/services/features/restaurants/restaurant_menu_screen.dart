import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/services/features/restaurants/providers/restaurant_provider.dart';
import 'package:chatbox/services/features/payment/presentation/screens/checkout_screen.dart';
import 'package:chatbox/theme/app_theme.dart';

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

  String _formatPrice(double amount) {
    return '\$${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')} COP';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.clientScaffoldBg,
      body: RefreshIndicator(
        color: AppColors.loriveryRed,
        onRefresh: () async {
          setState(() { _isLoading = true; _error = null; });
          await _loadProducts();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // SliverAppBar Hero con Imagen del Restaurante Estilo Rappi
            SliverAppBar(
              expandedHeight: 220.0,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.clientTextPrimary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.clientTextPrimary, size: 20),
                      onPressed: () {
                        setState(() { _isLoading = true; _error = null; });
                        _loadProducts();
                      },
                      tooltip: 'Actualizar menú',
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.restaurant.logoUrl != null)
                      Image.network(
                        '${ApiConfig.baseUrl}${widget.restaurant.logoUrl}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFFF1F3F5),
                          child: const Center(child: Icon(Icons.restaurant_rounded, size: 60, color: Colors.grey)),
                        ),
                      )
                    else
                      Container(
                        color: const Color(0xFFF1F3F5),
                        child: const Center(child: Icon(Icons.restaurant_rounded, size: 80, color: Colors.grey)),
                      ),
                    // Gradiente inferior para legibilidad
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tarjeta de Información del Restaurante
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.restaurant.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.clientTextPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFECB3), width: 1),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.star_rounded, color: Color(0xFFFFA000), size: 16),
                              SizedBox(width: 4),
                              Text(
                                '4.8',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFB78103)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (widget.restaurant.description != null && widget.restaurant.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.restaurant.description!,
                        style: const TextStyle(color: AppColors.clientTextSecondary, fontSize: 14, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Badges de entrega y tarifa local
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.loriveryRedLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.two_wheeler_rounded, size: 14, color: AppColors.loriveryRed),
                              SizedBox(width: 4),
                              Text(
                                'Envío \$3.000',
                                style: TextStyle(
                                  color: AppColors.loriveryRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F3F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 14, color: AppColors.clientTextPrimary),
                              SizedBox(width: 4),
                              Text(
                                '15-25 min',
                                style: TextStyle(
                                  color: AppColors.clientTextPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.clientBorder, height: 1),
                    const SizedBox(height: 16),
                    const Text(
                      'Platos y Menú',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.clientTextPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Lista de Platos desde la API
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.loriveryRed),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.loriveryRed),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() { _isLoading = true; _error = null; });
                            _loadProducts();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.loriveryRed,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_products.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu_rounded, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Este restaurante aún no tiene platos disponibles',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          boxShadow: AppShadows.clientCard,
                          border: Border.all(color: AppColors.clientBorder, width: 0.8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Imagen del plato
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 84,
                                  height: 84,
                                  color: const Color(0xFFF1F3F5),
                                  child: product.imageUrl != null
                                      ? Image.network(
                                          '${ApiConfig.baseUrl}${product.imageUrl}',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.fastfood_rounded,
                                            color: Colors.grey,
                                            size: 32,
                                          ),
                                        )
                                      : const Icon(Icons.fastfood_rounded, color: Colors.grey, size: 32),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Detalles del Producto
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppColors.clientTextPrimary,
                                      ),
                                    ),
                                    if (product.description != null && product.description!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        product.description!,
                                        style: const TextStyle(
                                          color: AppColors.clientTextSecondary,
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatPrice(product.price),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.loriveryRed,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Controles de Cantidad Estilo Rappi
                              Container(
                                decoration: BoxDecoration(
                                  color: qty > 0 ? AppColors.loriveryRedLight : const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: qty > 0 ? AppColors.loriveryRed.withValues(alpha: 0.3) : AppColors.clientBorder,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (qty > 0) ...[
                                      IconButton(
                                        onPressed: () => _removeFromCart(product),
                                        icon: const Icon(Icons.remove_rounded, size: 18),
                                        color: AppColors.loriveryRed,
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Text(
                                          '$qty',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.loriveryRed,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                    IconButton(
                                      onPressed: () => _addToCart(product),
                                      icon: const Icon(Icons.add_rounded, size: 18),
                                      color: Colors.white,
                                      style: IconButton.styleFrom(
                                        backgroundColor: AppColors.loriveryRed,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
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

      // Barra Flotante de Carrito Estilo Rappi
      bottomSheet: _cartItemCount > 0
          ? Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -6),
                  ),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
                border: Border.all(color: AppColors.clientBorder, width: 0.8),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.loriveryRed,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$_cartItemCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _cartItemCount == 1 ? 'producto' : 'productos',
                              style: const TextStyle(color: AppColors.clientTextSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatPrice(_cartTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: AppColors.clientTextPrimary,
                            letterSpacing: -0.3,
                          ),
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
                        backgroundColor: AppColors.loriveryRed,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        minimumSize: const Size(130, 48),
                        shadowColor: AppColors.loriveryRed.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Ver Pedido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
