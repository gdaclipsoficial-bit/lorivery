import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chatbox/core/config/api_config.dart';

final webSocketServiceProvider = ChangeNotifierProvider<WebSocketService>((ref) {
  return WebSocketService();
});

/// Servicio global de WebSocket que mantiene la conexión viva
/// sin importar en qué pantalla esté el usuario.
class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  Map<String, dynamic>? _lastLocationData;
  Map<String, dynamic>? _pendingOrder;

  bool get isConnected => _isConnected;
  Map<String, dynamic>? get lastLocationData => _lastLocationData;
  Map<String, dynamic>? get pendingOrder => _pendingOrder;

  void connect({String orderId = 'demo_order'}) {
    if (_channel != null) return; // Ya conectado
    
    final wsUrl = Uri.parse('${ApiConfig.wsUrl}/ws/orders/$orderId');
    _channel = WebSocketChannel.connect(wsUrl);
    _isConnected = true;
    notifyListeners();

    _channel!.stream.listen((message) {
      final data = jsonDecode(message);
      if (data['type'] == 'NEW_ORDER') {
        _pendingOrder = data;
        notifyListeners();
      }
    }, onError: (error) {
      debugPrint("WebSocket Error: $error");
      _isConnected = false;
      notifyListeners();
    }, onDone: () {
      debugPrint("WebSocket Closed");
      _isConnected = false;
      notifyListeners();
    });
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    notifyListeners();
  }

  void reconnect({String orderId = 'demo_order'}) {
    disconnect();
    connect(orderId: orderId);
  }

  void clearPendingOrder() {
    _pendingOrder = null;
    notifyListeners();
  }

  void sendPayload(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

