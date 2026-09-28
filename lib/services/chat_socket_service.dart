// 一對一聊天即時通道：wss://.../ws，連上後第一則訊息送 {type:auth, token}（見 Truku_backend backend/realtime.ts）。
// token 不放網址：Cloud Run 請求日誌會記下完整網址（後端已知問題 SEC-01）。
// 除驗證訊息外只接收，不送出——送訊息/已讀一律走 FriendService 的 REST 端點，WS 純粹是推播。
// 指數退避重連；close code 4001 "token expired"（連線中 JWT 自然過期）先重換 JWT 再重連
// （連上前只換一次，換完仍被踢就退回退避），
// 其他 4001（unauthorized / token revoked）不重連、交給 REST 401 導回登入；
// 4003（未同意條款）導去同意頁；1011（握手時後端出錯）等其餘斷線照退避重連。

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

  factory ChatSocketEvent.connected() =>
      const ChatSocketEvent._(ChatSocketEventType.connected);

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
  bool _refreshedForExpiry = false;
  bool _disposed = false;

  /// 每次 [disconnect] 加一；等待中的 connect／換 token 發現世代變了就放棄，
  /// 避免登出前發起的連線在登出後才連上。
  int _generation = 0;

  ChatSocketEvent? lastEvent;

  bool get isConnected => _channel != null;

  @visibleForTesting
  int get reconnectAttempts => _reconnectAttempts;

  @visibleForTesting
  bool get hasPendingReconnect => _reconnectTimer?.isActive ?? false;

  @visibleForTesting
  void debugSimulateClosed(int? closeCode, String? closeReason) =>
      _onClosed(closeCode, closeReason);

  Future<void> connect() async {
    if (_channel != null) return;
    _reconnectTimer?.cancel();
    final generation = _generation;
    final token = await AuthService.currentToken();
    if (token == null || generation != _generation || _channel != null) return;
    final wsBase = ApiConfig.baseUrl.replaceFirst(RegExp(r'^https'), 'wss');
    final uri = Uri.parse('$wsBase/ws');
    try {
      final channel = WebSocketChannel.connect(uri);
      // 10 秒內沒送驗證會被後端以 4001 關閉；連上前 sink 會先暫存這則訊息。
      channel.sink.add(jsonEncode({'type': 'auth', 'token': token}));
      _channel = channel;
      _sub = channel.stream.listen(
        _onData,
        onDone: () => _onClosed(channel.closeCode, channel.closeReason),
        onError: (e) => _onClosed(null, null),
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('ChatController.connect 失敗：$e');
      _scheduleReconnect();
    }
  }

  /// 關閉連線並回到初始狀態（登出時呼叫，下一位登入者從零開始）。
  /// 先取消 [_sub]，sink.close() 就不會再進 [_onClosed] 觸發重連。
  void disconnect() {
    _generation++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    _reconnectAttempts = 0;
    _refreshedForExpiry = false;
    lastEvent = null;
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
        _refreshedForExpiry = false;
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

  void _onClosed(int? closeCode, String? closeReason) {
    _sub?.cancel();
    _channel = null;
    if (_disposed) return;
    if (closeCode == 4001 && closeReason == 'token expired') {
      if (_refreshedForExpiry) {
        // 換過 token 還沒連上又被踢（例如時鐘偏移）：不再打登入端點，退回一般退避。
        _scheduleReconnect();
      } else {
        _refreshedForExpiry = true;
        _refreshAndReconnect();
      }
      return;
    }
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

  /// 舊 token 已過期，拿它重試只會一直被踢；先換新 JWT，換不到就不重連
  /// （交給下一次 REST 呼叫的 401 統一走 ApiClient._forceLogout）。
  /// 每次成功連上前只換一次，避免後端持續踢人時猛打登入端點。
  Future<void> _refreshAndReconnect() async {
    final generation = _generation;
    final ok = await AuthService.refreshSession();
    if (!ok || _disposed || generation != _generation) return;
    await connect();
  }

  void _scheduleReconnect() {
    _reconnectAttempts++;
    _reconnectTimer = Timer(
      Duration(seconds: reconnectDelaySeconds(_reconnectAttempts)),
      connect,
    );
  }

  /// 第 [attempts] 次重連前等幾秒：2、4、8、16，之後固定 30。
  /// 先夾住指數再位移：次數很大時 2 的次方會溢位成負數，變成零間隔狂連。
  @visibleForTesting
  static int reconnectDelaySeconds(int attempts) =>
      min(30, 1 << min(attempts, 5));

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    super.dispose();
  }
}

final chatController = ChatController();
