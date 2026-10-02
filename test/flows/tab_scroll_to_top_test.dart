// 取代的人工重測：
//   「在某個底部分頁捲到中段，切到別的分頁再切回來，看是不是從最上面開始；
//     再點一次目前分頁也要捲回最上面」
//
// 個人視訊分頁用膠囊 + IndexedStack 疊「個人資料」「視訊配對」兩塊，
// 兩塊都要回到最上面，不只目前顯示的那塊。

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/profile/profile_video_screen.dart';
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

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(TrukuBottomTab),
        matching: find.text(label),
      ),
    );
    await pumpFrames(tester);
  }

  /// 個人視訊分頁底下（含沒顯示的膠囊那塊）所有垂直捲動位置。
  List<ScrollPosition> profileVideoPositions(WidgetTester tester) => tester
      .stateList<ScrollableState>(
        find.descendant(
          of: find.byType(ProfileVideoScreen, skipOffstage: false),
          matching: find.byType(Scrollable, skipOffstage: false),
          skipOffstage: false,
        ),
      )
      .map((s) => s.position)
      .where((p) => p.axis == Axis.vertical)
      .toList();

  /// 把每個捲得動的垂直位置捲到中段，回傳捲動過的那些。
  List<ScrollPosition> scrollAllToMiddle(WidgetTester tester) {
    final scrolled = <ScrollPosition>[];
    for (final p in profileVideoPositions(tester)) {
      if (p.hasContentDimensions && p.maxScrollExtent > 0) {
        p.jumpTo(math.min(150, p.maxScrollExtent));
        scrolled.add(p);
      }
    }
    return scrolled;
  }

  Future<void> pumpApp(WidgetTester tester) async {
    installMockClient(routes());
    // 畫面矮一點，個人資料與視訊配對兩塊都捲得動。
    usePhoneSurface(tester, size: const Size(414, 500));
    await tester.pumpWidget(buildTestApp(initialRoute: '/home'));
    await pumpFrames(tester, times: 10);
    await tapTab(tester, '我的');
  }

  testWidgets('個人視訊兩塊都捲到中段，切到首頁再切回來，兩塊都在最上面', (tester) async {
    await pumpApp(tester);

    final scrolled = scrollAllToMiddle(tester);
    expect(scrolled.length, greaterThanOrEqualTo(2), reason: '兩塊內容都要捲得動才驗得到');
    await tester.pump();

    await tapTab(tester, '首頁');
    await tapTab(tester, '我的');

    for (final p in profileVideoPositions(tester)) {
      expect(p.pixels, 0);
    }
  });

  testWidgets('再點一次目前所在的分頁也捲回最上面', (tester) async {
    await pumpApp(tester);

    expect(scrollAllToMiddle(tester), isNotEmpty);
    await tester.pump();

    await tapTab(tester, '我的');

    for (final p in profileVideoPositions(tester)) {
      expect(p.pixels, 0);
    }
  });
}
