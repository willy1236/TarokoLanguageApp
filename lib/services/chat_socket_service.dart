// 一對一聊天即時通道：wss://.../ws?token=<JWT>（見 Truku_backend backend/realtime.ts）。
// 只接收，不送出——送訊息/已讀一律走 FriendService 的 REST 端點，WS 純粹是推播。
// 指數退避重連；close code 4001（JWT 失效）導回登入，4003（未同意條款）導去同意頁。

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants/api.dart';
import '../main.dart';
import '../models/friend_message_model.dart';
import 'auth_service.dart';

enum ChatSocketEventType { connected, message, read }

class ChatSocketEvent {
  final ChatSocketEventType type;
  final FriendMessage? message;
  final int? byUid;
  final int? count;

  const ChatSocketEvent._(this.type, {this.message, this.byUid, this.count});

  factory ChatSocketEvent.connected() => const ChatSocketEvent._(ChatSocketEventType.connected);

  factory ChatSocketEvent.message(FriendMessage message) =>
      ChatSocketEvent._(ChatSocketEventType.message, message: message);

  factory ChatSocketEvent.read({required int byUid, required int count}) =>
      ChatSocketEvent._(ChatSocketEventType.read, byUid: byUid, count: count);
}

class ChatController extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  ChatSocketEvent? lastEvent;

  bool get isConnected => _channel != null;

  Future<void> connect() async {
    if (_channel != null) return;
    _reconnectTimer?.cancel();
    final token = await AuthService.currentToken();
    if (token == null) return;
    final wsBase = ApiConfig.baseUrl.replaceFirst(RegExp(r'^https'), 'wss');
    final uri = Uri.parse('$wsBase/ws').replace(queryParameters: {'token': token});
    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _sub = channel.stream.listen(
        _onData,
        onDone: () => _onClosed(channel.closeCode),
        onError: (e) => _onClosed(null),
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('ChatController.connect 失敗：$e');
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void _onData(dynamic raw) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('ChatController: 無法解析 WS 訊息：$raw');
      return;
    }
    switch (json['type']) {
      case 'connected':
        _reconnectAttempts = 0;
        lastEvent = ChatSocketEvent.connected();
        notifyListeners();
        break;
      case 'message':
        final m = json['message'];
        if (m is Map<String, dynamic>) {
          lastEvent = ChatSocketEvent.message(FriendMessage.fromJson(m));
          notifyListeners();
        }
        break;
      case 'read':
        lastEvent = ChatSocketEvent.read(
          byUid: (json['by_uid'] as num?)?.toInt() ?? 0,
          count: (json['count'] as num?)?.toInt() ?? 0,
        );
        notifyListeners();
        break;
    }
  }

  void _onClosed(int? closeCode) {
    _sub?.cancel();
    _channel = null;
    if (_disposed) return;
    if (closeCode == 4001) {
      // JWT 失效：交給下一次 REST 呼叫的 401 統一走 ApiClient._forceLogout，這裡不重連。
      return;
    }
    if (closeCode == 4003) {
      navigatorKey.currentState?.pushNamed('/terms-consent');
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectAttempts++;
    final seconds = min(30, pow(2, _reconnectAttempts).toInt());
    _reconnectTimer = Timer(Duration(seconds: seconds), connect);
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    super.dispose();
  }
}

final chatController = ChatController();
