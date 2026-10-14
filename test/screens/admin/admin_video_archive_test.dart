// 下架影片（後台影片 T-08）：archiveVideo 的端點與回傳值（規格範例，不打正式 API）；
// 列選單「下架」先確認、取消不送出、成功就地改成已下架、處理中多一句提醒、YouTube 用專用文字、
// 檔案沒刪乾淨提示並提供「再刪一次檔案」（不再確認）、送出中選單停用、
// 請求期間列表更新過以新資料為底、404 重抓列表、非管理員退出後台。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/admin/admin_error.dart';
import 'package:flutter_application_1/screens/admin/admin_videos_screen.dart';
import 'package:flutter_application_1/screens/admin/widgets/admin_widgets.dart';
import 'package:flutter_application_1/services/admin_service.dart';
import 'package:flutter_application_1/services/category_service.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

const _videosPath = '/api/admin/videos';
const _archivePath = '/api/admin/videos/7/archive';
const _archived = 'post_api_admin_videos_archive.json';
const _notDeleted = 'post_api_admin_videos_archive_files_not_deleted.json';

Map<String, dynamic> _video({
  String status = 'ready',
  String title = '織布',
  String source = 'hls',
}) => {
  'id': 7,
  'title': title,
  'description': null,
  'category': 'cultural',
  'source': source,
  'status': status,
  'fail_reason': null,
  'duration_sec': 60,
  'thumbnail_url': null,
  'youtube_video_id': null,
  'embeddable': null,
  'tribe_id': null,
  'created_at': '2026-10-13T00:00:00.000Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    restoreHttp();
    CategoryService.reset();
    UserService.clearCache();
  });

  group('AdminService.archiveVideo', () {
    late List<http.Request> requests;

    void mockArchive(String fixture) {
      requests = [];
      installMockClient({
        _archivePath: loadSpecFixtureMap(fixture),
      }, onRequest: requests.add);
    }

    test('POST 不帶 body，檔案刪乾淨回 true', () async {
      mockArchive(_archived);
      expect(await AdminService.archiveVideo(7), isTrue);
      final r = requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, _archivePath);
      expect(r.body, isEmpty);
    });

    test('files_deleted: false 回 false', () async {
      mockArchive(_notDeleted);
      expect(await AdminService.archiveVideo(7), isFalse);
    });
  });

  group('列選單下架', () {
    late int listCalls;
    late int archiveCalls;

    /// 列表回的標題；測試中途改它，模擬請求期間列表被重整成新資料。
    late String listTitle;

    /// 列表回一筆 [status] 的影片；下架依序回 [archive]（fixture 檔名、http.Response，
    /// 或 Completer<String>：完成前請求停在送出中，完成值是 fixture 檔名）。
    void mock({
      String status = 'ready',
      String source = 'hls',
      required List<Object> archive,
    }) {
      listCalls = 0;
      archiveCalls = 0;
      listTitle = '織布';
      ApiClient.httpClient = MockClient((r) async {
        switch (r.url.path) {
          case _videosPath:
            listCalls++;
            return jsonResponse({
              'videos': [
                _video(status: status, title: listTitle, source: source),
              ],
              'page_info': {'next_cursor': null, 'has_more': false},
            });
          case _archivePath:
            var res = archive[archiveCalls++];
            if (res is Completer<String>) res = await res.future;
            return res is http.Response
                ? res
                : jsonResponse(loadSpecFixtureMap(res as String));
          case '/api/videos/categories':
            return jsonResponse({'categories': []});
          case '/api/me':
            return jsonResponse({
              'uid': 1,
              'created_at': '2026-01-01T00:00:00Z',
              'role': 'user',
            });
        }
        fail('沒有準備 ${r.method} ${r.url}');
      });
    }

    Future<void> openList(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    pushAdmin<void>(context, const AdminVideosScreen()),
                child: const Text('開啟'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開啟'));
      await tester.pumpAndSettle();
    }

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('更多操作'));
      await tester.pumpAndSettle();
    }

    Future<void> chooseArchive(WidgetTester tester) async {
      await openMenu(tester);
      await tester.tap(find.text('下架'));
      await tester.pumpAndSettle();
    }

    Finder confirmButton() => find.widgetWithText(FilledButton, '下架');

    /// 列上的狀態標籤（篩選列也有同名 chip，限定在列卡片裡找）。
    Finder rowStatus(String label) =>
        find.descendant(of: find.byType(AdminCard), matching: find.text(label));

    testWidgets('先跳確認，取消不送出', (tester) async {
      mock(archive: [_archived]);
      await openList(tester);
      await chooseArchive(tester);

      expect(find.text('下架會刪除播放檔，無法復原。'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(archiveCalls, 0);
      expect(rowStatus('已上架'), findsOneWidget);
    });

    testWidgets('確認後該列就地變已下架，不重抓列表，選單不再有下架', (tester) async {
      mock(archive: [_archived]);
      await openList(tester);
      await chooseArchive(tester);
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(archiveCalls, 1);
      expect(listCalls, 1);
      expect(rowStatus('已上架'), findsNothing);
      expect(rowStatus('已下架'), findsOneWidget);

      await openMenu(tester);
      expect(find.text('編輯'), findsOneWidget);
      expect(find.text('下架'), findsNothing);
      expect(find.text('再刪一次檔案'), findsNothing);
    });

    testWidgets('處理中的影片也能下架，確認框多提醒殘留檔案', (tester) async {
      mock(status: 'processing', archive: [_archived]);
      await openList(tester);
      await chooseArchive(tester);

      expect(find.text('下架會刪除播放檔，無法復原。轉檔中的影片之後可能仍有殘留檔案。'), findsOneWidget);
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();
      expect(archiveCalls, 1);
    });

    testWidgets('YouTube 影片的確認框用專用文字（沒有播放檔可刪）', (tester) async {
      mock(source: 'youtube', archive: [_archived]);
      await openList(tester);
      await chooseArchive(tester);

      expect(find.text('下架後 App 不再顯示這支影片。'), findsOneWidget);
      expect(find.textContaining('刪除播放檔'), findsNothing);
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();
      expect(archiveCalls, 1);
      expect(rowStatus('已下架'), findsOneWidget);
    });

    testWidgets('已下架的影片沒有下架選項', (tester) async {
      mock(status: 'archived', archive: []);
      await openList(tester);
      await openMenu(tester);

      expect(find.text('編輯'), findsOneWidget);
      expect(find.text('下架'), findsNothing);
      expect(find.text('再刪一次檔案'), findsNothing);
    });

    testWidgets('檔案沒刪乾淨：提示再按一次，再刪一次檔案不再確認，成功後選項消失', (tester) async {
      mock(archive: [_notDeleted, _archived]);
      await openList(tester);
      await chooseArchive(tester);
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(find.text('已下架，但檔案沒刪乾淨，請再按一次'), findsOneWidget);
      await openMenu(tester);
      await tester.tap(find.text('再刪一次檔案'));
      await tester.pumpAndSettle();

      expect(find.byType(FilledButton), findsNothing, reason: '不再跳確認');
      expect(archiveCalls, 2);
      expect(rowStatus('已下架'), findsOneWidget);
      await openMenu(tester);
      expect(find.text('再刪一次檔案'), findsNothing);
    });

    testWidgets('送出中：選單項目停用並顯示下架中，點了也不重送', (tester) async {
      final pending = Completer<String>();
      mock(archive: [pending]);
      await openList(tester);
      await chooseArchive(tester);
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      await openMenu(tester);
      final item = tester.widget<PopupMenuItem<int>>(
        find.widgetWithText(PopupMenuItem<int>, '下架中…'),
      );
      expect(item.enabled, isFalse);
      expect(find.text('下架'), findsNothing);
      await tester.tap(find.text('下架中…'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(archiveCalls, 1);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      pending.complete(_archived);
      await tester.pumpAndSettle();
      expect(rowStatus('已下架'), findsOneWidget);
      await openMenu(tester);
      expect(find.text('下架中…'), findsNothing);
    });

    testWidgets('送出期間下拉重整過：以重整後的那筆為底改成已下架，不蓋回舊資料', (tester) async {
      final pending = Completer<String>();
      mock(archive: [pending]);
      await openList(tester);
      await chooseArchive(tester);
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      listTitle = '織布（改名）';
      tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
      await tester.pumpAndSettle();
      expect(listCalls, 2);
      expect(find.text('織布（改名）'), findsOneWidget);

      pending.complete(_archived);
      await tester.pumpAndSettle();
      expect(find.text('織布（改名）'), findsOneWidget);
      expect(find.text('織布'), findsNothing);
      expect(rowStatus('已下架'), findsOneWidget);
    });

    testWidgets('404 VIDEO_NOT_FOUND：提示影片不存在並重抓列表', (tester) async {
      mock(
        archive: [
          errorResponse('VIDEO_NOT_FOUND', status: 404, message: '影片不存在'),
        ],
      );
      await openList(tester);
      await chooseArchive(tester);
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(find.text('這支影片已不存在'), findsOneWidget);
      expect(listCalls, 2);
    });

    testWidgets('非管理員：退出整個後台', (tester) async {
      mock(
        archive: [
          errorResponse('ADMIN_ONLY', status: 403, message: '只有管理員可以使用'),
        ],
      );
      UserService.currentUid = 1;
      await openList(tester);
      await chooseArchive(tester);
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(find.text('開啟'), findsOneWidget);
      expect(find.text('影片管理'), findsNothing);
    });
  });
}
