// EventDetailScreen（活動詳情）的畫面層測試。
//
// 這支取代的人工測試：開一場活動、填 email 報名、看有沒有跳成「已報名」、
// 按讚的樂觀更新在後端失敗時會不會還原、唯讀帳號按讚有沒有被擋。
// 報名／退出人工重測一次就要清一次報名狀態，很容易把測試資料弄髒。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/core/utils/date_format.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/events/event_detail_screen.dart';
import 'package:flutter_application_1/screens/events/widgets/event_detail_dialogs.dart';
import 'package:flutter_application_1/services/account_lock_controller.dart';
import 'package:flutter_application_1/services/fcm_service.dart';
import 'package:flutter_application_1/services/user_service.dart';
import 'package:flutter_application_1/shared/widgets/async_state_view.dart';

import '../helpers/widget_test_helpers.dart';

const int _eventId = 1;
const int _myUid = 1;

Map<String, dynamic> _detail({
  bool isHost = false,
  bool isJoined = false,
  bool isLiked = false,
  int likeCount = 3,
  String effectiveStatus = 'active',
}) => {
  'id': _eventId,
  'is_host': isHost,
  'title': '部落豐年祭',
  'description': '一起來跳舞',
  'starts_at': '2026-12-01T10:00:00Z',
  'status': 'active',
  'effective_status': effectiveStatus,
  'registration_open': true,
  'is_joined': isJoined,
  'is_liked': isLiked,
  'like_count': likeCount,
  'participant_count': 5,
};

Map<String, dynamic> _me() => {
  'uid': _myUid,
  'created_at': '2026-01-01T00:00:00Z',
  'email': 'me@example.com',
};

