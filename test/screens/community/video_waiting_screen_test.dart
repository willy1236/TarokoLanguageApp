// 配對等待畫面的佇列心跳：被後端移出佇列（切背景超過 30 秒）時重新排隊，
// 重新排隊被 403 擋下就停止並離開。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/community/video_waiting_screen.dart';

import '../../helpers/flow_test_helpers.dart';
import '../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  Widget app() => MaterialApp(
    scaffoldMessengerKey: scaffoldMessengerKey,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const VideoWaitingScreen())),
          child: const Text('OPEN'),
        ),
      ),
    ),
  );

  /// 開啟等待畫面並跑過第一次輪詢（4 秒）。
  Future<void> openAndPoll(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('OPEN'));
    await pumpFrames(tester);
    await tester.pump(const Duration(seconds: 4));
    await pumpFrames(tester);
  }

  testWidgets('仍在佇列時不重新排隊', (tester) async {
    var queuePosts = 0;
    installMockClient(
      {
        '/api/video/session/current': {'session': null, 'in_queue': true},
      },
      onRequest: (r) {
        if (r.url.path == '/api/video/queue') queuePosts++;
      },
    );

    await openAndPoll(tester);

    expect(queuePosts, 0);
    expect(find.byType(VideoWaitingScreen), findsOneWidget);
  });

  testWidgets('被移出佇列時重新排隊，仍未配到就繼續等待', (tester) async {
    var queuePosts = 0;
    installMockClient(
      {
        '/api/video/session/current': {'session': null, 'in_queue': false},
        '/api/video/queue': {'matched': false},
      },
      onRequest: (r) {
        if (r.url.path == '/api/video/queue' && r.method == 'POST') {
          queuePosts++;
        }
      },
    );

    await openAndPoll(tester);

    expect(queuePosts, 1);
    expect(find.byType(VideoWaitingScreen), findsOneWidget);
  });

  testWidgets('重新排隊回 403：停止輪詢、顯示原因並離開', (tester) async {
    var queuePosts = 0;
    installMockClient(
      {
        '/api/video/session/current': {'session': null, 'in_queue': false},
        '/api/video/queue': errorResponse(
          'MUTED',
          status: 403,
          message: '你目前被禁言',
        ),
      },
      onRequest: (r) {
        if (r.url.path == '/api/video/queue') queuePosts++;
      },
    );

    await openAndPoll(tester);

    expect(find.byType(VideoWaitingScreen), findsNothing);
    expect(find.textContaining('你目前被禁言'), findsOneWidget);

    // 已離開畫面，不再重試。
    await tester.pump(const Duration(seconds: 8));
    expect(queuePosts, 1);
  });
}
