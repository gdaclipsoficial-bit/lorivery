import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:chatbox/services/websocket_service.dart';
import 'package:chatbox/services/location_service.dart';
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/services/features/auth/presentation/screens/auth_screen.dart';
import 'package:chatbox/services/features/courier/presentation/screens/active_trip_screen.dart';
import 'package:chatbox/services/features/courier/presentation/screens/courier_profile_screen.dart' as profile;
import 'package:chatbox/services/features/courier/presentation/screens/courier_history_screen.dart';
import 'package:chatbox/services/features/support/support_modal.dart';
import 'package:chatbox/core/widgets/app_notification_banner.dart';
import 'package:flutter/services.dart';

class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapController = MapController(); 
  
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStream;
  Timer? _ordersPollTimer;
  bool _isSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _initLocationTracking();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wsService = ref.read(webSocketServiceProvider);
      if (wsService.pendingOrder != null) {
        final orderData = wsService.pendingOrder!;
        wsService.clearPendingOrder();
        _showIncomingOrderBottomSheet(orderData);
      } else {
        _checkPendingAvailableOrders();
      }
    });

    // Consultar periódicamente pedidos disponibles si el repartidor se conecta tarde o no hay asignado
    _ordersPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkPendingAvailableOrders();
    });
  }

  Future<void> _checkPendingAvailableOrders() async {
    if (_isSheetOpen) return;
    try {
      final token = ref.read(authProvider).token;
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/orders/available'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final List<dynamic> orders = data['orders'] ?? [];
        if (orders.isNotEmpty && !_isSheetOpen) {
          final firstOrder = orders.first;
          _showIncomingOrderBottomSheet(Map<String, dynamic>.from(firstOrder));
        }
      }
    } catch (_) {}
  }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position initialPos = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentLocation = LatLng(initialPos.latitude, initialPos.longitude);
      });
      _centerMap();
      _updateBackendLocation(initialPos.latitude, initialPos.longitude);
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5)
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _updateBackendLocation(position.latitude, position.longitude);
      }
    });
  }

  Future<void> _updateBackendLocation(double lat, double lng) async {
    try {
      final token = ref.read(authProvider).token;
      if (token == null) return;
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/couriers/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'latitude': lat, 'longitude': lng}),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _ordersPollTimer?.cancel();
    _positionStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _centerMap() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15.5);
    } else {
      _mapController.move(const LatLng(9.2389, -75.8139), 15.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wsService = ref.watch(webSocketServiceProvider);
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);

    ref.listen<WebSocketService>(webSocketServiceProvider, (previous, next) {
      if (next.pendingOrder != null) {
        final orderData = next.pendingOrder!;
        next.clearPendingOrder();
        _showIncomingOrderBottomSheet(orderData);
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(authState.name ?? 'Repartidor'),
              accountEmail: Text(authState.role == 'COURIER' ? 'Modo Motorizado' : ''),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.motorcycle, size: 30, color: Colors.orange),
              ),
              decoration: BoxDecoration(color: theme.colorScheme.primary),
            ),
            ListTile(
              leading: const Icon(Icons.radar),
              title: const Text('Radar de Pedidos'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Ganancias y Perfil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const profile.CourierProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Historial de Entregas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CourierOrderHistoryScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_rounded, color: Colors.blueAccent),
              title: const Text('Soporte y Ayuda'),
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
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
              onTap: () => AuthNotifier.performLogout(context, ref),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? const LatLng(9.2389, -75.8139),
              initialZoom: 14.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.chatbox',
              ),
              if (wsService.isConnected && _currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 60,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.motorcycle_rounded, color: Colors.green, size: 30),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: const Icon(Icons.menu, color: Colors.black87),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: wsService.isConnected ? Colors.green : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          wsService.isConnected ? Icons.wifi : Icons.wifi_off,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          wsService.isConnected ? 'Buscando pedidos' : 'Desconectado',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0, bottom: 16.0),
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'refresh_radar_fab',
                        backgroundColor: Colors.white,
                        onPressed: () async {
                          await _initLocationTracking();
                          if (wsService.isConnected) {
                            ref.read(webSocketServiceProvider).reconnect();
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('⚡ Radar y GPS re-sincronizados'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: const Icon(Icons.refresh, color: Colors.black87),
                      ),
                      const SizedBox(height: 10),
                      FloatingActionButton(
                        heroTag: 'center_location_fab',
                        backgroundColor: Colors.white,
                        onPressed: _centerMap,
                        child: const Icon(Icons.my_location, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildQuickStat('Ganancias Hoy', '\$0', Icons.attach_money),
                          Container(width: 1, height: 40, color: Colors.grey.shade300),
                          _buildQuickStat('Tasa Aceptación', '100%', Icons.check_circle_outline),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (wsService.isConnected) {
                              ref.read(webSocketServiceProvider).disconnect();
                            } else {
                              // 1. Verificación de Opciones de Desarrollador
                              final isDevMode = await _checkDevMode();
                              if (isDevMode) {
                                _showSecurityDialog(
                                  title: '⚠️ Opciones de Desarrollador Detectadas',
                                  message: 'Por la seguridad de la plataforma y prevención de GPS falso, debes desactivar las Opciones de Desarrollador (Developer Options) en los Ajustes de tu celular para poder conectarte.',
                                );
                                return;
                              }

                              // 2. Verificación de Aprobación por Admin
                              final isApproved = await _checkApprovalStatus();
                              if (!isApproved) {
                                _showSecurityDialog(
                                  title: '⏳ Cuenta en Revisión',
                                  message: 'Tus fotos de cédula y selfie están en proceso de verificación por la administración. Podrás conectarte una vez que tu cuenta sea aprobada.',
                                );
                                return;
                              }

                              ref.read(webSocketServiceProvider).connect();
                              _centerMap();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: wsService.isConnected ? Colors.redAccent : Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            wsService.isConnected ? 'DESCONECTARSE' : 'CONECTARSE',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkDevMode() async {
    try {
      const platform = MethodChannel('com.example.chatbox/security');
      final bool isDev = await platform.invokeMethod('isDevModeEnabled');
      return isDev;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkApprovalStatus() async {
    try {
      final token = ref.read(authProvider).token;
      if (token == null) return false;
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/couriers/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['is_approved'] == true;
      }
    } catch (e) {
      debugPrint('Error checking approval status: $e');
    }
    return true; // Fallback permitiendo conexión si hay error de red temporal
  }

  void _showSecurityDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }

  void _showIncomingOrderBottomSheet(Map<String, dynamic> orderData) {
    if (!mounted || _isSheetOpen) return;
    _isSheetOpen = true;

    // Alerta auditiva/háptica y Notificación flotante de nuevo pedido
    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.click);

    AppNotificationBanner.show(
      context,
      title: '🚨 ¡NUEVO PEDIDO EN LORICA!',
      message: '${orderData['restaurant'] ?? 'Restaurante'} -> ${orderData['destination'] ?? 'Cliente'} (${orderData['earnings'] ?? '\$3.000 COP'})',
      icon: Icons.motorcycle_rounded,
      accentColor: Colors.orangeAccent,
    );

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _IncomingOrderSheet(orderData: orderData),
    ).then((_) {
      _isSheetOpen = false;
    });
  }
}

class _IncomingOrderSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> orderData;
  const _IncomingOrderSheet({Key? key, required this.orderData}) : super(key: key);

  @override
  ConsumerState<_IncomingOrderSheet> createState() => _IncomingOrderSheetState();
}

class _IncomingOrderSheetState extends ConsumerState<_IncomingOrderSheet> with TickerProviderStateMixin {
  late AnimationController _progressController;
  bool _isAccepted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..reverse(from: 1.0);

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !_isAccepted && !_isLoading) {
        Navigator.pop(context); 
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _acceptOrder() async {
    setState(() => _isLoading = true);
    _progressController.stop();
    
    final orderId = widget.orderData['order_id'];
    if (orderId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final token = ref.read(authProvider).token;
      final userId = ref.read(authProvider).userId;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/accept'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() => _isAccepted = true);
        
        final wsService = ref.read(webSocketServiceProvider);
        final locService = LocationService(wsService);
        locService.requestPermissionsAndStart(orderId, userId!);

        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        
        Navigator.pop(context); 
        
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (_) => ActiveTripScreen(orderData: widget.orderData),
          )
        );
      } else if (response.statusCode == 409) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Alguien fue más rápido! El pedido ya fue asignado.'),
            backgroundColor: Colors.redAccent,
          )
        );
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _progressController.reverse(); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e'), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurantDisplay = widget.orderData['restaurant_name'] ?? widget.orderData['restaurant'] ?? 'Restaurante Local';
    final destinationDisplay = widget.orderData['delivery_address'] ?? widget.orderData['destination'] ?? 'Barrio Centro, Lorica';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('¡NUEVO PEDIDO!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 20),
          
          _buildRouteInfo(Icons.restaurant, restaurantDisplay, Colors.orange),
          const Padding(
            padding: EdgeInsets.only(left: 14),
            child: SizedBox(height: 20, child: VerticalDivider(color: Colors.grey, thickness: 1)),
          ),
          _buildRouteInfo(Icons.location_on_rounded, destinationDisplay, Colors.blue),
          
          const SizedBox(height: 30),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric('Ganancia', widget.orderData['earnings'] ?? '\$3.000', Colors.green),
              _buildMetric('Distancia', widget.orderData['distance'] ?? '2.5 km', Colors.black87),
            ],
          ),
          
          const SizedBox(height: 30),
          
          _isAccepted
            ? const CircularProgressIndicator(color: Colors.green)
            : Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        return CircularProgressIndicator(
                          value: _progressController.value,
                          color: Colors.orange,
                          backgroundColor: Colors.grey.shade200,
                          strokeWidth: 8,
                        );
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: _acceptOrder,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                      ),
                      child: const Center(
                        child: Text('ACEPTAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                    ),
                  ),
                ],
              ),
          
          if (!_isAccepted) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Rechazar', style: TextStyle(color: Colors.grey, fontSize: 16)),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildRouteInfo(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 16),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
      ],
    );
  }

  Widget _buildMetric(String title, String value, Color valueColor) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    );
  }
}