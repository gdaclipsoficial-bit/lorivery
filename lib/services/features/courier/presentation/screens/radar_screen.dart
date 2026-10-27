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
import 'package:audioplayers/audioplayers.dart';

class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapController = MapController(); 
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStream;
  Timer? _ordersPollTimer;
  bool _isSheetOpen = false;
  final Set<String> _locallyRejectedOrderIds = {};

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
        final filteredOrders = orders.where((o) {
          final id = (o['order_id'] ?? o['id'])?.toString();
          return id != null && !_locallyRejectedOrderIds.contains(id);
        }).toList();

        if (filteredOrders.isNotEmpty && !_isSheetOpen) {
          final firstOrder = filteredOrders.first;
          _showIncomingOrderBottomSheet(Map<String, dynamic>.from(firstOrder));
        }
      }
    } catch (_) {}
  }

  Future<void> _initLocationTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _currentLocation = const LatLng(9.2389, -75.8139));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _currentLocation = const LatLng(9.2389, -75.8139));
          return;
        }
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
    } catch (e) {
      // Fallback seguro para Linux Desktop / emulador sin GPS nativo
      debugPrint('Geolocator no soportado en esta plataforma: $e');
      if (mounted) {
        setState(() {
          _currentLocation = const LatLng(9.2389, -75.8139);
        });
        _centerMap();
      }
    }
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
    _audioPlayer.dispose();
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
        backgroundColor: const Color(0xFF141920),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE60000), Color(0xFF990000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.two_wheeler_rounded, size: 34, color: Color(0xFFE60000)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    authState.name ?? 'Repartidor Lorivery',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: wsService.isConnected ? const Color(0xFF00E676) : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        authState.role == 'COURIER' ? 'Motorizado Activo • Lorica' : 'Repartidor',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildDrawerTile(
              icon: Icons.radar_rounded,
              title: 'Radar de Pedidos',
              isSelected: true,
              onTap: () => Navigator.pop(context),
            ),
            _buildDrawerTile(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Ganancias y Billetera',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const profile.CourierProfileScreen()),
                );
              },
            ),
            _buildDrawerTile(
              icon: Icons.history_toggle_off_rounded,
              title: 'Historial de Entregas',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CourierOrderHistoryScreen()),
                );
              },
            ),
            _buildDrawerTile(
              icon: Icons.support_agent_rounded,
              title: 'Soporte Repartidor 24/7',
              accentColor: const Color(0xFF00B0FF),
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
              child: Divider(color: Color(0xFF263238), height: 1),
            ),
            _buildDrawerTile(
              icon: Icons.logout_rounded,
              title: 'Cerrar Sesión',
              accentColor: const Color(0xFFFF5252),
              onTap: () => AuthNotifier.performLogout(context, ref),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Mapa a pantalla completa
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
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 70,
                      height: 70,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (wsService.isConnected ? const Color(0xFF00E676) : Colors.grey)
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF181D24),
                              border: Border.all(
                                color: wsService.isConnected ? const Color(0xFF00E676) : Colors.grey,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.two_wheeler_rounded,
                              color: wsService.isConnected ? const Color(0xFF00E676) : Colors.grey.shade400,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Header Operativo Flotante (Soy Rappi High-Contrast HUD)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Botón Menú táctico
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141920),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF263238), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                    ),
                  ),

                  // Pill de Estado Operativo (En Línea / Desconectado)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141920),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: wsService.isConnected ? const Color(0xFF00E676) : const Color(0xFF37474F),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (wsService.isConnected ? const Color(0xFF00E676) : Colors.black)
                              .withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: wsService.isConnected ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                            shape: BoxShape.circle,
                            boxShadow: wsService.isConnected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00E676).withValues(alpha: 0.6),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          wsService.isConnected ? 'EN LÍNEA • RADAR ACTIVO' : 'MODO DESCONECTADO',
                          style: TextStyle(
                            color: wsService.isConnected ? const Color(0xFF00E676) : Colors.white70,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Panel Operativo Inferior Soy Rappi Style
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botones flotantes de acción rápida sobre el mapa
                Padding(
                  padding: const EdgeInsets.only(right: 16.0, bottom: 12.0),
                  child: Column(
                    children: [
                      _buildFloatingActionBtn(
                        icon: Icons.sync_rounded,
                        tooltip: 'Re-sincronizar GPS y Radar',
                        onTap: () async {
                          await _initLocationTracking();
                          if (wsService.isConnected) {
                            ref.read(webSocketServiceProvider).reconnect();
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('⚡ Radar y GPS re-sincronizados con éxito'),
                                backgroundColor: Color(0xFF1E2630),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildFloatingActionBtn(
                        icon: Icons.my_location_rounded,
                        tooltip: 'Centrar en mi ubicación',
                        onTap: _centerMap,
                      ),
                    ],
                  ),
                ),

                // Card Inferior Táctica de Despacho (Dark High Contrast)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12161D),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    border: Border.all(color: const Color(0xFF222B36), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Manija indicadora
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D3748),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Métricas Rápidas Operativas
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              title: 'GANANCIAS HOY',
                              value: '\$0 COP',
                              icon: Icons.attach_money_rounded,
                              accentColor: const Color(0xFF00E676),
                            ),
                          ),
                          Container(width: 1, height: 44, color: const Color(0xFF263238)),
                          Expanded(
                            child: _buildMetricTile(
                              title: 'ACEPTACIÓN',
                              value: '100%',
                              icon: Icons.verified_rounded,
                              accentColor: const Color(0xFF00B0FF),
                            ),
                          ),
                          Container(width: 1, height: 44, color: const Color(0xFF263238)),
                          Expanded(
                            child: _buildMetricTile(
                              title: 'ZONA',
                              value: 'Lorica Centro',
                              icon: Icons.location_city_rounded,
                              accentColor: const Color(0xFFFFB300),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Botón Operativo Masivo CONECTARSE / DESCONECTARSE
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
                            backgroundColor: wsService.isConnected
                                ? const Color(0xFFE60000)
                                : const Color(0xFF00C853),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 4,
                            shadowColor: (wsService.isConnected
                                    ? const Color(0xFFE60000)
                                    : const Color(0xFF00C853))
                                .withValues(alpha: 0.4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                wsService.isConnected
                                    ? Icons.power_settings_new_rounded
                                    : Icons.play_arrow_rounded,
                                size: 26,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                wsService.isConnected ? 'DESCONECTARSE' : 'CONECTARSE AL RADAR',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
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

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    Color? accentColor,
  }) {
    final color = accentColor ?? (isSelected ? const Color(0xFF00E676) : Colors.white70);
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFF1E2632),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }

  Widget _buildFloatingActionBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF141920),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF263238), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: accentColor),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF8B9BB4),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
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
        backgroundColor: const Color(0xFF1A212C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE60000),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showIncomingOrderBottomSheet(Map<String, dynamic> orderData) {
    if (!mounted || _isSheetOpen) return;
    
    final orderId = (orderData['order_id'] ?? orderData['id'])?.toString();
    if (orderId != null && _locallyRejectedOrderIds.contains(orderId)) {
      return;
    }

    _isSheetOpen = true;

    // Alerta auditiva/háptica y Notificación flotante de nuevo pedido
    HapticFeedback.vibrate();
    _audioPlayer.play(AssetSource('sounds/new_order.wav'));

    AppNotificationBanner.show(
      context,
      title: '🚨 ¡NUEVO PEDIDO EN LORICA!',
      message: '${orderData['restaurant'] ?? 'Restaurante'} -> ${orderData['destination'] ?? 'Cliente'} (${orderData['earnings'] ?? '\$3.000 COP'})',
      icon: Icons.motorcycle_rounded,
      accentColor: const Color(0xFF00E676),
    );

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _IncomingOrderSheet(
        orderData: orderData,
        onRejected: (rejectedId) {
          _locallyRejectedOrderIds.add(rejectedId);
        },
      ),
    ).then((_) {
      _isSheetOpen = false;
    });
  }
}

