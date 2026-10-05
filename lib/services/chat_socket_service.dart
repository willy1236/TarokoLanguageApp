// 一對一聊天即時通道：wss://.../ws，連上後第一則訊息送 {type:auth, token}（見 Truku_backend backend/realtime.ts）。
// token 不放網址：Cloud Run 請求日誌會記下完整網址（後端已知問題 SEC-01）。
// 除驗證訊息外只接收，不送出——送訊息/已讀一律走 FriendService 的 REST 端點，WS 純粹是推播。
// 通話事件（與同名推播同時送出，見 Truku_backend API/即時連線.md「通話事件」）
// 不走 lastEvent，另從 [ChatController.callEvents] 送出，由 main.dart 轉給 FcmService。
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
import '../core/network/api_client.dart';
import '../models/friend_message_model.dart';
import 'auth_service.dart';

enum ChatSocketEventType { connected, message, read, call }

class ChatSocketEvent {
  final ChatSocketEventType type;
  final FriendMessage? message;

  /// 事件來自哪位對象：message 是傳訊者、read 是讀了我訊息的人，用來判斷
  /// 屬於哪個聊天室。
  final String? friendCode;
  final int? count;

  /// 通話事件的原始內容（含 type；id 一律字串），格式與同名推播的 data 相同。
  final Map<String, String>? callData;

  const ChatSocketEvent._(
    this.type, {
    this.message,
    this.friendCode,
    this.count,
    this.callData,
  });

  static const _callTypes = {
    'video_matched',
    'video_session_ended',
    'friend_call_incoming',
    'friend_call_accepted',
    'friend_call_declined',
    'friend_call_cancelled',
    'friend_call_ended',
  };

  factory ChatSocketEvent.connected() =>
      const ChatSocketEvent._(ChatSocketEventType.connected);

  factory ChatSocketEvent.message(
    FriendMessage message, {
    required String fromFriendCode,
  }) => ChatSocketEvent._(
    ChatSocketEventType.message,
    message: message,
    friendCode: fromFriendCode,
  );

  factory ChatSocketEvent.read({
    required String byFriendCode,
    required int count,
  }) => ChatSocketEvent._(
    ChatSocketEventType.read,
    friendCode: byFriendCode,
    count: count,
  );

  factory ChatSocketEvent.call(Map<String, String> data) =>
      ChatSocketEvent._(ChatSocketEventType.call, callData: data);

  /// 伺服器推來的一則事件；不認得的類型或格式不對回 null。
  static ChatSocketEvent? fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    if (_callTypes.contains(type)) {
      return ChatSocketEvent.call({
        for (final e in json.entries)
          if (e.value != null) e.key: e.value.toString(),
      });
    }
    switch (type) {
      case 'connected':
        return ChatSocketEvent.connected();
      case 'message':
        final m = json['message'];
        return m is Map<String, dynamic>
            ? ChatSocketEvent.message(
                FriendMessage.fromJson(m),
                fromFriendCode: json['from_friend_code'] as String? ?? '',
              )
            : null;
      case 'read':
        return ChatSocketEvent.read(
          byFriendCode: json['by_friend_code'] as String? ?? '',
          count: (json['count'] as num?)?.toInt() ?? 0,
        );
    }
    return null;
  }
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

  final _callEvents = StreamController<Map<String, String>>.broadcast();

  /// 通話事件。另開 stream 而不走 [lastEvent]：連續兩則事件時，
  /// 監聽者可能只讀到後一則。
  Stream<Map<String, String>> get callEvents => _callEvents.stream;

  bool get isConnected => _channel != null;

  @visibleForTesting
  int get reconnectAttempts => _reconnectAttempts;

  @visibleForTesting
  bool get hasPendingReconnect => _reconnectTimer?.isActive ?? false;

  @visibleForTesting
  void debugSimulateClosed(int? closeCode, String? closeReason) =>
      _onClosed(closeCode, closeReason);

  /// 模擬伺服器推來一則事件（原始 JSON 字串），不必真的連 WebSocket。
  @visibleForTesting
  void debugSimulateData(String raw) => _onData(raw);

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
    final event = ChatSocketEvent.fromJson(json);
    if (event == null) return;
    if (event.type == ChatSocketEventType.call) {
      _callEvents.add(event.callData!);
      return;
    }
    if (event.type == ChatSocketEventType.connected) {
      _reconnectAttempts = 0;
      _refreshedForExpiry = false;
    }
    lastEvent = event;
    notifyListeners();
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
      // 與 REST 的 CONSENT_REQUIRED 同一個入口，兩邊同時發生也只疊一層。
      ApiClient.showConsent();
      return;
    }
    _scheduleReconnect();
  }

  /// 舊 token 已過期，拿它重試只會一直被踢；先換新 JWT，換不到就不重連
  /// （交給下一次 REST 呼叫的 401 統一走 ApiClient._forceLogout）。
  /// 每次成功連上前只換一次，避免後端持續踢人時猛打登入端點。
  Future<void> _refreshAndReconnect() async {
    final generation = _generation;
    final outcome = await AuthService.refreshSession();
    if (outcome != RefreshOutcome.ok ||
        _disposed ||
        generation != _generation) {
      return;
    }
    await connect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
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
    _callEvents.close();
    super.dispose();
  }
}

final chatController = ChatController();
