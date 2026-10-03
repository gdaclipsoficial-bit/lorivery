import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:chatbox/core/config/api_config.dart';
import 'package:chatbox/services/websocket_service.dart';
import 'package:chatbox/services/features/auth/presentation/screens/auth_screen.dart';

class OrderChatModal extends ConsumerStatefulWidget {
  final String orderId;
  final String otherPartyName;
  final String otherPartyPhone;
  final String userRole; // CLIENT o COURIER

  const OrderChatModal({
    Key? key,
    required this.orderId,
    required this.otherPartyName,
    required this.otherPartyPhone,
    required this.userRole,
  }) : super(key: key);

  @override
  ConsumerState<OrderChatModal> createState() => _OrderChatModalState();
}

class _OrderChatModalState extends ConsumerState<OrderChatModal> {
  final TextEditingController _msgCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isSending = false;

  final List<String> _quickRepliesClient = [
    '¿En cuánto tiempo llegas?',
    'Estoy listo en la puerta',
    'Por favor timbre al llegar',
    'Gracias por tu servicio 👍',
  ];

  final List<String> _quickRepliesCourier = [
    'Ya voy en camino con tu pedido 🏍️',
    'Estoy afuera de tu domicilio 📍',
    'Tu comida ya está empacada',
    'Llego en 2 minutos ⏱️',
  ];

  @override
  void initState() {
    super.initState();
    // Mensaje de bienvenida inicial
    _messages.add({
      'sender_role': widget.userRole == 'CLIENT' ? 'COURIER' : 'CLIENT',
      'sender_name': widget.otherPartyName,
      'message': '¡Hola! Estoy atento a tu pedido. Escribe aquí cualquier indicación.',
      'time': 'Ahora',
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final msgText = text.trim();
    _msgCtrl.clear();

    setState(() {
      _messages.add({
        'sender_role': widget.userRole,
        'sender_name': 'Tú',
        'message': msgText,
        'time': 'Ahora',
      });
      _isSending = true;
    });

    try {
      final token = ref.read(authProvider).token;
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/orders/${widget.orderId}/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': msgText,
          'sender_role': widget.userRole,
        }),
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showContactInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.phone_forwarded, color: Colors.green),
            const SizedBox(width: 10),
            Text('Contacto: ${widget.otherPartyName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.blue),
              title: Text(widget.otherPartyPhone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: const Text('Número de teléfono'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Llamando a ${widget.otherPartyPhone}...')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final quickReplies = widget.userRole == 'CLIENT' ? _quickRepliesClient : _quickRepliesCourier;

    // Escuchar mensajes en tiempo real desde el WebSocket global
    ref.listen<WebSocketService>(webSocketServiceProvider, (prev, next) {
      if (next.lastLocationData != null && next.lastLocationData!['type'] == 'CHAT_MESSAGE') {
        final data = next.lastLocationData!;
        if (data['sender_role'] != widget.userRole) {
          setState(() {
            _messages.add({
              'sender_role': data['sender_role'],
              'sender_name': data['sender_name'] ?? widget.otherPartyName,
              'message': data['message'],
              'time': 'Ahora',
            });
          });
        }
      }
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header del Chat
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      child: Icon(
                        widget.userRole == 'CLIENT' ? Icons.motorcycle : Icons.person,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.otherPartyName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          widget.userRole == 'CLIENT' ? 'Tu Repartidor en línea' : 'Cliente de la Orden',
                          style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.phone, color: Colors.green),
                      onPressed: _showContactInfo,
                      tooltip: 'Llamar',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Burbujas de mensajes
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender_role'] == widget.userRole;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isMe ? primaryColor : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 0),
                        bottomRight: Radius.circular(isMe ? 0 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['message'],
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg['time'],
                          style: TextStyle(
                            color: isMe ? Colors.white70 : Colors.grey.shade500,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Respuestas Rápidas
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: quickReplies.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    label: Text(quickReplies[index], style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                    onPressed: () => _sendMessage(quickReplies[index]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Input del mensaje
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: const Color(0xFFF1F3F5),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    elevation: 0,
                    backgroundColor: primaryColor,
                    onPressed: () => _sendMessage(_msgCtrl.text),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
