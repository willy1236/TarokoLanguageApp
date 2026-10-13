// EventComposeScreen（發起／編輯活動表單）的畫面層測試。
//
// 這裡不重測欄位驗證規則——那是 EventDraft.validate 的職責，
// 已由 test/models/event_draft_test.dart 覆蓋。這支只測「畫面怎麼反應」：
// 驗證不過時有沒有顯示錯誤而且不打 API、成功後有沒有回傳 true 讓列表刷新、
// 編輯途中活動被取消／已開始時會不會把使用者留在存不了的表單裡、
// 分類清單跟著後端（含載入失敗擋下送出）、管理員可以直接新增分類。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/models/event_model.dart';
import 'package:flutter_application_1/screens/events/event_compose_screen.dart';
import 'package:flutter_application_1/services/category_service.dart';
import 'package:flutter_application_1/services/user_service.dart';
import 'package:flutter_application_1/shared/widgets/related_tribe_field.dart';

import '../helpers/widget_test_helpers.dart';

/// 編輯模式會用既有活動預填表單，省去在測試裡操作日期／時間選擇器。
EventDetail _editing({String category = '族語'}) => EventDetail(
  id: 1,
  title: '部落豐年祭',
  description: '一起來跳舞',
  startsAt: DateTime.now().add(const Duration(days: 30)),
  location: '花蓮縣秀林鄉',
  address: '秀林鄉中正路 1 號',
  category: category,
  status: 'active',
  effectiveStatus: 'active',
  registrationOpen: true,
);

const _categoriesPath = '/api/events/categories';

/// 後端分類清單：工藝目前沒有活動（count 0），發起時仍要列出來。
final _categories = {
  'categories': [
    {'value': '族語', 'label': '族語', 'sort_order': 10, 'count': 2},
    {'value': '工藝', 'label': '工藝', 'sort_order': 30, 'count': 0},
    {'value': '其他', 'label': '其他', 'sort_order': 1000, 'count': 1},
    // 顯示名稱與 value 不同的分類，測管理員輸入名稱時對回既有分類。
    {'value': 'culture', 'label': '文化', 'sort_order': 1100, 'count': 0},
  ],
};

/// 各測試的路由一律帶上分類清單。
Map<String, Object?> _routes([Map<String, Object?> extra = const {}]) => {
  _categoriesPath: _categories,
  ...extra,
};

/// 分類 chip（表單上顯示為「# 名稱」）。
Finder _categoryChip(String label) => find.text('# $label');

