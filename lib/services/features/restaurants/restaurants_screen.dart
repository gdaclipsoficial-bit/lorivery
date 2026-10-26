import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbox/services/features/restaurants/providers/restaurant_provider.dart';
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/theme/app_theme.dart';
import 'restaurant_menu_screen.dart'; 

class RestaurantsScreen extends ConsumerStatefulWidget {
  const RestaurantsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends ConsumerState<RestaurantsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.clientScaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.clientTextPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restaurantes',
              style: TextStyle(
                color: AppColors.clientTextPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Lorica, Córdoba • Entrega rápida',
              style: TextStyle(color: AppColors.clientTextSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(restaurantsProvider),
            icon: const Icon(Icons.refresh_rounded, color: AppColors.loriveryRed),
            tooltip: 'Actualizar',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Barra de Búsqueda Flotante Estilo Rappi
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.clientSearchBg,
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(color: AppColors.clientBorder, width: 1),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Buscar restaurantes o platos...',
                  hintStyle: const TextStyle(color: AppColors.clientTextSecondary, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.clientTextSecondary, size: 22),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.clientTextSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Lista de Restaurantes
          Expanded(
            child: RefreshIndicator(
              color: AppColors.loriveryRed,
              onRefresh: () async {
                ref.invalidate(restaurantsProvider);
                await ref.read(restaurantsProvider.future);
              },
              child: ref.watch(restaurantsProvider).when(
                data: (restaurants) {
                  final filtered = restaurants.where((r) {
                    if (_searchQuery.isEmpty) return true;
                    final nameMatch = r.name.toLowerCase().contains(_searchQuery);
                    final descMatch = (r.description ?? '').toLowerCase().contains(_searchQuery);
                    return nameMatch || descMatch;
                  }).toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: AppColors.loriveryRedLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.search_off_rounded, size: 36, color: AppColors.loriveryRed),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No encontramos "$_searchQuery"'
                                    : 'No hay restaurantes disponibles.',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Intenta con otro término o categoría',
                                style: TextStyle(color: AppColors.clientTextSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final restaurant = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          boxShadow: AppShadows.clientCard,
                          border: Border.all(color: AppColors.clientBorder, width: 0.8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RestaurantMenuScreen(restaurant: restaurant),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Portada Superior con Badges Flotantes
                                Stack(
                                  children: [
                                    Container(
                                      height: 150,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
                                        color: const Color(0xFFF1F3F5),
                                        image: restaurant.logoUrl != null
                                            ? DecorationImage(
                                                image: NetworkImage('${ApiConfig.baseUrl}${restaurant.logoUrl}'),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: restaurant.logoUrl == null
                                          ? Center(
                                              child: Icon(
                                                Icons.restaurant_rounded,
                                                size: 50,
                                                color: Colors.grey.shade400,
                                              ),
                                            )
                                          : null,
                                    ),

                                    // Gradiente sutil
                                    Container(
                                      height: 150,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.black.withValues(alpha: 0.25),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Badge de Tarifa Fija Local
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.loriveryRed,
                                          borderRadius: BorderRadius.circular(AppRadius.full),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.2),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.two_wheeler_rounded, size: 13, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text(
                                              'TARIFA \$3.000',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Badge de Tiempo de Entrega
                                    Positioned(
                                      bottom: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(AppRadius.full),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.15),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.schedule_rounded, size: 14, color: AppColors.clientTextPrimary),
                                            SizedBox(width: 4),
                                            Text(
                                              '15-25 min',
                                              style: TextStyle(
                                                color: AppColors.clientTextPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Detalles del Restaurante
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              restaurant.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 17,
                                                color: AppColors.clientTextPrimary,
                                                letterSpacing: -0.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF8E1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFFFECB3), width: 1),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 15),
                                                const SizedBox(width: 3),
                                                const Text(
                                                  '4.8',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 12,
                                                    color: Color(0xFFB78103),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (restaurant.description != null && restaurant.description!.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          restaurant.description!,
                                          style: const TextStyle(
                                            color: AppColors.clientTextSecondary,
                                            fontSize: 13,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE8F5E9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 12),
                                                SizedBox(width: 4),
                                                Text(
                                                  'ABIERTO',
                                                  style: TextStyle(
                                                    color: Color(0xFF2E7D32),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            '• Lorica Centro',
                                            style: TextStyle(color: AppColors.clientTextSecondary, fontSize: 12),
                                          ),
                                        ],
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
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.loriveryRed),
                ),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.loriveryRed, size: 48),
                      const SizedBox(height: 12),
                      Text('Error: $error', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(restaurantsProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.loriveryRed,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
