// 活動詳情頂端的圖片輪播：所有人看照片，發起人在上面直接新增、刪除。
//
// 這支取代的人工測試：用發起人帳號在正式後端上傳、刪除照片，看輪播、頁數指示、
// 上限、錯誤訊息對不對——每試一次都會在活動上留下或刪掉真的照片。

import 'dart:io' show SocketException;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/events/event_detail_screen.dart';
import 'package:flutter_application_1/screens/events/widgets/event_detail_hero.dart';
import 'package:flutter_application_1/screens/forum/widgets/forum_image_grid.dart';
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

  group('全螢幕與網址過期', () {
    testWidgets('點照片從那一張開全螢幕；發起人點照片也不會誤刪', (tester) async {
      var deletes = 0;
      installMockClient(
        _routes(_detail(isHost: true, imageIds: [1, 2, 3])),
        onRequest: (r) {
          if (r.method == 'DELETE') deletes++;
        },
      );
      await _open(tester);
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(find.byType(PageView)));
      await tester.pumpAndSettle();

      final viewer = tester.widget<ForumImageViewer>(
        find.byType(ForumImageViewer),
      );
      expect(viewer.initialIndex, 1);
      expect(viewer.images, hasLength(3));
      expect(find.text('2 / 3'), findsOneWidget);
      expect(deletes, 0);
    });

    testWidgets('網址過期自動重取詳情有次數上限，手動重試不受限', (tester) async {
      var detailCalls = 0;
      installMockClient(
        _routes(_detail(isHost: false, imageIds: [1, 2])),
        onRequest: (r) {
          if (r.url.path == _detailPath) detailCalls++;
        },
      );
      await _open(tester);
      expect(detailCalls, 1);

      // 測試環境無法真的讓 CachedNetworkImage 進 errorWidget，直接驅動回報的接縫，
      // 模擬每次重取後照片仍然載不起來的最壞情況。
      EventDetailHero hero() =>
          tester.widget<EventDetailHero>(find.byType(EventDetailHero));
      for (var i = 0; i < 10; i++) {
        hero().onImageExpired!();
        await tester.pumpAndSettle();
      }
      expect(detailCalls, 1 + 3);

      hero().onImageRetryTap!();
      await tester.pumpAndSettle();
      expect(detailCalls, 1 + 3 + 1);
    });
  });

  testWidgets('過期重取還在路上時上傳成功：晚回來的舊詳情不會蓋掉新照片', (tester) async {
    _fakePicker();
    var detailCalls = 0;
    installMockClient(
      _routes(_detail(isHost: true, imageIds: [1]), {
        _uploadPath: jsonResponse({
          'images': _images([1, 2]),
        }, status: 201),
      }),
      onRequest: (r) {
        if (r.url.path == _detailPath) detailCalls++;
      },
      // 進頁後的重取晚 2 秒才回來，期間完成上傳。
      delayFor: (r) => r.url.path == _detailPath && detailCalls > 1
          ? const Duration(seconds: 2)
          : Duration.zero,
    );
    await _open(tester);

    tester
        .widget<EventDetailHero>(find.byType(EventDetailHero))
        .onImageExpired!();
    await tester.pump();
    await tester.tap(find.byTooltip('新增照片'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('2／2'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(detailCalls, 2);
    expect(find.text('2／2'), findsOneWidget);
  });

  group('下拉重整', () {
    Future<void> pullToRefresh(WidgetTester tester) async {
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      // 讓 RefreshIndicator 跑完拉下的動畫、送出重取，但不等請求回來。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Finder capacity(int count) =>
        find.text('$count 人 · 不限名額', skipOffstage: false);

    /// 上傳要 3 秒；進頁之後的詳情重取要 2 秒，重整途中的畫面才看得到。
    Duration Function(http.Request) slowUploadAndRefetch() {
      var detailCalls = 0;
      return (r) {
        if (r.url.path == _uploadPath) return const Duration(seconds: 3);
        if (r.url.path == _detailPath && ++detailCalls > 1) {
          return const Duration(seconds: 2);
        }
        return Duration.zero;
      };
    }

    testWidgets('上傳中下拉重整：輪播不被卸載，上傳完照片出現在清單裡', (tester) async {
      _fakePicker();
      var detailCalls = 0;
      installMockClient(
        _routes(_detail(isHost: true, imageIds: [1]), {
          _uploadPath: jsonResponse({
            'images': _images([1, 2]),
          }, status: 201),
        }),
        onRequest: (r) {
          if (r.url.path == _detailPath) detailCalls++;
        },
        delayFor: slowUploadAndRefetch(),
      );
      await _open(tester);

      await tester.tap(find.byTooltip('新增照片'));
      await tester.pump(const Duration(milliseconds: 100));
      await pullToRefresh(tester);

      expect(detailCalls, 2, reason: '下拉有重取詳情');
      expect(find.byType(EventDetailHero), findsOneWidget, reason: '不換成載入畫面');

      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('2／2'), findsOneWidget);
    });

    testWidgets('上傳中下拉重整後上傳失敗：仍看得到失敗提示', (tester) async {
      _fakePicker();
      installMockClient(
        _routes(_detail(isHost: true, imageIds: [1]), {
          _uploadPath: errorResponse('UPLOAD_FAILED', message: '照片格式不支援'),
        }),
        delayFor: slowUploadAndRefetch(),
      );
      await _open(tester);

      await tester.tap(find.byTooltip('新增照片'));
      await tester.pump(const Duration(milliseconds: 100));
      await pullToRefresh(tester);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('照片格式不支援'), findsOneWidget);
    });

    testWidgets('重整回來的舊照片清單不蓋掉剛上傳的結果', (tester) async {
      _fakePicker();
      var detailCalls = 0;
      installMockClient(
        _routes(_detail(isHost: true, imageIds: [1]), {
          _uploadPath: jsonResponse({
            'images': _images([1, 2]),
          }, status: 201),
        }),
        onRequest: (r) {
          if (r.url.path == _detailPath) detailCalls++;
        },
        // 下拉的重取晚 3 秒才回來，期間完成上傳。
        delayFor: (r) => r.url.path == _detailPath && detailCalls > 1
            ? const Duration(seconds: 3)
            : Duration.zero,
      );
      await _open(tester);

      await pullToRefresh(tester);
      await tester.tap(find.byTooltip('新增照片'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('2／2'), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(detailCalls, 2);
      expect(find.text('2／2'), findsOneWidget);
    });

    testWidgets('一般下拉重整照常更新報名人數', (tester) async {
      final routes = _routes(_detail(isHost: false));
      installMockClient(routes);
      await _open(tester);
      expect(capacity(5), findsOneWidget);

      routes[_detailPath] = {..._detail(isHost: false), 'participant_count': 6};
      await pullToRefresh(tester);
      await tester.pumpAndSettle();

      expect(capacity(6), findsOneWidget);
      expect(capacity(5), findsNothing);
    });

    testWidgets('下拉重整失敗：提示後端訊息，畫面內容保留', (tester) async {
      final routes = _routes(_detail(isHost: false, imageIds: [1, 2]));
      installMockClient(routes);
      await _open(tester);

      routes[_detailPath] = errorResponse(
        'NOT_FOUND',
        status: 404,
        message: '找不到這個活動',
      );
      await pullToRefresh(tester);
      await tester.pumpAndSettle();

      expect(find.text('找不到這個活動'), findsOneWidget);
      expect(find.byType(EventDetailHero), findsOneWidget);
      expect(find.text('1／2'), findsOneWidget);
      expect(capacity(5), findsOneWidget);
    });

    testWidgets('下拉重整斷線：提示連不上伺服器', (tester) async {
      var offline = false;
      installMockClient(
        _routes(_detail(isHost: false)),
        onRequest: (r) {
          if (offline && r.url.path == _detailPath) {
            throw const SocketException('offline');
          }
        },
      );
      await _open(tester);

      offline = true;
      await pullToRefresh(tester);
      await tester.pumpAndSettle();

      expect(find.text('無法連線到伺服器，請檢查網路'), findsOneWidget);
      expect(capacity(5), findsOneWidget);
    });

    // 照片載不出來時的重取：使用者點的「重試」失敗要提示，網址過期的自動重取不打擾。
    Future<void> failingImageRefetch(
      WidgetTester tester,
      VoidCallback Function(EventDetailHero hero) trigger,
    ) async {
      final routes = _routes(_detail(isHost: false, imageIds: [1]));
      installMockClient(routes);
      await _open(tester);

      routes[_detailPath] = errorResponse(
        'NOT_FOUND',
        status: 404,
        message: '找不到這個活動',
      );
      trigger(tester.widget<EventDetailHero>(find.byType(EventDetailHero)))();
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailHero), findsOneWidget, reason: '畫面內容保留');
    }

    testWidgets('手動點照片重試失敗：提示後端訊息', (tester) async {
      await failingImageRefetch(tester, (hero) => hero.onImageRetryTap!);
      expect(find.text('找不到這個活動'), findsOneWidget);
    });

    testWidgets('離線連點重試：提示只留一則，不會一則接一則排隊', (tester) async {
      var offline = false;
      installMockClient(
        _routes(_detail(isHost: false, imageIds: [1])),
        onRequest: (r) {
          if (offline && r.url.path == _detailPath) {
            throw const SocketException('offline');
          }
        },
      );
      await _open(tester);

      offline = true;
      for (var i = 0; i < 3; i++) {
        tester
            .widget<EventDetailHero>(find.byType(EventDetailHero))
            .onImageRetryTap!();
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.pumpAndSettle();
      expect(find.text('無法連線到伺服器，請檢查網路'), findsOneWidget);

      // SnackBar 預設停 4 秒；排隊的話時間到後會換下一則繼續顯示。
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('上傳失敗提示顯示中又重整失敗：上傳失敗提示不會被收掉', (tester) async {
      _fakePicker();
      var offline = false;
      installMockClient(
        _routes(_detail(isHost: true, imageIds: [1]), {
          _uploadPath: errorResponse('UPLOAD_FAILED', message: '照片格式不支援'),
        }),
        onRequest: (r) {
          if (offline && r.url.path == _detailPath) {
            throw const SocketException('offline');
          }
        },
      );
      await _open(tester);

      await tester.tap(find.byTooltip('新增照片'));
      await tester.pumpAndSettle();
      expect(find.text('照片格式不支援'), findsOneWidget);

      offline = true;
      await pullToRefresh(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('照片格式不支援'), findsOneWidget);
      expect(find.text('無法連線到伺服器，請檢查網路'), findsNothing, reason: '排在後面');

      // 上傳失敗提示停完 4 秒才輪到重整失敗。
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('照片格式不支援'), findsNothing);
      expect(find.text('無法連線到伺服器，請檢查網路'), findsOneWidget);
    });

    testWidgets('照片網址過期的自動重取失敗：不提示', (tester) async {
      await failingImageRefetch(tester, (hero) => hero.onImageExpired!);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
