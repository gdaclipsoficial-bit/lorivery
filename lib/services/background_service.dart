import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chatbox/services/notification_service.dart';
import 'package:chatbox/core/config/api_config.dart';

/// Inicializa y arranca el servicio de background de Lorivery.
/// Llama esto en main() antes de runApp().
Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // Lo arrancamos manualmente al hacer login
      isForegroundMode: true,
      notificationChannelId: 'lorivery_bg',
      initialNotificationTitle: 'Lorivery activo',
      initialNotificationContent: 'Monitoreando tu pedido...',
      foregroundServiceNotificationId: 9999,
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

/// Arranca el servicio pasando el token y el orderId.
Future<void> startOrderMonitor({
  required String token,
  required String orderId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('bg_token', token);
  await prefs.setString('bg_order_id', orderId);
  await prefs.setString('bg_last_status', '');
  await prefs.setInt('bg_last_chat_count', 0);

  final service = FlutterBackgroundService();
  await service.startService();
}

/// Detiene el servicio cuando el pedido finaliza o el cliente hace logout.
Future<void> stopOrderMonitor() async {
  final service = FlutterBackgroundService();
  service.invoke('stopService');
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('bg_token');
  await prefs.remove('bg_order_id');
}

/// Entry point del isolate de background (debe ser una función top-level).
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final notif = NotificationService();
  await notif.initialize();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Pollca cada 20 segundos
  Timer.periodic(const Duration(seconds: 20), (_) async {
    await _pollOrderStatus(service, notif);
  });
}

Future<void> _pollOrderStatus(
  ServiceInstance service,
  NotificationService notif,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('bg_token');
    final orderId = prefs.getString('bg_order_id');
    if (token == null || orderId == null || orderId.isEmpty) return;

    // ── 1. Verificar estado del pedido ───────────────────────────────
    final orderRes = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/orders/$orderId'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));

    if (orderRes.statusCode == 200) {
      final data = jsonDecode(orderRes.body);
      final newStatus = (data['status'] ?? '').toString();
      final lastStatus = prefs.getString('bg_last_status') ?? '';

      if (newStatus.isNotEmpty && newStatus != lastStatus) {
        await prefs.setString('bg_last_status', newStatus);
        await notif.showOrderStatusNotification(
          status: newStatus,
          orderId: orderId,
        );

        // Detener monitor si el pedido terminó
        if (newStatus.toUpperCase() == 'DELIVERED' ||
            newStatus.toUpperCase() == 'CANCELLED') {
          await prefs.remove('bg_order_id');
          service.stopSelf();
          return;
        }
      }
    }

    // ── 2. Verificar nuevos mensajes de chat ─────────────────────────
    final chatRes = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/chat'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));

    if (chatRes.statusCode == 200) {
      final chatData = jsonDecode(chatRes.body);
      final List<dynamic> msgs = chatData['messages'] ?? [];
      final lastCount = prefs.getInt('bg_last_chat_count') ?? 0;

      if (msgs.length > lastCount) {
        // Hay mensajes nuevos desde la última vez que revisamos
        await prefs.setInt('bg_last_chat_count', msgs.length);
        final newMsg = msgs.last;
        final senderRole = newMsg['sender_role'] ?? '';

        // Solo notificar si el mensaje es del REPARTIDOR (no del cliente mismo)
        if (senderRole == 'COURIER') {
          await notif.showChatNotification(
            senderName: newMsg['sender_name'] ?? 'Repartidor',
            message: newMsg['message'] ?? '',
            orderId: orderId,
          );
        }
      }
    }
  } catch (_) {
    // Silenciar errores de red en background
  }
}

