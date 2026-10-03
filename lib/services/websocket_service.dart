import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chatbox/core/config/api_config.dart';

final webSocketServiceProvider = ChangeNotifierProvider<WebSocketService>((ref) {
  return WebSocketService();
});

/// Servicio global de WebSocket que mantiene conexiones activas por room.
class WebSocketService extends ChangeNotifier {
  // Canal principal (demo_order para el radar de repartidores)
  WebSocketChannel? _mainChannel;
  // Canal del pedido activo (para chat y tracking)
  WebSocketChannel? _orderChannel;
  String? _connectedOrderId;

  bool _isConnected = false;
  Map<String, dynamic>? _lastLocationData;
  Map<String, dynamic>? _pendingOrder;
  Map<String, dynamic>? _lastChatMessage;
  Map<String, dynamic>? _lastStatusUpdate;

  bool get isConnected => _isConnected;
  Map<String, dynamic>? get lastLocationData => _lastLocationData;
  Map<String, dynamic>? get pendingOrder => _pendingOrder;
  Map<String, dynamic>? get lastChatMessage => _lastChatMessage;
  Map<String, dynamic>? get lastStatusUpdate => _lastStatusUpdate;
  String? get connectedOrderId => _connectedOrderId;

  void connect({String orderId = 'demo_order'}) {
    if (_mainChannel != null) return; // Ya conectado al radar

    final wsUrl = Uri.parse('${ApiConfig.wsUrl}/ws/orders/$orderId');
    _mainChannel = WebSocketChannel.connect(wsUrl);
    _isConnected = true;
    notifyListeners();

    _mainChannel!.stream.listen((message) {
      final data = jsonDecode(message);
      if (data['type'] == 'NEW_ORDER') {
        _pendingOrder = data;
        notifyListeners();
      } else if (data['type'] == 'STATUS_UPDATE') {
        _lastStatusUpdate = data;
        notifyListeners();
      } else if (data['type'] == 'CHAT_MESSAGE') {
        _lastChatMessage = data;
        _lastLocationData = data; // compatibilidad hacia atrás
        notifyListeners();
      } else {
        _lastLocationData = data;
        notifyListeners();
      }
    }, onError: (error) {
      debugPrint("WebSocket Error (main): $error");
      _isConnected = false;
      notifyListeners();
    }, onDone: () {
      debugPrint("WebSocket Closed (main)");
      _isConnected = false;
      notifyListeners();
    });
  }

  /// Conectar al WebSocket de un pedido específico (para chat y tracking en tiempo real)
  void connectToOrder(String orderId) {
    if (_connectedOrderId == orderId && _orderChannel != null) return;

    // Desconectar canal anterior si era diferente
    _orderChannel?.sink.close();
    _orderChannel = null;
    _connectedOrderId = orderId;

    final wsUrl = Uri.parse('${ApiConfig.wsUrl}/ws/orders/$orderId');
    _orderChannel = WebSocketChannel.connect(wsUrl);
    notifyListeners();

    _orderChannel!.stream.listen((message) {
      final data = jsonDecode(message);
      if (data['type'] == 'CHAT_MESSAGE') {
        _lastChatMessage = data;
        _lastLocationData = data; // compatibilidad
        notifyListeners();
      } else if (data['type'] == 'STATUS_UPDATE') {
        _lastStatusUpdate = data;
        notifyListeners();
      } else {
        _lastLocationData = data;
        notifyListeners();
      }
    }, onError: (error) {
      debugPrint("WebSocket Error (order $orderId): $error");
    }, onDone: () {
      debugPrint("WebSocket Closed (order $orderId)");
      _connectedOrderId = null;
    });
  }

  void disconnectFromOrder() {
    _orderChannel?.sink.close();
    _orderChannel = null;
    _connectedOrderId = null;
    _lastChatMessage = null;
    notifyListeners();
  }

  void disconnect() {
    _mainChannel?.sink.close();
    _mainChannel = null;
    _orderChannel?.sink.close();
    _orderChannel = null;
    _connectedOrderId = null;
    _isConnected = false;
    notifyListeners();
  }

  void reconnect({String orderId = 'demo_order'}) {
    _mainChannel?.sink.close();
    _mainChannel = null;
    _isConnected = false;
    connect(orderId: orderId);
  }

  void clearPendingOrder() {
    _pendingOrder = null;
    notifyListeners();
  }

  void clearLastChatMessage() {
    _lastChatMessage = null;
    notifyListeners();
  }

  void sendPayload(Map<String, dynamic> data) {
    if (_isConnected && _mainChannel != null) {
      _mainChannel!.sink.add(jsonEncode(data));
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
