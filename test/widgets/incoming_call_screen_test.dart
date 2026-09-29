import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/models/friend_model.dart';
import 'package:flutter_application_1/screens/friends/incoming_call_screen.dart';

const _callId = 7;

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// 依路徑回應：來電狀態取自 [status]()，接聽固定回 500，其餘（商品目錄）回 404。
MockClient _backend(
  String Function() status, {
  List<String>? log,
  Duration acceptDelay = Duration.zero,
}) => MockClient((req) async {
  final path = req.url.path;
  log?.add('${req.method} $path');
  if (path == '/api/friends/calls/$_callId') {
    return _json({
      'call_id': _callId,
      'status': status(),
      'is_caller': false,
      'peer_friend_code': 'BBBB2345',
    });
  }
  if (path == '/api/friends/calls/$_callId/accept') {
    await Future<void>.delayed(acceptDelay);
    return _json({
      'error': {'code': 'INTERNAL', 'message': 'boom'},
    }, 500);
  }
  return _json({
    'error': {'code': 'NOT_FOUND', 'message': 'not found'},
  }, 404);
});

/// 從首頁 push 出響鈴畫面，才能驗證它有沒有自己 pop 回來。
Future<void> _openScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => IncomingCallScreen(
                call: IncomingCall(
                  callId: _callId,
                  callerFriendCode: 'BBBB2345',
                  callerNickname: '阿美',
                  createdAt: DateTime(2026),
                ),
              ),
            ),
          ),
          child: const Text('home'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('home'));
  await tester.pumpAndSettle();
  expect(find.byType(IncomingCallScreen), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // secure storage（ApiClient 讀 token）、audioplayers、vibration 在測試環境沒有原生實作。
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
      'vibration',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
  });

  tearDown(() => ApiClient.httpClient = http.Client());

  testWidgets('撥出方取消後顯示提示並自動關閉', (tester) async {
    ApiClient.httpClient = _backend(() => 'cancelled');
    await _openScreen(tester);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('對方已取消通話'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.byType(IncomingCallScreen), findsNothing);
  });

  testWidgets('仍在響鈴時畫面保持開啟', (tester) async {
    ApiClient.httpClient = _backend(() => 'ringing');
    await _openScreen(tester);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(find.byType(IncomingCallScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('接聽暫時性失敗後恢復輪詢，對方取消仍會自動關閉', (tester) async {
    var status = 'ringing';
    ApiClient.httpClient = _backend(() => status);
    await _openScreen(tester);

    await tester.tap(find.text('接聽'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(IncomingCallScreen), findsOneWidget);

    status = 'cancelled';
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.byType(IncomingCallScreen), findsNothing);
  });

  testWidgets('返回鍵等於拒接：送出拒接並關閉畫面', (tester) async {
    final log = <String>[];
    ApiClient.httpClient = _backend(() => 'ringing', log: log);
    await _openScreen(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(log, contains('POST /api/friends/calls/$_callId/decline'));
    expect(find.byType(IncomingCallScreen), findsNothing);
  });

  testWidgets('接聽處理中按返回不送拒接，也不關畫面', (tester) async {
    final log = <String>[];
    ApiClient.httpClient = _backend(
      () => 'ringing',
      log: log,
      acceptDelay: const Duration(seconds: 2),
    );
    await _openScreen(tester);

    await tester.tap(find.text('接聽'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 500));

    // 接聽請求還沒回來：返回鍵要被擋下，畫面留著等接聽結果。返回鍵沒被擋下
    // 的話響鈴畫面正在退場，底下的首頁就點得到。
    expect(log.where((l) => l.endsWith('/decline')), isEmpty);
    expect(find.text('home').hitTestable(), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });
}