/// 分類區塊在表單中段，ListView 沒捲到不會建出來；捲到它下方的相關部落欄位為止。
Future<void> _scrollToCategories(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byType(RelatedTribeField),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// 選中的 chip 底色是主色。
bool _chipSelected(WidgetTester tester, String label) {
  final box = tester.widget<Container>(
    find
        .ancestor(of: _categoryChip(label), matching: find.byType(Container))
        .first,
  );
  return (box.decoration as BoxDecoration).color == AppColors.primary;
}

/// 用一顆按鈕把表單 push 起來，才能接到 Navigator.pop 的回傳值。
Widget _host({
  required EventDetail? editing,
  required void Function(Object?) onPop,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<Object?>(
                MaterialPageRoute(
                  builder: (_) => EventComposeScreen(editing: editing),
                ),
              );
              onPop(result);
            },
            child: const Text('OPEN'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
}

/// 送出失敗的錯誤走 SnackBar，不捲動也該看得到。
/// 這個斷言本身就是在守「錯誤訊息不會被藏在表單最底下」這件事：
/// 若哪天有人把它改回 inline 渲染，這裡會因為沒有 SnackBar 而變紅。
Finder _errorSnackBar(String contains) => find.descendant(
  of: find.byType(SnackBar),
  matching: find.textContaining(contains),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    CategoryService.reset();
    installMockClient(_routes());
  });
  tearDown(() {
    restoreHttp();
    CategoryService.reset();
    UserService.clearCache();
  });

  testWidgets('新建表單必填未填時顯示錯誤且不打 API', (tester) async {
    var calls = 0;
    installMockClient(
      _routes({'/api/events': <String, dynamic>{}}),
      onRequest: (r) {
        if (r.url.path != _categoriesPath) calls++;
      },
    );

    await tester.pumpWidget(_host(editing: null, onPop: (_) {}));
    await _openForm(tester);

    expect(find.text('新發布'), findsOneWidget);
    await tester.tap(find.text('發布'));
    await tester.pumpAndSettle();

    expect(calls, 0, reason: '驗證不過就不該送出');
    // 錯誤訊息的內容由 EventDraft.validate 決定，這裡只確認有顯示給使用者看。
    expect(_errorSnackBar('請填寫所有必填欄位'), findsOneWidget);
  });

  testWidgets('編輯模式預填既有內容，時間欄位標示不可改', (tester) async {
    await tester.pumpWidget(_host(editing: _editing(), onPop: (_) {}));
    await _openForm(tester);

    expect(find.text('編輯活動'), findsOneWidget);
    expect(find.text('部落豐年祭'), findsWidgets);
    // 舊活動地點與地址分開填、互不包含：合成一欄時兩邊都留著。
    const merged = '花蓮縣秀林鄉 秀林鄉中正路 1 號';
    await tester.scrollUntilVisible(
      find.text(merged),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(merged), findsOneWidget);
    expect(find.textContaining('需要調整時間，請取消這場活動後重新發起'), findsOneWidget);
  });

  testWidgets('編輯儲存成功後回傳 true 讓呼叫端刷新', (tester) async {
    Object? popped;
    installMockClient(_routes({'/api/events/1': <String, dynamic>{}}));

    await tester.pumpWidget(
      _host(editing: _editing(), onPop: (r) => popped = r),
    );
    await _openForm(tester);

    await tester.enterText(find.text('部落豐年祭').first, '部落豐年祭（改期）');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
  });

  group('編輯後的參加者通知提示', () {
    Future<void> saveEdit(WidgetTester tester, Object? response) async {
      installMockClient(_routes({'/api/events/1': response}));
      await tester.pumpWidget(_host(editing: _editing(), onPop: (_) {}));
      await _openForm(tester);
      await tester.enterText(find.text('部落豐年祭').first, '部落豐年祭（改地點）');
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();
    }

    testWidgets('通知次數達上限：提示參加者不會再收到推播', (tester) async {
      await saveEdit(tester, {
        'ok': true,
        'notified': 0,
        'notify_limited': true,
      });

      expect(find.text('活動已更新，今天通知次數已達上限，參加者不會再收到推播'), findsOneWidget);
      // 發起人得讀完才知道要另外通知參加者，停留時間同部落推播提示。
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 8),
      );
    });

    testWidgets('沒有 notify_limited：只提示活動已更新', (tester) async {
      await saveEdit(tester, {'ok': true, 'notified': 0});

      expect(find.text('活動已更新'), findsOneWidget);
    });
  });

  testWidgets('有地圖座標的活動：手動改地址後提示，儲存時清除座標', (tester) async {
    Map<String, dynamic>? sent;
    installMockClient(
      _routes({'/api/events/1': <String, dynamic>{}}),
      onRequest: (r) {
        if (r.method == 'PATCH') sent = jsonDecode(r.body);
      },
    );
    final e = EventDetail(
      id: 1,
      title: '部落豐年祭',
      description: '一起來跳舞',
      startsAt: DateTime.now().add(const Duration(days: 30)),
      location: '富世部落活動中心',
      address: '花蓮縣秀林鄉富世村 12 號',
      latitude: 24.15,
      longitude: 121.62,
      category: '族語',
      status: 'active',
      effectiveStatus: 'active',
    );

    await tester.pumpWidget(_host(editing: e, onPop: (_) {}));
    await _openForm(tester);
    expect(find.text('已在地圖上定位'), findsOneWidget);

    await tester.enterText(find.text('花蓮縣秀林鄉富世村 12 號'), '花蓮縣秀林鄉富世村 13 號');
    await tester.pump();
    expect(find.text('已在地圖上定位'), findsNothing);
    expect(find.text('已改為手動地址，可重新在地圖上選擇'), findsOneWidget);

    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();
    expect(sent, {
      'location': null,
      'address': '花蓮縣秀林鄉富世村 13 號',
      'latitude': null,
      'longitude': null,
    });
  });

  testWidgets('沒有發起權限時顯示後端錯誤，留在表單', (tester) async {
    Object? popped;
    installMockClient(
      _routes({
        '/api/events/1': errorResponse(
          'FORBIDDEN',
          status: 403,
          message: '需要活動主辦權限（organizer / admin）',
        ),
      }),
    );

    await tester.pumpWidget(
      _host(editing: _editing(), onPop: (r) => popped = r),
    );
    await _openForm(tester);

    await tester.enterText(find.text('部落豐年祭').first, '改個名字');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    expect(popped, isNull, reason: '失敗不該關閉表單');
    expect(_errorSnackBar('需要活動主辦權限'), findsOneWidget);
  });

  testWidgets('編輯途中活動已被取消時退回上一頁，不讓使用者卡在存不了的表單', (tester) async {
    Object? popped;
    installMockClient(
      _routes({'/api/events/1': errorResponse('EVENT_CLOSED', status: 409)}),
    );

    await tester.pumpWidget(
      _host(editing: _editing(), onPop: (r) => popped = r),
    );
    await _openForm(tester);

    await tester.enterText(find.text('部落豐年祭').first, '改個名字');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    expect(popped, isTrue, reason: '要回傳 true 讓詳情頁刷新成最新狀態');
    expect(find.text('活動已取消，無法修改'), findsOneWidget);
  });

  testWidgets('編輯途中活動已開始時同樣退回上一頁', (tester) async {
    Object? popped;
    installMockClient(
      _routes({'/api/events/1': errorResponse('EVENT_ENDED', status: 409)}),
    );

    await tester.pumpWidget(
      _host(editing: _editing(), onPop: (r) => popped = r),
    );
    await _openForm(tester);

    await tester.enterText(find.text('部落豐年祭').first, '改個名字');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    expect(find.text('活動已開始，無法修改'), findsOneWidget);
  });

  group('送出中不能返回', () {
    // 讓儲存請求晚點回應，模擬「還在轉圈」的那段時間。
    const slow = Duration(seconds: 2);

    ModalRoute<dynamic> formRoute(WidgetTester tester) =>
        ModalRoute.of(tester.element(find.byType(EventComposeScreen)))!;

    Future<void> startSaving(WidgetTester tester) async {
      await tester.enterText(find.text('部落豐年祭').first, '部落豐年祭（改期）');
      await tester.tap(find.text('儲存'));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('系統返回鍵、手勢與返回鈕都留在表單，送完照常帶 true 返回', (tester) async {
      Object? popped;
      var returned = false;
      installMockClient(
        _routes({'/api/events/1': <String, dynamic>{}}),
        delayFor: (r) => r.method == 'PATCH' ? slow : Duration.zero,
      );

      await tester.pumpWidget(
        _host(
          editing: _editing(),
          onPop: (r) {
            returned = true;
            popped = r;
          },
        ),
      );
      await _openForm(tester);
      expect(formRoute(tester).popGestureEnabled, isTrue);

      await startSaving(tester);

      // iOS 滑動返回與 Android 預測式返回都看這個旗標。
      expect(formRoute(tester).popGestureEnabled, isFalse);

      await tester.binding.handlePopRoute(); // 系統返回鍵
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byTooltip('返回')); // AppBackButton
      await tester.pump(const Duration(milliseconds: 100));

      expect(returned, isFalse);
      expect(find.text('編輯活動'), findsOneWidget);

      await tester.pump(slow);
      await tester.pumpAndSettle();

      expect(returned, isTrue);
      expect(popped, isTrue, reason: '送出成功照常帶結果返回，列表會刷新');
    });

    testWidgets('送出失敗後恢復可以返回', (tester) async {
      var returned = false;
      installMockClient(
        _routes({
          '/api/events/1': errorResponse(
            'FORBIDDEN',
            status: 403,
            message: '需要活動主辦權限（organizer / admin）',
          ),
        }),
        delayFor: (r) => r.method == 'PATCH' ? slow : Duration.zero,
      );

      await tester.pumpWidget(
        _host(editing: _editing(), onPop: (_) => returned = true),
      );
      await _openForm(tester);

      await startSaving(tester);
      expect(formRoute(tester).popGestureEnabled, isFalse);
      await tester.pump(slow);
      await tester.pumpAndSettle();

      expect(returned, isFalse, reason: '失敗不會自己關掉表單');
      expect(formRoute(tester).popGestureEnabled, isTrue);

      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(find.text('OPEN'), findsOneWidget);
    });
  });

  group('分類', () {
    testWidgets('發起時列出後端全部分類（含目前沒有活動的）', (tester) async {
      await tester.pumpWidget(_host(editing: null, onPop: (_) {}));
      await _openForm(tester);
      await _scrollToCategories(tester);

      for (final label in ['族語', '工藝', '其他']) {
        expect(_categoryChip(label), findsOneWidget);
      }
      expect(_categoryChip('走讀'), findsNothing, reason: '不再寫死前端清單');
    });

    testWidgets('點已選的分類不會取消選取', (tester) async {
      await tester.pumpWidget(_host(editing: null, onPop: (_) {}));
      await _openForm(tester);
      await _scrollToCategories(tester);

      await tester.ensureVisible(_categoryChip('工藝'));
      await tester.tap(_categoryChip('工藝'));
      await tester.pump();
      expect(_chipSelected(tester, '工藝'), isTrue);

      await tester.tap(_categoryChip('工藝'));
      await tester.pump();
      expect(_chipSelected(tester, '工藝'), isTrue);
    });

    testWidgets('沒選分類就送出：提示選分類且不打 API', (tester) async {
      var calls = 0;
      installMockClient(
        _routes({'/api/events': <String, dynamic>{}}),
        onRequest: (r) {
          if (r.url.path != _categoriesPath) calls++;
        },
      );
      await tester.pumpWidget(_host(editing: null, onPop: (_) {}));
      await _openForm(tester);

      // 名稱、說明、地址都填了，只差分類。
      Future<void> fill(String hint, String text) async {
        final field = find.widgetWithText(TextField, hint);
        await tester.scrollUntilVisible(
          field,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(field, text);
      }

      await fill('例如：青年族語營', '族語共學');
      await fill('門牌或描述，例如：秀林鄉富世村 12 號／部落活動中心', '秀林鄉富世村 12 號');
      await fill('介紹活動內容、流程、注意事項…', '一起學族語');
      await tester.pump();
      await tester.tap(find.text('發布'));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(_errorSnackBar('請選擇活動分類'), findsOneWidget);
    });

    testWidgets('分類清單載入失敗：顯示重試、擋下送出；重試成功後可選', (tester) async {
      var fail = true;
      installMockClient(
        {
          _categoriesPath: errorResponse('SERVER_ERROR', status: 500),
          '/api/events/1': <String, dynamic>{},
        },
        onRequest: (r) {
          if (r.method == 'PATCH') fail = false;
        },
      );

      await tester.pumpWidget(_host(editing: _editing(), onPop: (_) {}));
      await _openForm(tester);
      await tester.enterText(find.text('部落豐年祭').first, '部落豐年祭（改期）');
      await _scrollToCategories(tester);

      expect(find.text('分類載入失敗'), findsOneWidget);
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();
      expect(fail, isTrue, reason: '分類清單沒載入成功前不能送出');
      expect(_errorSnackBar('活動分類載入失敗'), findsOneWidget);

      installMockClient(_routes({'/api/events/1': <String, dynamic>{}}));
      await tester.ensureVisible(find.text('重試'));
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();

      expect(find.text('分類載入失敗'), findsNothing);
      expect(_categoryChip('工藝'), findsOneWidget);
      expect(_chipSelected(tester, '族語'), isTrue);
    });

    testWidgets('編輯時原分類不在清單：補一顆顯示為已選，沒改就不送 category', (tester) async {
      Map<String, dynamic>? sent;
      installMockClient(
        _routes({'/api/events/1': <String, dynamic>{}}),
        onRequest: (r) {
          if (r.method == 'PATCH') sent = jsonDecode(r.body);
        },
      );

      await tester.pumpWidget(
        _host(
          editing: _editing(category: '走讀'),
          onPop: (_) {},
        ),
      );
      await _openForm(tester);
      await tester.enterText(find.text('部落豐年祭').first, '部落豐年祭（改期）');
      await _scrollToCategories(tester);

      expect(_categoryChip('走讀'), findsOneWidget);
      expect(_chipSelected(tester, '走讀'), isTrue);

      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      expect(sent, {'title': '部落豐年祭（改期）'});
    });

    for (final (code, message) in [
      ('CATEGORY_REQUIRED', '請選擇活動分類'),
      ('INVALID_CATEGORY', '這個分類已停用，請改選其他分類'),
    ]) {
      testWidgets('後端回 400 $code：顯示後端訊息、留在表單', (tester) async {
        Object? popped;
        installMockClient(
          _routes({'/api/events/1': errorResponse(code, message: message)}),
        );

        await tester.pumpWidget(
          _host(editing: _editing(), onPop: (r) => popped = r),
        );
        await _openForm(tester);

        await tester.enterText(find.text('部落豐年祭').first, '改個名字');
        await tester.tap(find.text('儲存'));
        await tester.pumpAndSettle();

        expect(popped, isNull);
        expect(_errorSnackBar(message), findsOneWidget);
      });
    }
  });

  group('管理員新增分類', () {
    /// 以 [role] 登入（寫進 UserService 快取），並裝上記錄請求的假後端。
    Future<List<http.Request>> signIn(String role, {Object? save}) async {
      final requests = <http.Request>[];
      installMockClient(
        _routes({
          '/api/me': {
            'uid': 1,
            'created_at': '2026-01-01T00:00:00Z',
            'role': role,
          },
          '/api/events': jsonResponse({'id': 9}, status: 201),
          '/api/events/1': save ?? <String, dynamic>{},
        }),
        onRequest: requests.add,
      );
      await UserService.fetchMe(forceRefresh: true);
      requests.clear();
      return requests;
    }

    Future<void> addCategory(WidgetTester tester, String name) async {
      await tester.tap(find.text('＋新增'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        name,
      );
      await tester.pump();
      await tester.tap(find.text('確定'));
      await tester.pumpAndSettle();
    }

    int categoryFetches(List<http.Request> requests) =>
        requests.where((r) => r.url.path == _categoriesPath).length;

    Map<String, dynamic> bodyOf(List<http.Request> requests, String method) =>
        jsonDecode(requests.singleWhere((r) => r.method == method).body)
            as Map<String, dynamic>;

    testWidgets('organizer 看不到「＋新增」', (tester) async {
      await signIn('organizer');
      await tester.pumpWidget(_host(editing: null, onPop: (_) {}));
      await _openForm(tester);
      await _scrollToCategories(tester);

      expect(_categoryChip('族語'), findsOneWidget);
      expect(find.text('＋新增'), findsNothing);
    });

    testWidgets('編輯時輸入新分類：顯示為已選，儲存帶上它，成功後重抓分類清單', (tester) async {
      final requests = await signIn('admin');
      await tester.pumpWidget(_host(editing: _editing(), onPop: (_) {}));
      await _openForm(tester);
      await _scrollToCategories(tester);
      expect(categoryFetches(requests), 1);

      await addCategory(tester, '  射箭  ');

      expect(_chipSelected(tester, '射箭'), isTrue);
      expect(_chipSelected(tester, '族語'), isFalse);

      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      expect(bodyOf(requests, 'PATCH'), {'category': '射箭'});
      expect(categoryFetches(requests), 2, reason: '後端已加進分類表，重抓讓下次進發起頁看得到');
    });

    testWidgets('發起時輸入新分類：建立活動帶上它', (tester) async {
      final requests = await signIn('admin');
      await tester.pumpWidget(_host(editing: null, onPop: (_) {}));
      await _openForm(tester);

      Future<void> fill(String hint, String text) async {
        final field = find.widgetWithText(TextField, hint);
        await tester.scrollUntilVisible(
          field,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(field, text);
      }

      await fill('例如：青年族語營', '射箭體驗');
      await tester.scrollUntilVisible(
        find.text('選擇日期'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('選擇日期'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await fill('門牌或描述，例如：秀林鄉富世村 12 號／部落活動中心', '秀林鄉中正路 1 號');
      await fill('介紹活動內容、流程、注意事項…', '一起來射箭');
      await _scrollToCategories(tester);
      await addCategory(tester, '射箭');

      await tester.tap(find.text('發布'));
      await tester.pumpAndSettle();

      expect(bodyOf(requests, 'POST')['category'], '射箭');
      expect(categoryFetches(requests), 2);
    });

    testWidgets('輸入既有分類的名稱：直接選那個分類，不多一顆', (tester) async {
      final requests = await signIn('admin');
      await tester.pumpWidget(_host(editing: _editing(), onPop: (_) {}));
      await _openForm(tester);
      await _scrollToCategories(tester);

      await addCategory(tester, '文化');

      expect(_categoryChip('文化'), findsOneWidget);
      expect(_chipSelected(tester, '文化'), isTrue);

      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      expect(bodyOf(requests, 'PATCH'), {'category': 'culture'});
      expect(categoryFetches(requests), 1, reason: '沒有新增分類就不用重抓');
    });

    testWidgets('空白不能確定，超過 20 字打不進去（以 UTF-16 計）', (tester) async {
      await signIn('admin');
      await tester.pumpWidget(_host(editing: _editing(), onPop: (_) {}));
      await _openForm(tester);
      await _scrollToCategories(tester);

      await tester.tap(find.text('＋新增'));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      TextButton confirm() => tester.widget<TextButton>(
        find.ancestor(of: find.text('確定'), matching: find.byType(TextButton)),
      );

      expect(confirm().onPressed, isNull);
      await tester.enterText(field, '   ');
      await tester.pump();
      expect(confirm().onPressed, isNull);

      await tester.enterText(field, '射' * 25);
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, '射' * 20);

      await tester.enterText(field, '😀' * 11);
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, '😀' * 10);
      expect(confirm().onPressed, isNotNull);
    });

    testWidgets('新增後改選既有分類：新的那顆消失', (tester) async {
      await signIn('admin');
      await tester.pumpWidget(_host(editing: _editing(), onPop: (_) {}));
      await _openForm(tester);
      await _scrollToCategories(tester);

      await addCategory(tester, '射箭');
      expect(_categoryChip('射箭'), findsOneWidget);

      await tester.tap(_categoryChip('工藝'));
      await tester.pump();

      expect(_chipSelected(tester, '工藝'), isTrue);
      expect(_categoryChip('射箭'), findsNothing);
    });
  });
}
