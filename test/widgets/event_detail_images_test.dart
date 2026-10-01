// 活動詳情頂端的圖片輪播：所有人看照片，發起人在上面直接新增、刪除。
//
// 這支取代的人工測試：用發起人帳號在正式後端上傳、刪除照片，看輪播、頁數指示、
// 上限、錯誤訊息對不對——每試一次都會在活動上留下或刪掉真的照片。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/events/event_detail_screen.dart';
import 'package:flutter_application_1/services/account_lock_controller.dart';
import 'package:flutter_application_1/services/senior_mode_controller.dart';
import 'package:flutter_application_1/shared/utils/pick_images.dart';

import '../helpers/widget_test_helpers.dart';

const _detailPath = '/api/events/1';
const _uploadPath = '/api/events/1/images';

List<Map<String, Object?>> _images(Iterable<int> ids) => [
  for (final id in ids) {'id': id, 'url': 'https://example.invalid/$id.jpg'},
];

Map<String, Object?> _detail({
  required bool isHost,
  List<int> imageIds = const [],
}) => {
  'id': 1,
  'is_host': isHost,
  'title': '部落豐年祭',
  'starts_at': '2026-12-01T10:00:00Z',
  'status': 'active',
  'effective_status': 'active',
  'participant_count': 5,
  'images': _images(imageIds),
};

Map<String, Object?> _routes(
  Map<String, Object?> detail, [
  Map<String, Object?> extra = const {},
]) => {
  _detailPath: detail,
  '/api/events/1/reminders': {'reminders': <dynamic>[]},
  ...extra,
};

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: const EventDetailScreen(eventId: 1),
    ),
  );
  await tester.pumpAndSettle();
}

/// 換掉挑圖：記下要求的張數上限，回傳 [count] 張假 JPEG。
List<int> _fakePicker({int count = 1, String? skippedNotice}) {
  final limits = <int>[];
  pickImagesForUpload = ({required int limit, required int maxBytes}) async {
    limits.add(limit);
    return (
      images: [
        for (var i = 0; i < count; i++) Uint8List.fromList([i]),
      ],
      skippedNotice: skippedNotice,
    );
  };
  return limits;
}

