import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants/api.dart';
import 'auth_service.dart';

/// Receives forum updates. The server requires the same JWT used by REST APIs.
class ForumRealtimeService {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  Future<void> connect(void Function(Map<String, dynamic>) onEvent) async {
    final token = await AuthService.currentToken();
    if (token == null) return;
    final uri = Uri.parse(ApiConfig.forumWebSocketUrl)
        .replace(queryParameters: {'token': token});
    _channel = WebSocketChannel.connect(uri);
    _subscription = _channel!.stream.listen((message) {
      try {
        onEvent(jsonDecode(message as String) as Map<String, dynamic>);
      } catch (_) {
        // Ignore malformed or unsupported real-time messages.
      }
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
  }
}
