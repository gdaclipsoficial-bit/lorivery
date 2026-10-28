import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

/// Servicio central de notificaciones locales de Lorivery.
/// Muestra notificaciones cuando el pedido cambia de estado o llega un mensaje de chat.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelOrderId = 'lorivery_order';
  static const _channelChatId = 'lorivery_chat';

  static const _androidOrderChannel = AndroidNotificationDetails(
    _channelOrderId,
    'Estado del Pedido',
    channelDescription: 'Actualizaciones del flujo de tu pedido en Lorivery',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
    color: Color(0xFFE53935),
  );

  static const _androidChatChannel = AndroidNotificationDetails(
    _channelChatId,
    'Chat del Pedido',
    channelDescription: 'Mensajes nuevos de tu repartidor',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
    color: Color(0xFF1976D2),
  );

  Future<void> initialize() async {
    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: initAndroid);
    await _plugin.initialize(initSettings);

    // Solicitar permiso en Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Notificación de cambio de estado del pedido
  Future<void> showOrderStatusNotification({
    required String status,
    required String orderId,
  }) async {
    final (title, body) = _statusMessage(status);
    await _plugin.show(
      orderId.hashCode & 0x7FFFFFFF,
      title,
      body,
      const NotificationDetails(android: _androidOrderChannel),
      payload: 'order:$orderId',
    );
  }

  /// Notificación de nuevo mensaje de chat
  Future<void> showChatNotification({
    required String senderName,
    required String message,
    required String orderId,
  }) async {
    await _plugin.show(
      (orderId + '_chat').hashCode & 0x7FFFFFFF,
      '💬 Mensaje de $senderName',
      message,
      const NotificationDetails(android: _androidChatChannel),
      payload: 'chat:$orderId',
    );
  }

  /// Cancelar todas las notificaciones de una orden
  Future<void> cancelOrderNotifications(String orderId) async {
    await _plugin.cancel(orderId.hashCode & 0x7FFFFFFF);
    await _plugin.cancel((orderId + '_chat').hashCode & 0x7FFFFFFF);
  }

  static (String, String) _statusMessage(String status) {
    return switch (status.toUpperCase()) {
      'CREATED' => (
          '📦 Pedido recibido',
          'Tu pedido fue enviado. Esperando confirmación del restaurante.',
        ),
      'APPROVED_BY_ADMIN' || 'READY' => (
          '✅ Pedido confirmado',
          'El restaurante está preparando tu pedido. Buscando repartidor...',
        ),
      'ASSIGNED' => (
          '🏍️ Repartidor asignado',
          '¡Un repartidor aceptó tu pedido y ya va al restaurante!',
        ),
      'PICKED_UP' => (
          '🛵 Pedido en camino',
          '¡Tu pedido fue recogido y está en camino hacia ti!',
        ),
      'DELIVERED' => (
          '🎉 ¡Pedido entregado!',
          '¡Disfruta tu comida! No olvides calificar a tu repartidor.',
        ),
      _ => ('📱 Lorivery', 'Actualización en tu pedido.'),
    };
  }
}

