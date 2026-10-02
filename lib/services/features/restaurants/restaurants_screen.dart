import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbox/services/features/restaurants/providers/restaurant_provider.dart';
import 'package:chatbox/core/config/api_config.dart';
// Importamos la pantalla del menú real
import 'restaurant_menu_screen.dart'; 

class RestaurantsScreen extends ConsumerWidget {
  const RestaurantsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'Restaurantes',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(restaurantsProvider);
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(restaurantsProvider);
          await ref.read(restaurantsProvider.future);
        },
        child: ref.watch(restaurantsProvider).when(
          data: (restaurants) {
            if (restaurants.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('No hay restaurantes disponibles.')),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(20),
              itemCount: restaurants.length,
            itemBuilder: (context, index) {
              final restaurant = restaurants[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      // NAVEGACIÓN REAL AL MENÚ DEL RESTAURANTE
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
                        // Imagen grande del restaurante
                        Container(
                          height: 160,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            color: Colors.grey.shade200,
                            image: restaurant.logoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage('${ApiConfig.baseUrl}${restaurant.logoUrl}'),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: restaurant.logoUrl == null
                              ? const Center(child: Icon(Icons.restaurant, size: 60, color: Colors.grey))
                              : null,
                        ),
                        // Detalles del restaurante
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                restaurant.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 6),
                              if (restaurant.description != null) ...[
                                Text(
                                  restaurant.description!,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                              ],
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 16),
                                        const SizedBox(width: 4),
                                        const Text('4.8', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, color: Colors.grey.shade400, size: 16),
                                      const SizedBox(width: 4),
                                      Text('15-25 min', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                    ],
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    ),
  );
  }
}