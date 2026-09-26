// 取代的人工重測：
//   「把帳號設成唯讀，開 App 看橫幅在不在，再點進活動詳情看橫幅還在不在，
//     然後按報名看有沒有跳出唯讀提示」
//
// 這條人工流程要後端把帳號改成 locked 才能跑，成本很高、重測意願低。
// 而它保護的是一個容易被重構弄掉的設計決定：唯讀橫幅掛在 MaterialApp.builder
// （main.dart:168-180），不是掛在個別畫面 —— 所以 Navigator.push 出來的詳情頁
// 也看得到橫幅。一旦有人把它搬進某個畫面，這個測試會紅。
//
// 註：測試用的是 flow_test_helpers 裡 TestReadOnlyBannerFrame（main.dart 私有類別的鏡像）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show navigatorKey;
import 'package:flutter_application_1/screens/events/event_detail_screen.dart';
import 'package:flutter_application_1/services/account_lock_controller.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

const int _eventId = 1;

Map<String, dynamic> _eventDetail() => {
  'id': _eventId,
  'host_uid': 100,
  'title': '部落豐年祭',
  'description': '一起來跳舞',
  'starts_at': '2026-12-01T10:00:00Z',
  'status': 'active',
  'effective_status': 'active',
  'registration_open': true,
  'is_joined': false,
  'is_liked': false,
  'like_count': 3,
  'participant_count': 5,
};

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
      'email': 'me@example.com',
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
    '/api/forum/posts': {'posts': <dynamic>[], 'total': 0},
    '/api/friends': {'friends': <dynamic>[]},
    '/api/friends/requests': {'requests': <dynamic>[]},
    '/api/friends/messages': {'conversations': <dynamic>[]},
    '/api/events/$_eventId': _eventDetail(),
    '/api/events/$_eventId/reminders': {'reminders': <dynamic>[]},
  };

  Future<void> pumpLockedHome(WidgetTester tester) async {
    installMockClient(routes());
    usePhoneSurface(tester);
    await tester.pumpWidget(buildTestApp(initialRoute: '/home'));
    await pumpFrames(tester, times: 10);
    accountLockController.setLocked(true);
    await pumpFrames(tester);
  }

  testWidgets('唯讀橫幅在首頁顯示，push 詳情頁後仍然只有一條且還在', (tester) async {
    await pumpLockedHome(tester);
    expect(find.text(readOnlyBannerText), findsOneWidget);

    // 用全域 navigatorKey push，和 FCM 深連結走的是同一條路。
    unawaitedPush(const EventDetailScreen(eventId: _eventId));
    await pumpFrames(tester, times: 10);

    expect(find.byType(EventDetailScreen), findsOneWidget);
    expect(
      find.text(readOnlyBannerText),
      findsOneWidget,
      reason: '橫幅應該掛在 MaterialApp.builder，推進來的詳情頁也要看得到，且不該重複',
    );

    // 返回後橫幅仍在，不會被 pop 一起帶走。
    navigatorKey.currentState!.pop();
    await pumpFrames(tester, times: 10);
    expect(find.text(readOnlyBannerText), findsOneWidget);
  });

  testWidgets('解除唯讀後橫幅消失，不需要重開 App', (tester) async {
    await pumpLockedHome(tester);
    expect(find.text(readOnlyBannerText), findsOneWidget);

    accountLockController.setLocked(false);
    await pumpFrames(tester);

    expect(find.text(readOnlyBannerText), findsNothing);
  });

  testWidgets('唯讀狀態下在詳情頁按報名，會被擋下並跳出唯讀提示', (tester) async {
    await pumpLockedHome(tester);
    unawaitedPush(const EventDetailScreen(eventId: _eventId));
    await pumpFrames(tester, times: 10);

    await tester.tap(find.text('我要參加'));
    await pumpFrames(tester, times: 5);

    // blockIfReadOnly() 的 SnackBar 走 main.dart 的全域 scaffoldMessengerKey，
    // buildTestApp 掛的是同一把 key，所以這裡才找得到。
    expect(find.text(readOnlyMessage), findsOneWidget);
  });
}

/// 透過全域 navigatorKey 推一個畫面。回傳的 Future 不需要等，
/// 等它會卡到 pop 為止。
void unawaitedPush(Widget screen) {
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(builder: (_) => screen),
  );
}
