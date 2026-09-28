// 回前景會重新查簽到狀態。查詢還沒回來時使用者按了簽到，較晚回來的舊狀態
// （尚未簽到）不能蓋掉簽到成功的畫面。

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels(token: 'test-token');
    resetGlobals();
  });

  tearDown(() {
    restoreHttp();
    resetGlobals();
  });

  const notCheckedIn = {
    'checked_in_today': false,
    'checkin_streak': 0,
    'millet': 100,
  };

  Map<String, Object?> routes() => {
    '/api/me': {
      'uid': 1,
      'display_name': '測試使用者',
      'created_at': '2026-01-01T00:00:00Z',
      'millet': 100,
      'profile_completed': true,
    },
    '/api/shop/items': {'items': <dynamic>[]},
    '/api/checkin/status': notCheckedIn,
    '/api/checkin': {
      'checked_in_today': true,
      'checkin_streak': 1,
      'millet': 150,
    },
    '/api/notifications/summary': {
      'forum_unread': 0,
      'event_unread': 0,
      'friend_requests': 0,
    },
    '/api/levels': {'levels': <dynamic>[]},
    '/api/videos': {'videos': <dynamic>[], 'total': 0},
    '/api/articles': {'articles': <dynamic>[], 'total': 0},
    '/api/events': {'events': <dynamic>[], 'total': 0},
    '/api/forum/boards': {'boards': <dynamic>[]},
    '/api/friends': {'friends': <dynamic>[]},
    '/api/friends/requests': {'requests': <dynamic>[]},
    '/api/friends/messages': {'conversations': <dynamic>[]},
    '/api/forum/posts': {'posts': <dynamic>[], 'total': 0},
  };

  testWidgets('回前景的狀態查詢較晚回來，不會蓋掉簽到成功', (tester) async {
    var slowStatus = false;
    installMockClient(
      routes(),
      delayFor: (r) => slowStatus && r.url.path == '/api/checkin/status'
          ? const Duration(seconds: 2)
          : Duration.zero,
    );

    usePhoneSurface(tester);
    await tester.pumpWidget(buildTestApp(initialRoute: '/home'));
    await pumpFrames(tester, times: 10);
    expect(find.text('立即簽到'), findsOneWidget);

    slowStatus = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    await tester.tap(find.text('立即簽到'));
    await pumpFrames(tester);
    expect(find.text('已簽到'), findsOneWidget);

    // 回前景那次查詢現在才回來，內容是簽到前的狀態。
    await pumpFrames(tester, times: 25);
    expect(find.text('已簽到'), findsOneWidget);
    expect(find.text('立即簽到'), findsNothing);
  });
}
