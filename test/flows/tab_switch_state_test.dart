// 取代的人工重測：
//   「在底部分頁之間切來切去，看切走再切回的分頁有沒有整個重載、
//     原本的狀態有沒有被沖掉」
//
// MainContainer 用 IndexedStack 保留各分頁的 State。這件事沒有任何斷言保護，
// 一旦有人把 IndexedStack 換成 switch/case 或加了會變動的 key，
// 使用者會看到「切回來又重新轉圈圈」，但所有既有測試都還是綠的。
//
// 注意：IndexedStack 讓五個分頁同時存在於 widget tree，find.text() 會命中
// 非當前分頁的內容。所有斷言都要用 find.descendant 限定範圍。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show MainContainer;
import 'package:flutter_application_1/screens/plaza/plaza_event_screen.dart';
import 'package:flutter_application_1/shared/widgets/truku_bottom_tab.dart';

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

  /// MainContainer.initState 與各分頁載入時會打的端點。
  /// installMockClient 對沒備的 path 會直接 fail 並印出是哪一支，
  /// 之後要加分頁時照著錯誤訊息補即可。
  Map<String, Object?> routes() => {
        '/api/me': {
          'uid': 1,
          'display_name': '測試使用者',
          'created_at': '2026-01-01T00:00:00Z',
          'millet': 100,
          'profile_completed': true,
        },
        '/api/shop/items': {'items': <dynamic>[]},
        '/api/checkin/status': {
          'checked_in_today': false,
          'streak': 0,
          'weekly_count': 0,
          'weekly_bonus_earned': false,
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

  /// 底部分頁沒有 widget Key，只能用標籤文字點。
  /// 標籤定義在 truku_bottom_tab.dart:24。
  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(TrukuBottomTab),
        matching: find.text(label),
      ),
    );
    await pumpFrames(tester);
  }

  testWidgets('切到廣場活動再切回首頁，廣場分頁不會被重建（IndexedStack 保留 State）',
      (tester) async {
    final calls = <String, int>{};
    installMockClient(
      routes(),
      onRequest: (r) =>
          calls[r.url.path] = (calls[r.url.path] ?? 0) + 1,
    );

    usePhoneSurface(tester);
    await tester.pumpWidget(buildTestApp(initialRoute: '/home'));
    await pumpFrames(tester, times: 10);

    // 首頁狀態下，其他分頁雖然在 tree 裡，但 IndexedStack 只 render index 0。
    expect(find.byType(MainContainer), findsOneWidget);

    await tapTab(tester, '廣場活動');
    expect(find.byType(PlazaEventScreen), findsOneWidget);
    final eventCallsAfterFirstVisit = calls['/api/events'] ?? 0;

    await tapTab(tester, '首頁');
    await tapTab(tester, '廣場活動');

    // 關鍵斷言：切回來不該重打 API。重打代表 State 被丟掉了。
    expect(calls['/api/events'] ?? 0, eventCallsAfterFirstVisit,
        reason: '切回廣場活動時重新打了 /api/events，代表分頁 State 沒有被保留');
  });

  testWidgets('五個分頁都切得過去，且切換不會讓 MainContainer 重建', (tester) async {
    installMockClient(routes());

    usePhoneSurface(tester);
    await tester.pumpWidget(buildTestApp(initialRoute: '/home'));
    await pumpFrames(tester, times: 10);

    final stateBefore = tester.state(find.byType(MainContainer));

    for (final label in ['學習影音', '廣場活動', '好友', '我的', '首頁']) {
      await tapTab(tester, label);
      expect(find.byType(MainContainer), findsOneWidget);
    }

    expect(tester.state(find.byType(MainContainer)), same(stateBefore));
  });
}