class _IncomingOrderSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> orderData;
  final ValueChanged<String>? onRejected;

  const _IncomingOrderSheet({
    Key? key, 
    required this.orderData,
    this.onRejected,
  }) : super(key: key);

  @override
  ConsumerState<_IncomingOrderSheet> createState() => _IncomingOrderSheetState();
}

class _IncomingOrderSheetState extends ConsumerState<_IncomingOrderSheet> with TickerProviderStateMixin {
  late AnimationController _progressController;
  bool _isAccepted = false;
  bool _isLoading = false;
  bool _isRejecting = false;

  @override
  void initState() {
    super.initState();
    // Temporizador oficial de 30 segundos estilo Soy Rappi
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..reverse(from: 1.0);

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !_isAccepted && !_isLoading && !_isRejecting) {
        _rejectOrder(isTimeout: true);
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _rejectOrder({bool isTimeout = false}) async {
    if (_isRejecting || _isAccepted) return;
    _isRejecting = true;
    _progressController.stop();

    final orderId = widget.orderData['order_id']?.toString() ?? widget.orderData['id']?.toString();
    if (orderId != null) {
      widget.onRejected?.call(orderId);
      try {
        final token = ref.read(authProvider).token;
        if (token != null) {
          // Notificar al backend para excluir este pedido del radar del repartidor
          await http.post(
            Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/reject'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
        }
      } catch (e) {
        debugPrint('Error enviando rechazo de orden al backend: $e');
      }
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (isTimeout) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏰ Tiempo agotado para aceptar el pedido.'),
          backgroundColor: Color(0xFF1E2630),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _acceptOrder() async {
    setState(() => _isLoading = true);
    _progressController.stop();
    
    final orderId = widget.orderData['order_id']?.toString() ?? widget.orderData['id']?.toString();
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

        await Future.delayed(const Duration(milliseconds: 700));
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
            content: Text('¡Alguien fue más rápido! El pedido ya fue tomado.'),
            backgroundColor: Color(0xFFE60000),
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
        SnackBar(content: Text('Error de conexión: $e'), backgroundColor: const Color(0xFFE60000))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurantDisplay = widget.orderData['restaurant_name'] ?? widget.orderData['restaurant'] ?? 'Restaurante Local';
    final destinationDisplay = widget.orderData['delivery_address'] ?? widget.orderData['destination'] ?? 'Barrio Centro, Lorica';
    final earningsDisplay = widget.orderData['earnings'] ?? '\$3.000 COP';
    final distanceDisplay = widget.orderData['distance'] ?? '2.5 km';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF151A21),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF2A3442), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner Superior: Alerta y Temporizador Visual
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF00E676), width: 1),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: Color(0xFF00E676), size: 16),
                        SizedBox(width: 4),
                        Text(
                          'NUEVA ORDEN',
                          style: TextStyle(
                            color: Color(0xFF00E676),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  final secondsLeft = (30 * _progressController.value).ceil();
                  final isUrgent = secondsLeft <= 10;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (isUrgent ? const Color(0xFFFF5252) : const Color(0xFF222B36))
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isUrgent ? const Color(0xFFFF5252) : const Color(0xFF37474F),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 15,
                          color: isUrgent ? const Color(0xFFFF5252) : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${secondsLeft}s',
                          style: TextStyle(
                            color: isUrgent ? const Color(0xFFFF5252) : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Ganancia Gigante Estilo Soy Rappi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E2836), Color(0xFF18202A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF2E3D4F), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GANANCIA ESTIMADA',
                      style: TextStyle(
                        color: Color(0xFF8B9BB4),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      earningsDisplay,
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF263238),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.near_me_rounded, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        distanceDisplay,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Ruta Táctica de Despacho (Punto A -> Punto B)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A212A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF2A3644), width: 1),
            ),
            child: Column(
              children: [
                _buildRouteStep(
                  stepLabel: '1. RECOGER EN',
                  title: restaurantDisplay,
                  icon: Icons.storefront_rounded,
                  accentColor: const Color(0xFFFF9100),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 17, top: 4, bottom: 4),
                  child: Row(
                    children: [
                      Container(width: 2, height: 20, color: const Color(0xFF37474F)),
                    ],
                  ),
                ),
                _buildRouteStep(
                  stepLabel: '2. ENTREGAR A CLIENTE',
                  title: destinationDisplay,
                  icon: Icons.location_on_rounded,
                  accentColor: const Color(0xFF00E676),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Barra de Progreso del Tiempo (Visualizador Soy Rappi)
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              final isUrgent = _progressController.value < 0.33;
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progressController.value,
                  minHeight: 6,
                  backgroundColor: const Color(0xFF222B36),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isUrgent ? const Color(0xFFFF5252) : const Color(0xFF00E676),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Botón Circular Masivo de Aceptar o Acción
          _isAccepted
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: Color(0xFF00E676), strokeWidth: 3),
                  ),
                )
              : Row(
                  children: [
                    // Botón Rechazar (Rojo discreto / seguro)
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => _rejectOrder(isTimeout: false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF37474F), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            foregroundColor: const Color(0xFFFF5252),
                          ),
                          child: const Text(
                            'RECHAZAR',
                            style: TextStyle(
                              color: Color(0xFFFF5252),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Botón Masivo ACEPTAR (Verde Neón Soy Rappi)
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _acceptOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            shadowColor: const Color(0xFF00C853).withValues(alpha: 0.5),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      'ACEPTAR PEDIDO',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildRouteStep({
    required String stepLabel,
    required String title,
    required IconData icon,
    required Color accentColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 1.5),
          ),
          child: Icon(icon, color: accentColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stepLabel,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
