// EventsScreen（活動列表）的畫面層測試。
//
// 這支取代的人工測試：進活動頁看列表有沒有出來、篩選列是不是跟著後端分類表、
// 切分類有沒有帶 category 從第一頁重查、往下捲有沒有帶游標翻頁、
// 沒有發起權限的帳號發起鈕是不是真的按不動、後端掛掉時有沒有錯誤畫面與重試。
// 人工要驗「非 organizer 看不到發起」還得換帳號登入，特別麻煩；
// 「分類被刪光後切回全部」更是要請管理員改後台才看得到。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/events/events_screen.dart';
import 'package:flutter_application_1/screens/events/widgets/event_cards.dart';
import 'package:flutter_application_1/screens/events/widgets/event_cover.dart';
import 'package:flutter_application_1/services/account_lock_controller.dart';
import 'package:flutter_application_1/services/category_service.dart';
import 'package:flutter_application_1/services/event_service.dart';
import 'package:flutter_application_1/services/notification_summary_service.dart';
import 'package:flutter_application_1/services/user_service.dart';
import 'package:flutter_application_1/shared/widgets/async_state_view.dart';
import 'package:flutter_application_1/shared/widgets/module_header_actions.dart';
import 'package:flutter_application_1/shared/widgets/truku_empty_state.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _event({
  int id = 1,
  String title = '部落豐年祭',
  String category = '其他',
}) => {
  'id': id,
  'title': title,
  'starts_at': '2026-12-01T10:00:00Z',
  'category': category,
  'status': 'active',
  'effective_status': 'active',
  'registration_open': true,
};

Map<String, dynamic> _me({String role = 'user'}) => {
  'uid': 1,
  'created_at': '2026-01-01T00:00:00Z',
  'role': role,
};

Map<String, dynamic> _cat(String value, int count, {int sort = 10}) => {
  'value': value,
  'label': value,
  'sort_order': sort,
  'count': count,
};

/// 預設的分類清單：族語、走讀有活動，工藝沒有。
final _defaultCategories = {
  'categories': [
    _cat('族語', 2, sort: 10),
    _cat('走讀', 1, sort: 20),
    _cat('工藝', 0, sort: 30),
  ],
};

Map<String, Object?> _routes({
  Object? events,
  Object? categories,
  String role = 'user',
}) => {
  '/api/events':
      events ??
      {
        'events': [_event()],
      },
  '/api/me': _me(role: role),
  '/api/events/categories': categories ?? _defaultCategories,
};

/// 依 query 回不同活動列表的假後端；記下每次 /api/events 的 query。
class _Backend {
  _Backend({required this.events, Object? categories})
    : categories = categories ?? _defaultCategories;

  /// 依 category、cursor 決定回應。
  Object? Function(Map<String, String> query) events;
  Object? categories;
  final eventQueries = <Map<String, String>>[];
  var categoryCalls = 0;

  void install() {
    ApiClient.httpClient = MockClient((r) async {
      final Object? body = switch (r.url.path) {
        '/api/events' => () {
          eventQueries.add(r.url.queryParameters);
          return events(r.url.queryParameters);
        }(),
        '/api/events/categories' => () {
          categoryCalls++;
          return categories;
        }(),
        '/api/me' => _me(),
        // 活動詳情（id 1）與它載入時要的資料、詳情上的按讚。
        '/api/events/1' => {
          ..._event(),
          'description': '說明',
          'like_count': 0,
          'is_liked': false,
        },
        '/api/events/1/reminders' => {'reminders': <dynamic>[]},
        '/api/events/1/like' => {'liked': true, 'like_count': 1},
        '/api/shop/items' => {'items': <dynamic>[]},
        // 用來觸發 EventService.eventsChanged。
        '/api/events/9/cancel' => <String, dynamic>{},
        _ => fail('沒準備 ${r.url.path}'),
      };
      return body is http.Response ? body : jsonResponse(body);
    });
  }
}

Widget _app() => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: const Scaffold(body: EventsScreen()),
);

