import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../map/map_quote_screen.dart';
import 'package:chatbox/services/websocket_service.dart';
import 'package:chatbox/features/restaurants/providers/restaurant_provider.dart';
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/features/auth/presentation/screens/auth_screen.dart';
import '../restaurants/restaurants_screen.dart'; 
import '../restaurants/restaurant_menu_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFD), // Fondo limpio estilo Apple
      
      // --- MENÚ LATERAL ESTILO APPLE SHEET ---
      drawer: Drawer(
        backgroundColor: const Color(0xFFFBFBFD),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                authState.name ?? 'Daniel Luna',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black87),
              ),
              accountEmail: const Text(
                'Cliente • Lorivery',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              currentAccountPicture: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.primary, width: 2),
                ),
                child: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    'DL',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            _buildDrawerItem(
              icon: Icons.home_rounded, 
              title: 'Inicio', 
              onTap: () => Navigator.pop(context),
            ),
            _buildDrawerItem(
              icon: Icons.storefront_rounded, 
              title: 'Restaurantes', 
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantsScreen()));
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(),
            ),
            _buildDrawerItem(
              icon: Icons.logout_rounded, 
              title: 'Cerrar Sesión', 
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () {
                ref.invalidate(authProvider);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ESTILO APPLE (LARGE TITLE) ---
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Builder(
                          builder: (context) => GestureDetector(
                            onTap: () => Scaffold.of(context).openDrawer(),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: const Icon(Icons.menu_rounded, size: 22, color: Colors.black87),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LORICA',
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const Text(
                              'Hola, Daniel 👋',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Avatar minimalista
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: Text(
                          'DL',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // --- BANNER PROMOCIONAL LIMPIO ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'SERVICIO LOCAL',
                              style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.5),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Envíos rápidos\nen todo Lorica',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tus pedidos en la puerta de tu casa',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.electric_moped_rounded, size: 30, color: colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // --- SECCIÓN: SERVICIOS ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'SERVICIOS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _IOSServiceCard(
                        title: 'Comida',
                        subtitle: 'Restaurantes',
                        icon: Icons.fastfood_rounded,
                        color: Colors.orange.shade50,
                        iconColor: Colors.orange.shade700,
                        height: 224, // Ajustado para simetría perfecta
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RestaurantsScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _IOSServiceCard(
                            title: 'Moto',
                            subtitle: 'Viajes',
                            icon: Icons.motorcycle_rounded,
                            color: Colors.blue.shade50,
                            iconColor: Colors.blue.shade700,
                            height: 106, // Altura corregida para evitar overflow
                            isComingSoon: true,
                            onTap: () => _navigateToMap(context),
                          ),
                          const SizedBox(height: 12),
                          _IOSServiceCard(
                            title: 'Paquetes',
                            subtitle: 'Envíos',
                            icon: Icons.local_shipping_rounded,
                            color: Colors.green.shade50,
                            iconColor: Colors.green.shade700,
                            height: 106, // Altura corregida para evitar overflow
                            isComingSoon: true,
                            onTap: () => _navigateToMap(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // --- SECCIÓN: POPULARES ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'POPULARES CERCA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 1.0,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RestaurantsScreen()),
                        );
                      },
                      child: Text(
                        'Ver todos',
                        style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              ref.watch(restaurantsProvider).when(
                data: (restaurants) {
                  if (restaurants.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('No hay restaurantes disponibles.')),
                    );
                  }
                  return SizedBox(
                    height: 195,
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: restaurants.length,
                      itemBuilder: (context, index) {
                        final restaurant = restaurants[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RestaurantMenuScreen(restaurant: restaurant),
                              ),
                            );
                          },
                          child: Container(
                            width: 240,
                            margin: const EdgeInsets.only(right: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                      color: Colors.grey.shade100,
                                      image: restaurant.logoUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage('${ApiConfig.baseUrl}${restaurant.logoUrl}'),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: restaurant.logoUrl == null
                                        ? const Center(child: Icon(Icons.restaurant, size: 40, color: Colors.grey))
                                        : null,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        restaurant.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                          const SizedBox(width: 4),
                                          const Text('4.8', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                          const SizedBox(width: 6),
                                          Text('• 15-25 min', style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({required IconData icon, required String title, required VoidCallback onTap, Color textColor = Colors.black87, Color iconColor = Colors.black87}) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: textColor, fontSize: 15)),
      onTap: onTap,
      dense: true,
    );
  }

  void _navigateToMap(BuildContext context) {
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const MapQuoteScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    ));
  }
}

class _IOSServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final double height;
  final VoidCallback onTap;
  final bool isComingSoon;

  const _IOSServiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.height,
    required this.onTap,
    this.isComingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: isComingSoon ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Opacity(
          opacity: isComingSoon ? 0.7 : 1.0,
          child: Container(
            height: height,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              // Estilo Apple: sin bordes grises fuertes, solo sombra ultra suave y limpia
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    if (isComingSoon)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Pronto',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}