Widget _app() => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: const EventDetailScreen(eventId: _eventId),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    accountLockController.setLocked(false);
    UserService.clearCache();
  });

  tearDown(() {
    restoreHttp();
    accountLockController.setLocked(false);
    UserService.clearCache();
  });

  testWidgets('載入失敗顯示錯誤畫面並可重試', (tester) async {
    var calls = 0;
    installMockClient(
      {
        '/api/events/1': errorResponse('SERVER_ERROR', status: 500),
        '/api/events/1/reminders': {'reminders': <dynamic>[]},
        '/api/me': _me(),
      },
      onRequest: (req) {
        if (req.url.path == '/api/events/1') calls++;
      },
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(TrukuErrorView), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(calls, 2);
  });

  testWidgets('提醒紀錄抓不到（非參加者會 403）不該讓整頁失敗', (tester) async {
    installMockClient({
      '/api/events/1': _detail(),
      '/api/events/1/reminders': errorResponse('FORBIDDEN', status: 403),
      '/api/me': _me(),
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(TrukuErrorView), findsNothing);
    expect(find.text('部落豐年祭'), findsWidgets);
  });

  testWidgets('報名要先填聯絡 Email，送出後顯示已報名', (tester) async {
    var joined = false;
    String? sentBody;
    installMockClient(
      {
        '/api/events/1': _detail(),
        '/api/events/1/reminders': {'reminders': <dynamic>[]},
        '/api/me': _me(),
        '/api/events/1/join': <String, dynamic>{},
      },
      onRequest: (req) {
        if (req.url.path == '/api/events/1/join') {
          joined = true;
          sentBody = req.body;
        }
      },
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('我要參加'));
    await tester.pumpAndSettle();

    // 對話框要預填帳號 email，讓使用者確認而不是從頭打字。
    expect(find.byType(JoinEmailDialog), findsOneWidget);
    expect(find.text('me@example.com'), findsOneWidget);

    await tester.tap(find.text('確認報名'));
    await tester.pumpAndSettle();

    expect(joined, isTrue);
    expect(sentBody, contains('me@example.com'));
    expect(find.text('已報名'), findsWidgets);
  });

  group('返回結果', () {
    Map<String, Object?> routes() => {
      '/api/events/1': _detail(),
      '/api/events/1/reminders': {'reminders': <dynamic>[]},
      '/api/me': _me(),
      '/api/events/1/join': <String, dynamic>{},
    };

    /// 從一個空白頁推入詳情頁，回傳返回時的結果。
    Future<Future<bool?>> openDetail(WidgetTester tester) async {
      late BuildContext home;
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: Builder(
            builder: (c) {
              home = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final result = Navigator.push<bool>(
        home,
        EventDetailScreen.route<bool>(_eventId),
      );
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('沒有變動就返回：結果不是 true，列表不必重載', (tester) async {
      installMockClient(routes());
      final result = await openDetail(tester);

      await tester.binding.handlePopRoute(); // Android 返回鍵
      await tester.pumpAndSettle();

      expect(await result, isNot(true));
    });

    testWidgets('報名後返回（系統返回鍵）：結果為 true', (tester) async {
      installMockClient(routes());
      final result = await openDetail(tester);

      await tester.tap(find.text('我要參加'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認報名'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(await result, isTrue);
    });
  });

  testWidgets('報名對話框 Email 格式錯誤時不送出', (tester) async {
    var joined = false;
    installMockClient(
      {
        '/api/events/1': _detail(),
        '/api/events/1/reminders': {'reminders': <dynamic>[]},
        '/api/me': _me(),
        '/api/events/1/join': <String, dynamic>{},
      },
      onRequest: (req) {
        if (req.url.path == '/api/events/1/join') joined = true;
      },
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('我要參加'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bad-email');
    await tester.tap(find.text('確認報名'));
    await tester.pumpAndSettle();

    expect(find.text('請輸入有效的 Email'), findsOneWidget);
    expect(joined, isFalse);
  });

  testWidgets('取消報名對話框則不打 API', (tester) async {
    var joined = false;
    installMockClient(
      {
        '/api/events/1': _detail(),
        '/api/events/1/reminders': {'reminders': <dynamic>[]},
        '/api/me': _me(),
        '/api/events/1/join': <String, dynamic>{},
      },
      onRequest: (req) {
        if (req.url.path == '/api/events/1/join') joined = true;
      },
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('我要參加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(joined, isFalse);
  });

  testWidgets('報名被後端拒絕時顯示後端訊息', (tester) async {
    installMockClient({
      '/api/events/1': _detail(),
      '/api/events/1/reminders': {'reminders': <dynamic>[]},
      '/api/me': _me(),
      '/api/events/1/join': errorResponse(
        'EVENT_FULL',
        status: 409,
        message: '名額已滿',
      ),
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('我要參加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確認報名'));
    await tester.pumpAndSettle();

    expect(find.text('名額已滿'), findsOneWidget);
  });

  testWidgets('唯讀模式下按讚被擋，且不打 API', (tester) async {
    var likeCalls = 0;
    installMockClient(
      {
        '/api/events/1': _detail(isLiked: false),
        '/api/events/1/reminders': {'reminders': <dynamic>[]},
        '/api/me': _me(),
        '/api/events/1/like': {'liked': true, 'like_count': 4},
      },
      onRequest: (req) {
        if (req.url.path == '/api/events/1/like') likeCalls++;
      },
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    accountLockController.setLocked(true);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(find.text(readOnlyMessage), findsOneWidget);
    expect(likeCalls, 0);
  });

  testWidgets('按讚失敗時樂觀更新要還原', (tester) async {
    installMockClient({
      '/api/events/1': _detail(isLiked: false, likeCount: 3),
      '/api/events/1/reminders': {'reminders': <dynamic>[]},
      '/api/me': _me(),
      '/api/events/1/like': errorResponse('SERVER_ERROR', status: 500),
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    // 還原後應該回到未按讚的圖示與原本的計數。
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.text('3'), findsWidgets);
  });

  group('報名資訊與取消理由', () {
    Future<void> pumpDetail(
      WidgetTester tester,
      Map<String, dynamic> extra,
    ) async {
      installMockClient({
        '/api/events/1': {..._detail(), ...extra},
        '/api/events/1/reminders': {'reminders': <dynamic>[]},
        '/api/me': _me(),
      });
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
    }

    testWidgets('已報名時顯示報名時間', (tester) async {
      await pumpDetail(tester, {
        'is_joined': true,
        'my_registration': {
          'joined_at': '2026-11-20T02:30:00Z',
          'contact_email': 'me@example.com',
        },
      });
      final local = DateTime.utc(2026, 11, 20, 2, 30).toLocal();
      expect(find.text('你已於 ${formatDateTime(local)} 報名'), findsOneWidget);
    });

    testWidgets('發起人看自己的活動不顯示報名時間', (tester) async {
      await pumpDetail(tester, {
        'is_host': true,
        'is_joined': true,
        'my_registration': {
          'joined_at': '2026-11-20T02:30:00Z',
          'contact_email': 'me@example.com',
        },
      });
      expect(find.text('部落豐年祭'), findsWidgets);
      expect(find.textContaining('你已於'), findsNothing);
    });

    testWidgets('報名資訊格式不對時照常顯示活動，只是沒有報名時間', (tester) async {
      await pumpDetail(tester, {
        'is_joined': true,
        'my_registration': {'joined_at': 'not-a-date', 'contact_email': 42},
      });
      expect(find.byType(TrukuErrorView), findsNothing);
      expect(find.text('部落豐年祭'), findsWidgets);
      expect(find.textContaining('你已於'), findsNothing);
    });

    testWidgets('未報名時不顯示報名時間', (tester) async {
      await pumpDetail(tester, {'my_registration': null});
      expect(find.textContaining('你已於'), findsNothing);
    });

    testWidgets('已取消且有理由：照原樣顯示（含 *）', (tester) async {
      await pumpDetail(tester, {
        'status': 'cancelled',
        'effective_status': 'cancelled',
        'cancel_reason': '颱風 *停班停課*',
      });
      expect(find.text('取消理由：颱風 *停班停課*'), findsOneWidget);
    });

    testWidgets('已取消但理由為 null：不顯示理由列', (tester) async {
      await pumpDetail(tester, {
        'status': 'cancelled',
        'effective_status': 'cancelled',
        'cancel_reason': null,
      });
      expect(find.textContaining('取消理由'), findsNothing);
      expect(find.text('已取消'), findsWidgets);
    });
  });

  group('前景收到活動被刪除的推播', () {
    Future<void> pumpOpenedDetail(WidgetTester tester) async {
      installMockClient({
        '/api/events/1': _detail(isJoined: true),
        '/api/events/1/reminders': {'reminders': <dynamic>[]},
        '/api/me': _me(),
      });
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<bool>(
                  context,
                  EventDetailScreen.route<bool>(_eventId),
                ),
                child: const Text('開詳情'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開詳情'));
      await tester.pumpAndSettle();
    }

    testWidgets('就是這場活動：跳對話框說明，按確定後關閉詳情頁', (tester) async {
      await pumpOpenedDetail(tester);
      expect(find.text('我要參加'), findsNothing);
      expect(find.text('部落豐年祭'), findsWidgets);

      FcmService.dispatchEventDeleted(_eventId);
      await tester.pumpAndSettle();

      expect(find.text('活動已刪除'), findsOneWidget);
      expect(find.text('您參加的部落豐年祭已被發起人刪除。'), findsOneWidget);

      await tester.tap(find.text('確定'));
      await tester.pumpAndSettle();

      expect(find.text('開詳情'), findsOneWidget);
      expect(find.text('部落豐年祭'), findsNothing);
    });

    testWidgets('別場活動被刪除：詳情頁不受影響', (tester) async {
      await pumpOpenedDetail(tester);

      FcmService.dispatchEventDeleted(_eventId + 1);
      await tester.pumpAndSettle();

      expect(find.text('活動已刪除'), findsNothing);
      expect(find.text('部落豐年祭'), findsWidgets);
    });

    testWidgets('同一則推播重複送達只跳一次對話框', (tester) async {
      await pumpOpenedDetail(tester);

      FcmService.dispatchEventDeleted(_eventId);
      FcmService.dispatchEventDeleted(_eventId);
      await tester.pumpAndSettle();

      expect(find.text('活動已刪除'), findsOneWidget);
    });

    testWidgets('詳情頁上面還蓋著別的頁面：只移除詳情頁，上面的頁面留著', (tester) async {
      await pumpOpenedDetail(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('上層頁面')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      FcmService.dispatchEventDeleted(_eventId);
      await tester.pumpAndSettle();
      await tester.tap(find.text('確定'));
      await tester.pumpAndSettle();

      expect(find.text('上層頁面'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('開詳情'), findsOneWidget);
      expect(find.text('部落豐年祭'), findsNothing);
    });
  });

  group('發起人刪除活動', () {
    Future<void> deleteAs(WidgetTester tester, Object? deleteBody) async {
      final farFuture = {
        ..._detail(isHost: true),
        'starts_at': '2099-12-01T10:00:00Z',
      };
      ApiClient.httpClient = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'DELETE' && path == '/api/events/1') {
          return deleteBody is http.Response
              ? deleteBody
              : jsonResponse(deleteBody);
        }
        return switch (path) {
          '/api/events/1' => jsonResponse(farFuture),
          '/api/events/1/reminders' => jsonResponse({'reminders': <dynamic>[]}),
          '/api/me' => jsonResponse(_me()),
          _ => fail('沒有準備 ${request.method} $path'),
        };
      });
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<bool>(
                  context,
                  EventDetailScreen.route<bool>(_eventId),
                ),
                child: const Text('開詳情'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開詳情'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('刪除活動'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('刪除活動'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();
    }

    testWidgets('後端通知了報名者：提示人數並回到上一頁', (tester) async {
      await deleteAs(tester, {'success': true, 'notified': 3});

      expect(find.text('活動已刪除，已通知 3 位報名者'), findsOneWidget);
      expect(find.text('開詳情'), findsOneWidget);
    });

    testWidgets('沒有人報名：只提示活動已刪除', (tester) async {
      await deleteAs(tester, {'success': true, 'notified': 0});

      expect(find.text('活動已刪除'), findsOneWidget);
      expect(find.textContaining('已通知'), findsNothing);
      expect(find.text('開詳情'), findsOneWidget);
    });

    testWidgets('刪除失敗：顯示後端訊息、留在詳情頁', (tester) async {
      await deleteAs(
        tester,
        errorResponse('EVENT_STARTED', status: 409, message: '活動已開始，無法刪除'),
      );

      expect(find.text('活動已開始，無法刪除'), findsOneWidget);
      expect(find.text('活動已刪除'), findsNothing);
      expect(find.text('開詳情'), findsNothing);
    });
  });
}
