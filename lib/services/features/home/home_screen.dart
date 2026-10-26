import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../map/map_quote_screen.dart';
import 'package:chatbox/services/features/restaurants/providers/restaurant_provider.dart';
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/services/features/auth/presentation/screens/auth_screen.dart';
import '../restaurants/restaurants_screen.dart'; 
import '../restaurants/restaurant_menu_screen.dart';
import '../client/presentation/screens/order_history_screen.dart';
import 'package:chatbox/services/features/support/support_modal.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  String _searchQuery = '';

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final restaurantsAsync = ref.watch(restaurantsProvider);

    // Paleta de Identidad Lorivery (Lorivery Red + Neutros Premium)
    const primaryRed = Color(0xFFE60000);
    const darkText = Color(0xFF111111);
    const greyMuted = Color(0xFF718096);
    const scaffoldBg = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: scaffoldBg,

      // --- MENÚ LATERAL (DRAWER CONSERVADO) ---
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                authState.name ?? 'Cliente Lorivery',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white),
              ),
              accountEmail: const Text(
                'Cliente • Lorica, Córdoba',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              currentAccountPicture: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    (authState.name ?? 'U').split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase(),
                    style: const TextStyle(
                      color: primaryRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              decoration: const BoxDecoration(
                color: primaryRed,
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
            _buildDrawerItem(
              icon: Icons.receipt_long_rounded, 
              title: 'Mis Pedidos', 
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientOrderHistoryScreen()));
              },
            ),
            _buildDrawerItem(
              icon: Icons.support_agent_rounded, 
              title: 'Soporte y Ayuda', 
              iconColor: primaryRed,
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const SupportHelpModal(),
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(),
            ),
            _buildDrawerItem(
              icon: Icons.logout_rounded, 
              title: 'Cerrar Sesión', 
              textColor: Colors.redAccent,
              iconColor: Colors.redAccent,
              onTap: () => AuthNotifier.performLogout(context, ref),
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: RefreshIndicator(
          color: primaryRed,
          onRefresh: () async {
            ref.invalidate(restaurantsProvider);
            await ref.read(restaurantsProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // ==========================================
                // 1. HEADER RAPPI-STYLE: UBICACIÓN Y BÚSQUEDA
                // ==========================================
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Builder(
                            builder: (context) => GestureDetector(
                              onTap: () => Scaffold.of(context).openDrawer(),
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: scaffoldBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black.withOpacity(0.04)),
                                ),
                                child: const Icon(Icons.menu_rounded, size: 20, color: darkText),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Selector de dirección de entrega
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 14, color: primaryRed),
                                    const SizedBox(width: 4),
                                    Text(
                                      'ENTREGAR EN',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.grey.shade500,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Row(
                                  children: [
                                    Text(
                                      'Lorica, Córdoba (Centro)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: darkText,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: darkText),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Botón de soporte rápido
                          IconButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const SupportHelpModal(),
                              );
                            },
                            icon: const Icon(Icons.support_agent_rounded, color: darkText, size: 24),
                            tooltip: 'Soporte',
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Barra de Búsqueda estilo Rappi (Rounded 16px con sombra tenue)
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: scaffoldBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black.withOpacity(0.04)),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                          decoration: InputDecoration(
                            hintText: '¿Qué se te antoja hoy en Lorica?',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w500),
                            prefixIcon: const Icon(Icons.search_rounded, color: primaryRed, size: 22),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                                    onPressed: () => setState(() => _searchQuery = ''),
                                  )
                                : Icon(Icons.tune_rounded, color: Colors.grey.shade400, size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ==========================================
                // 2. CATEGORÍAS RAPPI BUBBLES (PÍLDORAS)
                // ==========================================
                SizedBox(
                  height: 98,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildCategoryBubble(
                        title: 'Restaurantes',
                        icon: Icons.restaurant_rounded,
                        color: Colors.red.shade50,
                        iconColor: primaryRed,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantsScreen()));
                        },
                      ),
                      _buildCategoryBubble(
                        title: 'Hamburguesas',
                        icon: Icons.lunch_dining_rounded,
                        color: Colors.amber.shade50,
                        iconColor: Colors.amber.shade800,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantsScreen()));
                        },
                      ),
                      _buildCategoryBubble(
                        title: 'Comida Criolla',
                        icon: Icons.set_meal_rounded,
                        color: Colors.teal.shade50,
                        iconColor: Colors.teal.shade700,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantsScreen()));
                        },
                      ),
                      _buildCategoryBubble(
                        title: 'Pizzas',
                        icon: Icons.local_pizza_rounded,
                        color: Colors.deepOrange.shade50,
                        iconColor: Colors.deepOrange,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantsScreen()));
                        },
                      ),
                      _buildCategoryBubble(
                        title: 'Moto Envíos',
                        icon: Icons.motorcycle_rounded,
                        color: Colors.blue.shade50,
                        iconColor: Colors.blue.shade700,
                        badgeText: 'Pronto',
                        onTap: () => _navigateToMap(context),
                      ),
                      _buildCategoryBubble(
                        title: 'Mandados',
                        icon: Icons.inventory_2_rounded,
                        color: Colors.green.shade50,
                        iconColor: Colors.green.shade700,
                        badgeText: 'Pronto',
                        onTap: () => _navigateToMap(context),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ==========================================
                // 3. CARRUSEL DE BANNERS HERO (RAPPI PROMOS)
                // ==========================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 140,
                        child: PageView(
                          controller: _bannerController,
                          onPageChanged: (idx) => setState(() => _currentBannerIndex = idx),
                          children: [
                            _buildHeroBanner(
                              tag: 'LOCAL & RÁPIDO',
                              title: 'Sabores del Sinú\nhasta tu puerta',
                              subtitle: 'Tus platos favoritos en minutos',
                              icon: Icons.delivery_dining_rounded,
                              gradientColors: const [Color(0xFFE60000), Color(0xFFBA0000)],
                            ),
                            _buildHeroBanner(
                              tag: 'TARIFA FIJA',
                              title: 'Envíos en Lorica\ndesde \$3.000 COP',
                              subtitle: 'Sin tarifas ocultas en tu domicilio',
                              icon: Icons.savings_rounded,
                              gradientColors: const [Color(0xFF1E293B), Color(0xFF0F172A)],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Indicadores de puntos (Dots)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(2, (index) {
                          final isActive = _currentBannerIndex == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isActive ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive ? primaryRed : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ==========================================
                // 4. RESTAURANTES DESTACADOS (CARRUSEL HORIZONTAL RAPPI)
                // ==========================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Restaurantes Cerca de Ti',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: darkText,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Negocios populares en Lorica',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: greyMuted,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RestaurantsScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryRed.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Ver todos',
                            style: TextStyle(
                              color: primaryRed,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Consumer de Restaurantes con Tarjetas Rappi
                restaurantsAsync.when(
                  data: (restaurants) {
                    final filtered = _searchQuery.isEmpty
                        ? restaurants
                        : restaurants.where((r) => r.name.toLowerCase().contains(_searchQuery)).toList();

                    if (filtered.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isEmpty 
                                    ? 'No hay restaurantes registrados aún.'
                                    : 'No encontramos negocios con "$_searchQuery"',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SizedBox(
                      height: 235,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final restaurant = filtered[index];
                          return _buildRappiRestaurantCard(
                            restaurant: restaurant,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RestaurantMenuScreen(restaurant: restaurant),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                  loading: () => SizedBox(
                    height: 235,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      itemCount: 3,
                      itemBuilder: (_, __) => _buildSkeletonCard(),
                    ),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(child: Text('Error cargando restaurantes: $error')),
                  ),
                ),

                const SizedBox(height: 28),

                // ==========================================
                // 5. SECCIÓN DE SERVICIOS ADICIONALES (MOTO / ENVÍOS)
                // ==========================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: const Text(
                    'Otros Servicios',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: darkText,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildServiceBannerCard(
                          title: 'Lorivery Moto',
                          subtitle: 'Transporte rápido',
                          icon: Icons.two_wheeler_rounded,
                          accentColor: Colors.blue.shade700,
                          bgColor: Colors.blue.shade50,
                          onTap: () => _navigateToMap(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildServiceBannerCard(
                          title: 'Paquetería',
                          subtitle: 'Envío de paquetes',
                          icon: Icons.local_shipping_rounded,
                          accentColor: Colors.green.shade700,
                          bgColor: Colors.green.shade50,
                          onTap: () => _navigateToMap(context),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS DE COMPONENTES VISUALES RAPPI-STYLE ---

  Widget _buildCategoryBubble({
    required String title,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                if (badgeText != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111111),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner({
    required String tag,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildRappiRestaurantCard({
    required Restaurant restaurant,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.04)),
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
            // Portada / Imagen con Badges estilo Rappi
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Container(
                    height: 125,
                    width: double.infinity,
                    color: Colors.grey.shade100,
                    child: restaurant.logoUrl != null
                        ? Image.network(
                            '${ApiConfig.baseUrl}${restaurant.logoUrl}',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.restaurant_rounded, size: 36, color: Colors.grey),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.restaurant_rounded, size: 36, color: Colors.grey),
                          ),
                  ),
                ),
                // Badge de tiempo flotante en la esquina inferior derecha de la imagen
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF111111)),
                        SizedBox(width: 4),
                        Text(
                          '15-25 min',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Badge de Tarifa fija en la esquina superior izquierda
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE60000),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'TARIFA \$3.000',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Contenido / Metadatos del Restaurante
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF111111),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 3),
                      const Text(
                        '4.8',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF111111)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• ${restaurant.description ?? "Comida local"}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.pedal_bike_rounded, size: 13, color: Color(0xFF34C759)),
                      const SizedBox(width: 4),
                      Text(
                        'Envío rápido en Lorica',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 125, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: const BorderRadius.vertical(top: Radius.circular(18)))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 140, color: Colors.grey.shade200),
                const SizedBox(height: 8),
                Container(height: 10, width: 90, color: Colors.grey.shade100),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildServiceBannerCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.04)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF111111)),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color textColor = const Color(0xFF111111),
    Color iconColor = const Color(0xFF111111),
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
      onTap: onTap,
      dense: true,
    );
  }

  void _navigateToMap(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MapQuoteScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }
}
