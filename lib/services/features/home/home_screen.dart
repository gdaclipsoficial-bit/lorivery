import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String _selectedCategory = 'Todos';
  String _deliveryAddress = 'Detectando ubicación...';
  bool _isLocating = false;

  final List<Map<String, dynamic>> _foodCategories = const [
    {'title': 'Todos', 'icon': Icons.tune_rounded},
    {'title': 'Hamburguesas', 'icon': Icons.lunch_dining_rounded},
    {'title': 'Pizzas', 'icon': Icons.local_pizza_rounded},
    {'title': 'Comida Rápida', 'icon': Icons.fastfood_rounded},
    {'title': 'Criollo / Sinú', 'icon': Icons.set_meal_rounded},
    {'title': 'Bebidas & Postres', 'icon': Icons.local_cafe_rounded},
  ];

  List<Restaurant> _filterRestaurants(List<Restaurant> restaurants) {
    return restaurants.where((r) {
      final nameLower = r.name.toLowerCase();
      final descLower = (r.description ?? '').toLowerCase();

      // Filtro de búsqueda por texto
      if (_searchQuery.isNotEmpty) {
        if (!nameLower.contains(_searchQuery) && !descLower.contains(_searchQuery)) {
          return false;
        }
      }

      // Filtro por categoría seleccionada
      if (_selectedCategory == 'Todos') return true;

      if (_selectedCategory == 'Hamburguesas') {
        return nameLower.contains('hamburg') || nameLower.contains('burger') ||
               descLower.contains('hamburg') || descLower.contains('burger');
      }
      if (_selectedCategory == 'Pizzas') {
        return nameLower.contains('pizza') || descLower.contains('pizza') || descLower.contains('italiana');
      }
      if (_selectedCategory == 'Comida Rápida') {
        return nameLower.contains('rápida') || nameLower.contains('fast') || nameLower.contains('perro') ||
               nameLower.contains('salchipapa') || descLower.contains('rápida') || descLower.contains('salchipapa');
      }
      if (_selectedCategory == 'Criollo / Sinú') {
        return nameLower.contains('sinu') || nameLower.contains('crioll') || nameLower.contains('asado') ||
               descLower.contains('sinu') || descLower.contains('crioll') || descLower.contains('pescado') ||
               descLower.contains('asado') || descLower.contains('sancocho');
      }
      if (_selectedCategory == 'Bebidas & Postres') {
        return nameLower.contains('cafe') || nameLower.contains('café') || nameLower.contains('bebida') ||
               nameLower.contains('helad') || descLower.contains('bebida') || descLower.contains('postre') ||
               descLower.contains('jugo') || descLower.contains('cerveza');
      }

      return nameLower.contains(_selectedCategory.toLowerCase()) || descLower.contains(_selectedCategory.toLowerCase());
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadOrDetectLocation();
  }

  Future<void> _loadOrDetectLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('user_delivery_address');
      if (saved != null && saved.isNotEmpty) {
        if (mounted) setState(() => _deliveryAddress = saved);
        return;
      }
      await _detectRealLocation(silent: true);
    } catch (e) {
      if (mounted) setState(() => _deliveryAddress = 'Lorica, Córdoba');
    }
  }

  Future<void> _detectRealLocation({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor activa el GPS de tu dispositivo')),
          );
        }
        if (mounted && _deliveryAddress.contains('Detectando')) {
          setState(() => _deliveryAddress = 'Lorica, Córdoba (GPS desactivado)');
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted && _deliveryAddress.contains('Detectando')) {
            setState(() => _deliveryAddress = 'Lorica, Córdoba');
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted && _deliveryAddress.contains('Detectando')) {
          setState(() => _deliveryAddress = 'Lorica, Córdoba');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );

      // Consulta de geocodificación inversa a OpenStreetMap Nominatim
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'LoriveryApp/1.0 (lorivery.app@gmail.com)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final road = addr['road'] ?? addr['pedestrian'] ?? addr['street'];
          final suburb = addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'] ?? addr['residential'] ?? addr['subdivision'];
          final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['municipality'] ?? 'Lorica';

          String formatted = '';
          if (road != null && suburb != null) {
            formatted = '$road, $suburb';
          } else if (suburb != null) {
            formatted = '$suburb, $city';
          } else if (road != null) {
            formatted = '$road, $city';
          } else {
            formatted = '$city, Córdoba';
          }

          if (mounted) {
            setState(() => _deliveryAddress = formatted);
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_delivery_address', formatted);
          await prefs.setDouble('user_delivery_lat', position.latitude);
          await prefs.setDouble('user_delivery_lng', position.longitude);
          return;
        }
      }

      if (mounted) {
        setState(() => _deliveryAddress = 'Lorica, Córdoba (GPS)');
      }
    } catch (e) {
      debugPrint('Error detectando ubicación: $e');
      if (mounted && _deliveryAddress.contains('Detectando')) {
        setState(() => _deliveryAddress = 'Lorica, Córdoba');
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _setCustomAddress(String address) async {
    setState(() => _deliveryAddress = address);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_delivery_address', address);
  }

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
                          // Selector de dirección de entrega estilo Rappi
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _showAddressPickerModal(context),
                              behavior: HitTestBehavior.opaque,
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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _deliveryAddress,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: darkText,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: darkText),
                                    ],
                                  ),
                                ],
                              ),
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

                const SizedBox(height: 14),

                // ==========================================
                // 2. CARRUSEL DE BANNERS HERO (EDITORIAL RAPPI)
                // ==========================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 135,
                        child: PageView(
                          controller: _bannerController,
                          onPageChanged: (idx) => setState(() => _currentBannerIndex = idx),
                          children: [
                            _buildHeroBanner(
                              tag: 'LOCAL Y RÁPIDO',
                              title: 'Sabores del Sinú\nhasta tu puerta',
                              subtitle: 'Pide en tus restaurantes favoritos de Lorica',
                              icon: Icons.delivery_dining_rounded,
                              gradientColors: const [Color(0xFFE60000), Color(0xFF990000)],
                            ),
                            _buildHeroBanner(
                              tag: 'TARIFA PLANA OFICIAL',
                              title: 'Domicilios en Lorica\n\$3.000 COP siempre',
                              subtitle: 'Sin cobros sorpresa ni tarifas ocultas',
                              icon: Icons.verified_rounded,
                              gradientColors: const [Color(0xFF0F172A), Color(0xFF1E293B)],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Indicadores de puntos elegantes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(2, (index) {
                          final isActive = _currentBannerIndex == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isActive ? 20 : 6,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isActive ? primaryRed : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ==========================================
                // 3. SELECTOR DE CATEGORÍAS (CÁPSULAS INTERACTIVAS)
                // ==========================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Explora por Categoría',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: darkText,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (_selectedCategory != 'Todos')
                        GestureDetector(
                          onTap: () => setState(() => _selectedCategory = 'Todos'),
                          child: const Text(
                            'Limpiar filtro',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: primaryRed,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  height: 42,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _foodCategories.length,
                    itemBuilder: (context, index) {
                      final cat = _foodCategories[index];
                      final isSelected = _selectedCategory == cat['title'];
                      return _buildCategoryChip(
                        title: cat['title'],
                        icon: cat['icon'],
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat['title'];
                          });
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 22),

                // ==========================================
                // 4. RESTAURANTES DESTACADOS (CARRUSEL HORIZONTAL)
                // ==========================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCategory == 'Todos' ? 'Restaurantes en Lorica' : '$_selectedCategory en Lorica',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: darkText,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Negocios verificados • Entrega inmediata',
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: primaryRed.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Ver lista',
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

                const SizedBox(height: 12),

                // Consumer de Restaurantes filtrados en vivo
                restaurantsAsync.when(
                  data: (restaurants) {
                    final filtered = _filterRestaurants(restaurants);

                    if (filtered.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No encontramos negocios con "$_searchQuery"'
                                    : 'Aún no hay restaurantes en "$_selectedCategory"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: darkText,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Explora todas las opciones disponibles en Santa Cruz de Lorica.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _selectedCategory = 'Todos';
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF111111),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Ver todos los restaurantes',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Carrusel horizontal
                        SizedBox(
                          height: 230,
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        ),

                        const SizedBox(height: 26),

                        // Feed Vertical Completo
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Text(
                            'Explora el Menú Completo',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: darkText,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final restaurant = filtered[index];
                              return _buildVerticalRestaurantCard(
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
                        ),
                      ],
                    );
                  },
                  loading: () => SizedBox(
                    height: 230,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 3,
                      itemBuilder: (_, __) => _buildSkeletonCard(),
                    ),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(child: Text('Error cargando restaurantes: $error')),
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

  Widget _buildCategoryChip({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF111111) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF111111) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF4B5563),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF1F2937),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
                letterSpacing: -0.1,
              ),
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

  Widget _buildVerticalRestaurantCard({
    required Restaurant restaurant,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.04)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Portada panorámica con badges flotantes estilo Rappi
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  Container(
                    height: 145,
                    width: double.infinity,
                    color: const Color(0xFFF1F5F9),
                    child: restaurant.logoUrl != null
                        ? Image.network(
                            '${ApiConfig.baseUrl}${restaurant.logoUrl}',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildRestaurantPlaceholder(),
                          )
                        : _buildRestaurantPlaceholder(),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.35),
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Badge tarifa superior izquierda
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE60000),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'DOMICILIO \$3.000 COP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Badge tiempo inferior derecha
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_filled_rounded, size: 13, color: Color(0xFF111111)),
                          SizedBox(width: 4),
                          Text(
                            '20-30 min',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111111),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Detalles y nombre del restaurante
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111111),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          restaurant.description ?? 'Platos tradicionales y deliciosos en Lorica',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
                                  SizedBox(width: 2),
                                  Text(
                                    '4.9',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('•', style: TextStyle(color: Colors.grey)),
                            const SizedBox(width: 8),
                            const Text(
                              'Entrega en Lorica',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE60000).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFFE60000),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantPlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
                ],
              ),
              child: const Icon(Icons.storefront_rounded, size: 28, color: Color(0xFFE60000)),
            ),
            const SizedBox(height: 6),
            Text(
              'Restaurante Oficial',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddressPickerModal(BuildContext context) {
    final textCtrl = TextEditingController(text: _deliveryAddress.contains('Lorica, Córdoba') ? '' : _deliveryAddress);
    final loricaNeighborhoods = [
      'Centro',
      'San Gabriel',
      'Arenal',
      'Remolino',
      'San Pedro',
      'Santa Teresita',
      'San Vicente',
      'Kennedy',
      'La Esmeralda',
      'Nuevo Oriente',
      'Paraíso',
      'Gaita',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Dirección de Entrega',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Indica dónde deseas recibir tus pedidos en Lorica',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),

                    // Botón para usar GPS actual
                    InkWell(
                      onTap: _isLocating
                          ? null
                          : () async {
                              setModalState(() => _isLocating = true);
                              await _detectRealLocation();
                              setModalState(() => _isLocating = false);
                              if (context.mounted) Navigator.pop(ctx);
                            },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE60000).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE60000).withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            _isLocating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFE60000),
                                    ),
                                  )
                                : const Icon(Icons.my_location_rounded, color: Color(0xFFE60000), size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isLocating ? 'Detectando señal GPS...' : 'Usar mi ubicación GPS actual',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Color(0xFFE60000),
                                    ),
                                  ),
                                  Text(
                                    'Precisión satelital automática para Lorica',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Campo de texto para dirección personalizada
                    TextField(
                      controller: textCtrl,
                      decoration: InputDecoration(
                        labelText: 'Barrio, calle o punto de referencia',
                        hintText: 'Ej. Calle 10 # 25-14, Barrio Arenal',
                        prefixIcon: const Icon(Icons.edit_location_alt_outlined, color: Colors.grey),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check_circle_rounded, color: Color(0xFFE60000)),
                          onPressed: () {
                            if (textCtrl.text.trim().isNotEmpty) {
                              _setCustomAddress(textCtrl.text.trim());
                              Navigator.pop(ctx);
                            }
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          _setCustomAddress(val.trim());
                          Navigator.pop(ctx);
                        }
                      },
                    ),

                    const SizedBox(height: 18),
                    const Text(
                      'Barrios Populares de Lorica',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111111)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: loricaNeighborhoods.map((barrio) {
                        final isSelected = _deliveryAddress.contains(barrio);
                        return ChoiceChip(
                          label: Text(barrio),
                          selected: isSelected,
                          onSelected: (_) {
                            _setCustomAddress('Barrio $barrio, Lorica');
                            Navigator.pop(ctx);
                          },
                          selectedColor: const Color(0xFFE60000).withOpacity(0.15),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFFE60000) : Colors.black87,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12,
                          ),
                          backgroundColor: const Color(0xFFF1F3F5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
}
