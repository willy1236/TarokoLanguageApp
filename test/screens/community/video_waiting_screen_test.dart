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

  testWidgets('查詢本身回 403 不當成重新排隊被擋，仍留在等待畫面', (tester) async {
    installMockClient({
      '/api/video/session/current': errorResponse('MUTED', status: 403),
    });

    await openAndPoll(tester);

    expect(find.byType(VideoWaitingScreen), findsOneWidget);
  });

  testWidgets('重新排隊途中按取消：離開後再送一次離開佇列，不留幽靈排隊者', (tester) async {
    final requests = <String>[];
    installMockClient(
      {
        '/api/video/session/current': {'session': null, 'in_queue': false},
        '/api/video/queue': {'matched': false},
      },
      onRequest: (r) => requests.add('${r.method} ${r.url.path}'),
      delayFor: (r) =>
          r.method == 'POST' ? const Duration(seconds: 2) : Duration.zero,
    );

    await openAndPoll(tester);
    expect(requests, contains('POST /api/video/queue'));

    await tester.tap(find.text('取消配對'));
    await pumpFrames(tester, times: 10);
    expect(find.byType(VideoWaitingScreen), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await pumpFrames(tester);
    expect(requests.where((r) => r == 'DELETE /api/video/queue').length, 2);
  });

  group('重新排隊被 403 擋下，同時取消失敗：直接離開，不停在不再輪詢的畫面', () {
    Future<void> run(
      WidgetTester tester, {
      required Duration joinDelay,
      required Duration leaveDelay,
    }) async {
      installMockClient(
        {
          '/api/video/session/current': {'session': null, 'in_queue': false},
          // POST（重新排隊）與 DELETE（離開佇列）都回 403。
          '/api/video/queue': errorResponse(
            'MUTED',
            status: 403,
            message: '你目前被禁言',
          ),
        },
        delayFor: (r) => r.url.path != '/api/video/queue'
            ? Duration.zero
            : r.method == 'POST'
            ? joinDelay
            : leaveDelay,
      );

      await openAndPoll(tester);
      await tester.tap(find.text('取消配對'));
      await pumpFrames(tester);
      await tester.pump(const Duration(seconds: 3));
      await pumpFrames(tester, times: 10);

      expect(find.text('無法取消配對'), findsNothing);
      expect(find.byType(VideoWaitingScreen), findsNothing);
      expect(find.text('OPEN'), findsOneWidget);
    }

    testWidgets('403 先回來、離開佇列才失敗', (tester) async {
      await run(
        tester,
        joinDelay: const Duration(seconds: 1),
        leaveDelay: const Duration(seconds: 2),
      );
    });

    testWidgets('離開佇列先失敗、確認框開著時 403 才回來', (tester) async {
      await run(
        tester,
        joinDelay: const Duration(seconds: 2),
        leaveDelay: Duration.zero,
      );
    });
  });
}