/// 篩選列上的 chip 文字（依畫面順序）。
List<String> _chipLabels(WidgetTester tester) {
  final list = find.byWidgetPredicate(
    (w) => w is ListView && w.scrollDirection == Axis.horizontal,
  );
  return tester
      .widgetList<Text>(find.descendant(of: list, matching: find.byType(Text)))
      .map((t) => t.data!)
      .toList();
}

Finder _chip(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is ListView && w.scrollDirection == Axis.horizontal,
  ),
  matching: find.text(label),
);

Future<void> _pullToRefresh(WidgetTester tester) async {
  tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    accountLockController.setLocked(false);
    UserService.clearCache();
    NotificationSummaryService.clear();
    CategoryService.reset();
  });

  tearDown(() {
    restoreHttp();
    accountLockController.setLocked(false);
    UserService.clearCache();
    NotificationSummaryService.clear();
    CategoryService.reset();
  });

  testWidgets('載入失敗顯示錯誤畫面，重試會再打一次 API', (tester) async {
    var calls = 0;
    installMockClient(
      _routes(events: errorResponse('SERVER_ERROR', status: 500)),
      onRequest: (req) {
        if (req.url.path == '/api/events') calls++;
      },
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(TrukuErrorView), findsOneWidget);
    expect(calls, 1);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(calls, 2);
  });

  group('分類篩選列', () {
    testWidgets('「全部」在最前，其後照後端順序只列有活動的分類；列表不帶 scope 與 category', (
      tester,
    ) async {
      final backend = _Backend(
        events: (_) => {
          'events': [_event()],
        },
      )..install();

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(_chipLabels(tester), ['全部', '族語', '走讀']);
      expect(backend.eventQueries, [
        {'limit': '20'},
      ]);
    });

    testWidgets('點分類帶 category 從第一頁重查，畫面換成後端回的結果', (tester) async {
      final backend = _Backend(
        events: (q) => q['category'] == '族語'
            ? {
                'events': [_event(id: 2, title: '族語共學', category: '族語')],
              }
            : {
                'events': [_event(title: '陶藝工作坊', category: '工藝')],
              },
      )..install();

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('陶藝工作坊'), findsWidgets);

      await tester.tap(_chip('族語'));
      await tester.pumpAndSettle();

      expect(backend.eventQueries.last, {'category': '族語', 'limit': '20'});
      expect(find.text('族語共學'), findsWidgets);
      expect(find.text('陶藝工作坊'), findsNothing);

      await tester.tap(_chip('全部'));
      await tester.pumpAndSettle();
      expect(backend.eventQueries.last, {'limit': '20'});
    });

    testWidgets('選了分類後翻下一頁，連同 cursor 一起帶 category', (tester) async {
      final backend = _Backend(
        events: (q) => q['cursor'] == null
            ? {
                'events': [_event(id: 1, title: '第一頁', category: '族語')],
                'page_info': {'next_cursor': '20', 'has_more': true},
              }
            : {
                'events': [_event(id: 2, title: '第二頁', category: '族語')],
                'page_info': {'next_cursor': null, 'has_more': false},
              },
      )..install();

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(_chip('族語'));
      await tester.pumpAndSettle();

      // 一頁填不滿畫面時 PagerScrollLoader 會自己接著翻頁。
      expect(
        backend.eventQueries,
        containsAllInOrder([
          {'category': '族語', 'limit': '20'},
          {'category': '族語', 'cursor': '20', 'limit': '20'},
        ]),
      );
      expect(find.text('第二頁'), findsWidgets);
    });

    testWidgets('分類清單載入失敗時只顯示「全部」，列表照常', (tester) async {
      _Backend(
        events: (_) => {
          'events': [_event(title: '族語共學')],
        },
        categories: errorResponse('SERVER_ERROR', status: 500),
      ).install();

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(_chipLabels(tester), ['全部']);
      expect(find.text('族語共學'), findsWidgets);
    });

    testWidgets('下拉重整後選中的分類已經沒有活動：切回「全部」重載', (tester) async {
      final backend = _Backend(
        events: (_) => {
          'events': [_event()],
        },
      )..install();

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(_chip('走讀'));
      await tester.pumpAndSettle();
      expect(backend.eventQueries.last['category'], '走讀');

      backend.categories = {
        'categories': [_cat('族語', 2), _cat('走讀', 0, sort: 20)],
      };
      await _pullToRefresh(tester);

      expect(_chipLabels(tester), ['全部', '族語']);
      expect(backend.eventQueries.last, {'limit': '20'});
    });

    testWidgets('下拉重整時分類清單重抓失敗：保留原本的篩選列與選擇', (tester) async {
      final backend = _Backend(
        events: (_) => {
          'events': [_event()],
        },
      )..install();

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(_chip('走讀'));
      await tester.pumpAndSettle();

      backend.categories = errorResponse('SERVER_ERROR', status: 500);
      await _pullToRefresh(tester);

      expect(_chipLabels(tester), ['全部', '族語', '走讀']);
      expect(backend.eventQueries.last, {'category': '走讀', 'limit': '20'});
    });

    testWidgets('選了分類卻沒有活動時顯示空狀態', (tester) async {
      _Backend(
        events: (q) => q['category'] == null
            ? {
                'events': [_event()],
              }
            : {'events': <dynamic>[]},
      ).install();

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(_chip('族語'));
      await tester.pumpAndSettle();

      expect(find.byType(TrukuEmptyState), findsOneWidget);
    });
  });

  group('從詳情返回', () {
    testWidgets('只看不改就返回：不重載', (tester) async {
      final backend = _Backend(
        events: (_) => {
          'events': [_event()],
        },
      )..install();

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(EventFeaturedCard));
      await pumpFrames(tester, times: 10);
      await tester.binding.handlePopRoute();
      await pumpFrames(tester, times: 10);

      expect(backend.eventQueries, hasLength(1));
      expect(find.text('部落豐年祭'), findsWidgets);
    });

    testWidgets('在詳情按讚後返回：安靜重抓，不閃載入畫面', (tester) async {
      var round = 0;
      final backend = _Backend(
        events: (_) => {
          'events': [_event(title: '第 $round 次')],
        },
      )..install();

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(EventFeaturedCard));
      await pumpFrames(tester, times: 10);
      await tester.tap(find.byIcon(Icons.favorite_border));
      await pumpFrames(tester);

      round = 1;
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump();
      expect(find.byType(TrukuLoadingView), findsNothing);
      await pumpFrames(tester, times: 10);

      expect(backend.eventQueries, hasLength(2));
      expect(find.text('第 1 次'), findsWidgets);
    });
  });

  group('活動有異動（eventsChanged）', () {
    testWidgets('列表與分類一起重抓，剛有活動的分類出現在篩選列', (tester) async {
      var round = 0;
      final backend = _Backend(
        events: (_) => {
          'events': [_event(title: '第 $round 次')],
        },
      )..install();

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(_chipLabels(tester), ['全部', '族語', '走讀']);

      // 例如管理員發起時新增了「祭儀」分類，或原本沒有活動的工藝有了活動。
      round = 1;
      backend.categories = {
        'categories': [
          _cat('族語', 2, sort: 10),
          _cat('走讀', 1, sort: 20),
          _cat('工藝', 1, sort: 30),
          _cat('祭儀', 1, sort: 40),
        ],
      };
      await EventService.cancelEvent(9, '下雨');
      await tester.pump();
      expect(find.byType(TrukuLoadingView), findsNothing);
      await tester.pumpAndSettle();

      expect(backend.categoryCalls, 2);
      expect(backend.eventQueries, hasLength(2));
      expect(_chipLabels(tester), ['全部', '族語', '走讀', '工藝', '祭儀']);
      expect(find.text('第 1 次'), findsWidgets);
    });

    testWidgets('選中的分類變成沒有活動：切回「全部」', (tester) async {
      final backend = _Backend(
        events: (_) => {
          'events': [_event()],
        },
      )..install();

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(_chip('走讀'));
      await tester.pumpAndSettle();

      backend.categories = {
        'categories': [_cat('族語', 2), _cat('走讀', 0, sort: 20)],
      };
      await EventService.cancelEvent(9, '下雨');
      await tester.pumpAndSettle();

      expect(_chipLabels(tester), ['全部', '族語']);
      expect(backend.eventQueries.last, {'limit': '20'});
    });

    testWidgets('分類重抓失敗：保留原本的篩選列與選擇', (tester) async {
      final backend = _Backend(
        events: (_) => {
          'events': [_event()],
        },
      )..install();

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(_chip('走讀'));
      await tester.pumpAndSettle();

      backend.categories = errorResponse('SERVER_ERROR', status: 500);
      await EventService.cancelEvent(9, '下雨');
      await tester.pumpAndSettle();

      expect(_chipLabels(tester), ['全部', '族語', '走讀']);
      expect(backend.eventQueries.last, {'category': '走讀', 'limit': '20'});
    });

    testWidgets('列表停在錯誤畫面時：重新載入並清掉錯誤', (tester) async {
      var failing = true;
      final backend = _Backend(
        events: (_) => failing
            ? errorResponse('SERVER_ERROR', status: 500)
            : {
                'events': [_event()],
              },
      )..install();

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byType(TrukuErrorView), findsOneWidget);

      failing = false;
      await EventService.cancelEvent(9, '下雨');
      await tester.pumpAndSettle();

      expect(backend.eventQueries, hasLength(2));
      expect(find.byType(TrukuErrorView), findsNothing);
      expect(find.text('部落豐年祭'), findsWidgets);
    });

    testWidgets('離開畫面後不再回應', (tester) async {
      final backend = _Backend(
        events: (_) => {
          'events': [_event()],
        },
      )..install();

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      await EventService.cancelEvent(9, '下雨');
      await tester.pumpAndSettle();

      expect(backend.eventQueries, hasLength(1));
      expect(backend.categoryCalls, 1);
    });
  });

  testWidgets('封面網址過期：安靜重抓第一頁換掉清單，不閃載入畫面', (tester) async {
    var round = 0;
    final backend = _Backend(
      events: (_) => {
        'events': [_event(title: '第 $round 次')],
      },
    )..install();

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('第 0 次'), findsWidgets);

    round = 1;
    const EventCoverExpiredNotification().dispatch(
      tester.element(find.byType(EventFeaturedCard)),
    );
    await tester.pump();
    expect(find.byType(TrukuLoadingView), findsNothing);
    await tester.pumpAndSettle();

    expect(backend.eventQueries, hasLength(2));
    expect(find.text('第 1 次'), findsWidgets);
  });

  testWidgets('一般使用者的發起鈕停用（沒有 organizer 權限）', (tester) async {
    installMockClient(_routes(role: 'user'));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ModuleComposeButton>(find.byType(ModuleComposeButton))
          .enabled,
      isFalse,
    );
  });

  testWidgets('organizer 的發起鈕啟用', (tester) async {
    installMockClient(_routes(role: 'organizer'));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ModuleComposeButton>(find.byType(ModuleComposeButton))
          .enabled,
      isTrue,
    );
  });

  testWidgets('角色被改掉（userNotifier 更新）時發起鈕不重開頁面就跟著變', (tester) async {
    installMockClient(_routes(role: 'organizer'));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    bool enabled() => tester
        .widget<ModuleComposeButton>(find.byType(ModuleComposeButton))
        .enabled;
    expect(enabled(), isTrue);

    installMockClient({'/api/me': _me(role: 'user')});
    await UserService.fetchMe(forceRefresh: true);
    await tester.pump();
    expect(enabled(), isFalse);
  });

  testWidgets('查不到身分時保守擋下發起（不能因為 API 失敗就放行）', (tester) async {
    installMockClient({
      ..._routes(),
      '/api/me': errorResponse('SERVER_ERROR', status: 500),
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ModuleComposeButton>(find.byType(ModuleComposeButton))
          .enabled,
      isFalse,
    );
  });

  testWidgets('唯讀模式下 organizer 按發起會被擋並顯示提示', (tester) async {
    installMockClient(_routes(role: 'organizer'));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    accountLockController.setLocked(true);
    await tester.tap(find.byType(ModuleComposeButton));
    await tester.pump();

    expect(find.text(readOnlyMessage), findsOneWidget);
  });
}
