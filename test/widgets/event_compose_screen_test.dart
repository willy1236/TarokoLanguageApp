// EventComposeScreen（發起／編輯活動表單）的畫面層測試。
//
// 這裡不重測欄位驗證規則——那是 EventDraft.validate 的職責，
// 已由 test/models/event_draft_test.dart 覆蓋。這支只測「畫面怎麼反應」：
// 驗證不過時有沒有顯示錯誤而且不打 API、成功後有沒有回傳 true 讓列表刷新、
// 編輯途中活動被取消／已開始時會不會把使用者留在存不了的表單裡。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/event_model.dart';
import 'package:flutter_application_1/screens/events/event_compose_screen.dart';

import '../helpers/widget_test_helpers.dart';

/// 編輯模式會用既有活動預填表單，省去在測試裡操作日期／時間選擇器。
EventDetail _editing() => EventDetail(
  id: 1,
  hostUid: 100,
  title: '部落豐年祭',
  description: '一起來跳舞',
  startsAt: DateTime.now().add(const Duration(days: 30)),
  location: '花蓮縣秀林鄉',
  address: '秀林鄉中正路 1 號',
  status: 'active',
  effectiveStatus: 'active',
  registrationOpen: true,
);

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

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  testWidgets('新建表單必填未填時顯示錯誤且不打 API', (tester) async {
    var calls = 0;
    installMockClient({
      '/api/events': <String, dynamic>{},
    }, onRequest: (_) => calls++);

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
    expect(find.text('秀林鄉中正路 1 號'), findsWidgets);
    expect(find.textContaining('需要調整時間，請取消這場活動後重新發起'), findsOneWidget);
  });

  testWidgets('編輯儲存成功後回傳 true 讓呼叫端刷新', (tester) async {
    Object? popped;
    installMockClient({'/api/events/1': <String, dynamic>{}});

    await tester.pumpWidget(
      _host(editing: _editing(), onPop: (r) => popped = r),
    );
    await _openForm(tester);

    await tester.enterText(find.text('部落豐年祭').first, '部落豐年祭（改期）');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
  });

  testWidgets('沒有發起權限時顯示後端錯誤，留在表單', (tester) async {
    Object? popped;
    installMockClient({
      '/api/events/1': errorResponse(
        'FORBIDDEN',
        status: 403,
        message: '需要活動主辦權限（organizer / admin）',
      ),
    });

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
    installMockClient({
      '/api/events/1': errorResponse('EVENT_CLOSED', status: 409),
    });

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
    installMockClient({
      '/api/events/1': errorResponse('EVENT_ENDED', status: 409),
    });

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
}
