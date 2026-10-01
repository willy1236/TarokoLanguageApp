// 發起／編輯活動表單的照片欄位：選的照片按發布／儲存才送出。
//
// 這支取代的人工測試：發起一場帶照片的活動、故意讓照片上傳失敗，看活動有沒有
// 照常建立、提示對不對——每試一次就在正式後端多一場活動。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/models/event_model.dart';
import 'package:flutter_application_1/screens/events/event_compose_screen.dart';
import 'package:flutter_application_1/screens/forum/widgets/forum_image_grid.dart';
import 'package:flutter_application_1/shared/utils/pick_images.dart';

import '../helpers/widget_test_helpers.dart';

const _createdId = 55;
const _uploadPath = '/api/events/$_createdId/images';

/// 用一顆按鈕把表單 push 起來，才能接到 Navigator.pop 的回傳值。
Widget _host({EventDetail? editing, required void Function(Object?) onPop}) =>
    MaterialApp(
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

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
}

/// 填好建立活動的五個必填欄位；日期時間用選擇器的預設值（明天、一小時後）。
Future<void> _fillRequired(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextField, '例如：青年族語營'), '豐年祭');
  await tester.enterText(find.widgetWithText(TextField, '例如：秀林部落活動中心'), '活動中心');
  await tester.tap(find.text('選擇日期'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await _enterBelow(tester, '例如：花蓮縣秀林鄉…', '秀林鄉中正路 1 號');
  await _enterBelow(tester, '介紹活動內容、流程、注意事項…', '一起來跳舞');
}

Future<void> _enterBelow(WidgetTester tester, String hint, String text) async {
  final field = find.widgetWithText(TextField, hint);
  await tester.scrollUntilVisible(
    field,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(field, text);
}

Future<void> _scrollToTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
  await tester.pumpAndSettle();
}

/// 換掉挑圖：記下要求的張數上限，每次回傳 [count] 張假 JPEG。
List<int> _fakePicker({int count = 2}) {
  final limits = <int>[];
  pickImagesForUpload = ({required int limit, required int maxBytes}) async {
    limits.add(limit);
    return (
      images: [for (var i = 0; i < count; i++) base64Decode(_pngBase64)],
      skippedNotice: null,
    );
  };
  return limits;
}

final _originalPicker = pickImagesForUpload;

/// 1x1 PNG：預覽縮圖要真的解得開。
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

Map<String, Object?> _created() => {'id': _createdId};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    restoreHttp();
    pickImagesForUpload = _originalPicker;
  });

  group('發起活動', () {
    testWidgets('原本的鎖頭封面換成照片欄位，選圖後顯示縮圖、第一張標封面、可點開預覽', (tester) async {
      final limits = _fakePicker(count: 2);
      await tester.pumpWidget(_host(onPop: (_) {}));
      await _openForm(tester);

      expect(find.text('活動封面（尚未開放）'), findsNothing);
      await tester.tap(find.text('新增照片'));
      await tester.pumpAndSettle();

      expect(limits, [6]);
      expect(find.text('2/6 張・第一張是封面'), findsOneWidget);
      expect(find.text('封面'), findsOneWidget);

      await tester.tap(find.text('新增照片'));
      await tester.pumpAndSettle();
      expect(limits, [6, 4]);
      expect(find.text('4/6 張・第一張是封面'), findsOneWidget);

      await tester.tap(find.byTooltip('移除這張照片').first);
      await tester.pumpAndSettle();
      expect(find.text('3/6 張・第一張是封面'), findsOneWidget);

      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();
      expect(find.byType(ForumImageViewer), findsOneWidget);
    });

    testWidgets('沒選圖：只建立活動，流程與原本相同', (tester) async {
      Object? popped;
      final paths = <String>[];
      installMockClient({
        '/api/events': jsonResponse(_created(), status: 201),
      }, onRequest: (r) => paths.add(r.url.path));
      await tester.pumpWidget(_host(onPop: (r) => popped = r));
      await _openForm(tester);
      await _fillRequired(tester);

      await tester.tap(find.text('發布'));
      await tester.pumpAndSettle();

      expect(paths, ['/api/events']);
      expect(popped, isTrue);
      expect(find.text('活動已發起'), findsOneWidget);
    });

    testWidgets('有選圖：先建立活動、再把照片傳到新活動', (tester) async {
      _fakePicker(count: 2);
      Object? popped;
      final requests = <http.Request>[];
      installMockClient({
        '/api/events': jsonResponse(_created(), status: 201),
        _uploadPath: jsonResponse({
          'images': [
            {'id': 1, 'url': 'https://a/1.jpg'},
            {'id': 2, 'url': 'https://a/2.jpg'},
          ],
        }, status: 201),
      }, onRequest: requests.add);
      await tester.pumpWidget(_host(onPop: (r) => popped = r));
      await _openForm(tester);
      await tester.tap(find.text('新增照片'));
      await tester.pumpAndSettle();
      await _fillRequired(tester);

      await tester.tap(find.text('發布'));
      await tester.pumpAndSettle();

      expect(requests.map((r) => r.url.path), ['/api/events', _uploadPath]);
      expect(
        'name="images"'.allMatches(latin1.decode(requests[1].bodyBytes)).length,
        2,
      );
      expect(popped, isTrue);
      expect(find.text('活動已發起'), findsOneWidget);
    });

    testWidgets('活動建立了但照片上傳失敗：照常返回，提示稍後補上', (tester) async {
      _fakePicker(count: 1);
      Object? popped;
      installMockClient({
        '/api/events': jsonResponse(_created(), status: 201),
        _uploadPath: errorResponse('FILE_TOO_LARGE', message: '每張圖片上限 5MB'),
      });
      await tester.pumpWidget(_host(onPop: (r) => popped = r));
      await _openForm(tester);
      await tester.tap(find.text('新增照片'));
      await tester.pumpAndSettle();
      await _fillRequired(tester);

      await tester.tap(find.text('發布'));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(find.textContaining('活動已建立，圖片可以稍後在編輯頁補上'), findsOneWidget);
      expect(find.textContaining('每張圖片上限 5MB'), findsOneWidget);
    });

    testWidgets('活動建立失敗：不上傳照片、留在表單，已選的照片還在', (tester) async {
      _fakePicker(count: 2);
      Object? popped;
      final paths = <String>[];
      installMockClient({
        '/api/events': errorResponse(
          'FORBIDDEN',
          status: 403,
          message: '需要活動主辦權限（organizer / admin）',
        ),
      }, onRequest: (r) => paths.add(r.url.path));
      await tester.pumpWidget(_host(onPop: (r) => popped = r));
      await _openForm(tester);
      await tester.tap(find.text('新增照片'));
      await tester.pumpAndSettle();
      await _fillRequired(tester);

      await tester.tap(find.text('發布'));
      await tester.pumpAndSettle();

      expect(paths, ['/api/events']);
      expect(popped, isNull);
      await _scrollToTop(tester);
      expect(find.text('2/6 張・第一張是封面'), findsOneWidget);
    });

    testWidgets('送出中再按發布不會重複建立活動或重複上傳', (tester) async {
      _fakePicker(count: 1);
      final paths = <String>[];
      installMockClient(
        {
          '/api/events': jsonResponse(_created(), status: 201),
          _uploadPath: jsonResponse({'images': <Object?>[]}, status: 201),
        },
        onRequest: (r) => paths.add(r.url.path),
        delayFor: (_) => const Duration(milliseconds: 500),
      );
      await tester.pumpWidget(_host(onPop: (_) {}));
      await _openForm(tester);
      await tester.tap(find.text('新增照片'));
      await tester.pumpAndSettle();
      await _fillRequired(tester);

      await tester.tap(find.text('發布'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(CircularProgressIndicator).first);
      await tester.pumpAndSettle();

      expect(paths, ['/api/events', _uploadPath]);
    });
  });

  group('編輯活動', () {
    EventDetail editing({int imageCount = 2}) => EventDetail(
      id: 1,
      isHost: true,
      title: '部落豐年祭',
      description: '一起來跳舞',
      startsAt: DateTime.now().add(const Duration(days: 30)),
      location: '花蓮縣秀林鄉',
      address: '秀林鄉中正路 1 號',
      status: 'active',
      effectiveStatus: 'active',
      registrationOpen: true,
      images: [
        for (var i = 1; i <= imageCount; i++)
          EventImage(id: 10 + i, url: 'https://example.invalid/${10 + i}.jpg'),
      ],
    );

    testWidgets('顯示現有照片，可標記刪除並還原，封面跟著換', (tester) async {
      await tester.pumpWidget(_host(editing: editing(), onPop: (_) {}));
      await _openForm(tester);

      expect(find.text('2/6 張・第一張是封面'), findsOneWidget);
      await tester.tap(find.byTooltip('移除這張照片').first);
      await tester.pumpAndSettle();

      expect(find.text('將刪除'), findsOneWidget);
      expect(find.text('1/6 張・第一張是封面'), findsOneWidget);
      // 封面標到第二張（第一張已標記刪除）。
      final cover = tester.getCenter(find.text('封面'));
      final removed = tester.getCenter(find.text('將刪除'));
      expect(cover.dx, greaterThan(removed.dx));

      await tester.tap(find.byTooltip('還原這張照片'));
      await tester.pumpAndSettle();
      expect(find.text('將刪除'), findsNothing);
      expect(find.text('2/6 張・第一張是封面'), findsOneWidget);
    });

    testWidgets('按返回放棄：照片與文字都不送出', (tester) async {
      _fakePicker(count: 1);
      var calls = 0;
      installMockClient(const {}, onRequest: (_) => calls++);
      await tester.pumpWidget(_host(editing: editing(), onPop: (_) {}));
      await _openForm(tester);
      await tester.tap(find.byTooltip('移除這張照片').first);
      await tester.tap(find.text('新增照片'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(calls, 0);
    });

    testWidgets('儲存：先存文字、再刪標記的照片、最後上傳新照片', (tester) async {
      _fakePicker(count: 1);
      Object? popped;
      final calls = <String>[];
      installMockClient({
        '/api/events/1': <String, dynamic>{'ok': true},
        '/api/events/1/images/11': {
          'ok': true,
          'images': [
            {'id': 12, 'url': 'https://a/12.jpg'},
          ],
        },
        '/api/events/1/images': jsonResponse({
          'images': [
            {'id': 12, 'url': 'https://a/12.jpg'},
            {'id': 13, 'url': 'https://a/13.jpg'},
          ],
        }, status: 201),
      }, onRequest: (r) => calls.add('${r.method} ${r.url.path}'));
      await tester.pumpWidget(
        _host(editing: editing(), onPop: (r) => popped = r),
      );
      await _openForm(tester);

      await tester.tap(find.byTooltip('移除這張照片').first);
      await tester.tap(find.text('新增照片'));
      await tester.pumpAndSettle();
      await tester.enterText(find.text('部落豐年祭').first, '部落豐年祭（改地點）');
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      expect(calls, [
        'PATCH /api/events/1',
        'DELETE /api/events/1/images/11',
        'POST /api/events/1/images',
      ]);
      expect(popped, isTrue);
      expect(find.text('活動已更新'), findsOneWidget);
    });

    testWidgets('只改照片、沒改文字也能儲存（不送空的 PATCH）', (tester) async {
      final calls = <String>[];
      installMockClient({
        '/api/events/1/images/11': {'ok': true, 'images': <Object?>[]},
      }, onRequest: (r) => calls.add('${r.method} ${r.url.path}'));
      await tester.pumpWidget(
        _host(editing: editing(imageCount: 1), onPop: (_) {}),
      );
      await _openForm(tester);

      await tester.tap(find.byTooltip('移除這張照片'));
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      expect(calls, ['DELETE /api/events/1/images/11']);
    });

    testWidgets('文字已存但新照片上傳失敗：照樣回詳情頁，說明照片沒更新與原因', (tester) async {
      _fakePicker(count: 1);
      Object? popped;
      installMockClient({
        '/api/events/1/images': errorResponse(
          'MUTED',
          status: 403,
          message: '你目前被禁言',
        ),
      });
      await tester.pumpWidget(
        _host(editing: editing(), onPop: (r) => popped = r),
      );
      await _openForm(tester);

      await tester.tap(find.text('新增照片'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(find.textContaining('活動已更新，新照片沒有上傳（你目前被禁言）'), findsOneWidget);
      expect(find.textContaining('活動頁頂端'), findsOneWidget);
    });

    testWidgets('儲存時活動已開始（409）：退回詳情頁，照片不送', (tester) async {
      _fakePicker(count: 1);
      final calls = <String>[];
      installMockClient({
        '/api/events/1': errorResponse('EVENT_ENDED', status: 409),
      }, onRequest: (r) => calls.add('${r.method} ${r.url.path}'));
      await tester.pumpWidget(_host(editing: editing(), onPop: (_) {}));
      await _openForm(tester);

      await tester.tap(find.byTooltip('移除這張照片').first);
      await tester.tap(find.text('新增照片'));
      await tester.pumpAndSettle();
      await tester.enterText(find.text('部落豐年祭').first, '改個名字');
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      expect(calls, ['PATCH /api/events/1']);
      expect(find.text('活動已開始，無法修改'), findsOneWidget);
    });

    testWidgets('滿 6 張：標記刪除一張才能再加，加了之後不能還原', (tester) async {
      final limits = _fakePicker(count: 1);
      await tester.pumpWidget(
        _host(editing: editing(imageCount: 6), onPop: (_) {}),
      );
      await _openForm(tester);

      expect(find.text('新增照片'), findsNothing);
      await tester.tap(find.byTooltip('移除這張照片').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增照片'));
      await tester.pumpAndSettle();
      expect(limits, [1]);
      expect(find.text('6/6 張・第一張是封面'), findsOneWidget);

      await tester.tap(find.byTooltip('還原這張照片'));
      await tester.pumpAndSettle();
      expect(find.textContaining('先移除一張新照片才能還原'), findsOneWidget);
      expect(find.text('將刪除'), findsOneWidget);
    });
  });
}