final _originalPicker = pickImagesForUpload;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    accountLockController.setLocked(false);
  });

  tearDown(() {
    restoreHttp();
    pickImagesForUpload = _originalPicker;
  });

  group('一般使用者', () {
    testWidgets('沒有圖片：沒有新增入口也沒有頁數指示', (tester) async {
      installMockClient(_routes(_detail(isHost: false)));
      await _open(tester);

      expect(find.text('新增照片'), findsNothing);
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('多張圖片：顯示頁數、從標題上左右滑也能換頁，沒有新增刪除', (tester) async {
      installMockClient(_routes(_detail(isHost: false, imageIds: [1, 2, 3])));
      await _open(tester);

      expect(find.text('1／3'), findsOneWidget);
      expect(find.byTooltip('刪除這張照片'), findsNothing);
      expect(find.byTooltip('新增照片'), findsNothing);

      // 標題疊在照片上，不能吃掉滑動。
      await tester.drag(find.text('部落豐年祭').first, const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('2／3'), findsOneWidget);
    });

    testWidgets('只有一張時不顯示頁數', (tester) async {
      installMockClient(_routes(_detail(isHost: false, imageIds: [1])));
      await _open(tester);

      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('1／1'), findsNothing);
    });
  });

  group('發起人新增', () {
    testWidgets('沒有圖片時從「新增照片」上傳，輪播立刻換成後端回的清單', (tester) async {
      final limits = _fakePicker(count: 2);
      http.Request? upload;
      installMockClient(
        _routes(_detail(isHost: true), {
          _uploadPath: jsonResponse({
            'images': _images([7, 8]),
          }, status: 201),
        }),
        onRequest: (r) {
          if (r.url.path == _uploadPath) upload = r;
        },
      );
      await _open(tester);

      await tester.tap(find.text('新增照片'));
      await tester.pumpAndSettle();

      expect(limits, [6]);
      expect(upload?.method, 'POST');
      expect(find.text('1／2'), findsOneWidget);
      expect(find.byTooltip('刪除這張照片'), findsOneWidget);
    });

    testWidgets('已有 4 張時最多只讓選 2 張，上傳後停在第一張新照片', (tester) async {
      final limits = _fakePicker(count: 2);
      installMockClient(
        _routes(_detail(isHost: true, imageIds: [1, 2, 3, 4]), {
          _uploadPath: jsonResponse({
            'images': _images([1, 2, 3, 4, 5, 6]),
          }, status: 201),
        }),
      );
      await _open(tester);

      await tester.tap(find.byTooltip('新增照片'));
      await tester.pumpAndSettle();

      expect(limits, [2]);
      expect(find.text('5／6'), findsOneWidget);
    });

    testWidgets('滿 6 張時不開相簿，說明上限', (tester) async {
      final limits = _fakePicker();
      installMockClient(
        _routes(_detail(isHost: true, imageIds: [1, 2, 3, 4, 5, 6])),
      );
      await _open(tester);

      await tester.tap(find.byTooltip('已達 6 張上限'));
      await tester.pump();

      expect(limits, isEmpty);
      expect(find.textContaining('最多 6 張照片'), findsOneWidget);
    });

    testWidgets('有圖片被略過時提示檔名，其他照常上傳', (tester) async {
      _fakePicker(count: 1, skippedNotice: '已略過 big.heic：無法處理或壓縮後仍超過 5 MB');
      var uploads = 0;
      installMockClient(
        _routes(_detail(isHost: true), {
          _uploadPath: jsonResponse({
            'images': _images([7]),
          }, status: 201),
        }),
        onRequest: (r) {
          if (r.url.path == _uploadPath) uploads++;
        },
      );
      await _open(tester);

      await tester.tap(find.text('新增照片'));
      await tester.pump();

      expect(find.textContaining('big.heic'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(uploads, 1);
    });

    testWidgets('上傳被拒時顯示後端訊息（含禁言到期），輪播維持原樣', (tester) async {
      _fakePicker();
      installMockClient(
        _routes(_detail(isHost: true, imageIds: [1, 2]), {
          _uploadPath: jsonResponse({
            'error': {
              'code': 'MUTED',
              'message': '你目前被禁言',
              'mute_until': '2026-12-31T00:00:00Z',
            },
          }, status: 403),
        }),
      );
      await _open(tester);

      await tester.tap(find.byTooltip('新增照片'));
      await tester.pumpAndSettle();

      expect(find.textContaining('你目前被禁言（至'), findsOneWidget);
      expect(find.text('1／2'), findsOneWidget);
    });

    testWidgets('上傳中再點不會重複送出', (tester) async {
      final limits = _fakePicker();
      var uploads = 0;
      installMockClient(
        _routes(_detail(isHost: true), {
          _uploadPath: jsonResponse({
            'images': _images([7]),
          }, status: 201),
        }),
        onRequest: (r) {
          if (r.url.path == _uploadPath) uploads++;
        },
        delayFor: (r) => r.url.path == _uploadPath
            ? const Duration(seconds: 1)
            : Duration.zero,
      );
      await _open(tester);

      await tester.tap(find.text('新增照片'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('上傳中…'), findsOneWidget);
      await tester.tap(find.text('上傳中…'));
      await tester.pumpAndSettle();

      expect(limits, hasLength(1));
      expect(uploads, 1);
    });

    testWidgets('唯讀帳號不開相簿', (tester) async {
      final limits = _fakePicker();
      installMockClient(_routes(_detail(isHost: true)));
      await _open(tester);
      accountLockController.setLocked(true);

      await tester.tap(find.text('新增照片'));
      await tester.pump();

      expect(limits, isEmpty);
      accountLockController.setLocked(false);
    });
  });

  group('發起人刪除', () {
    testWidgets('確認後刪除，停在相鄰的下一張', (tester) async {
      installMockClient(
        _routes(_detail(isHost: true, imageIds: [1, 2, 3]), {
          '/api/events/1/images/2': {
            'ok': true,
            'images': _images([1, 3]),
          },
        }),
      );
      await _open(tester);
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('2／3'), findsOneWidget);

      await tester.tap(find.byTooltip('刪除這張照片'));
      await tester.pumpAndSettle();
      expect(find.text('刪除這張照片？'), findsOneWidget);
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();

      expect(find.text('2／2'), findsOneWidget);
    });

    testWidgets('取消確認就不打 API', (tester) async {
      var deletes = 0;
      installMockClient(
        _routes(_detail(isHost: true, imageIds: [1])),
        onRequest: (r) {
          if (r.method == 'DELETE') deletes++;
        },
      );
      await _open(tester);

      await tester.tap(find.byTooltip('刪除這張照片'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(deletes, 0);
    });

    testWidgets('刪到沒有圖片時回到漸層，出現「新增照片」', (tester) async {
      installMockClient(
        _routes(_detail(isHost: true, imageIds: [5]), {
          '/api/events/1/images/5': {'ok': true, 'images': <Object?>[]},
        }),
      );
      await _open(tester);

      await tester.tap(find.byTooltip('刪除這張照片'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
      expect(find.text('新增照片'), findsOneWidget);
    });
  });

  testWidgets('上傳過照片後返回，結果為 true（列表會重載換封面）', (tester) async {
    _fakePicker();
    installMockClient(
      _routes(_detail(isHost: true), {
        _uploadPath: jsonResponse({
          'images': _images([7]),
        }, status: 201),
      }),
    );
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
    final result = Navigator.push<bool>(home, EventDetailScreen.route<bool>(1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增照片'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(await result, isTrue);
  });

  testWidgets('精簡模式 320dp 寬：滿 6 張、長分類的發起人頂端不 overflow', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await seniorModeController.setEnabled(true);
    addTearDown(() => seniorModeController.setEnabled(false));
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    installMockClient(
      _routes({
        ..._detail(isHost: true, imageIds: [1, 2, 3, 4, 5, 6]),
        'category': '太魯閣族傳統織布工藝',
        'title': '太魯閣族傳統織布與苧麻工藝體驗暨部落長者口述歷史分享會',
      }),
    );
    await _open(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('1／6'), findsOneWidget);
  });
}
