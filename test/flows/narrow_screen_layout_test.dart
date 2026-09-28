// 取代的人工重測：
//   「把手機『顯示大小』調大（或用 adb shell wm density 560），逐頁看標題
//     有沒有被截成『…』、版面有沒有爆黃黑條」
//
// Android 的顯示大小設定會讓 Flutter 拿到的邏輯寬度變窄（1080px 在 density 560
// 下只剩約 308dp），main.dart 的 textScaler clamp 攔不住這種情況。
// 實機回報：活動頁標題「近期部落聚會」被截成「近期部落…」。
//
// 這裡用 320dp 寬度 render 主分頁與常用子頁面，一般模式與精簡模式各跑一輪：
//   - 任何 RenderFlex overflow 會以 FlutterError 讓測試直接失敗
//   - 固定文案的頁首標題另外斷言沒有被截斷（ellipsis 不會丟錯，只能主動檢查）
//   - 清單資料來自真實 fixture，標題換成超長字串，確認長內容也不會撐爆版面

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/main.dart' show navigatorKey;
import 'package:flutter_application_1/screens/backpack/backpack_screen.dart';
import 'package:flutter_application_1/screens/events/event_compose_screen.dart';
import 'package:flutter_application_1/screens/events/event_detail_screen.dart';
import 'package:flutter_application_1/screens/events/event_search_screen.dart';
import 'package:flutter_application_1/screens/events/my_events_screen.dart';
import 'package:flutter_application_1/screens/shop/shop_screen.dart';
import 'package:flutter_application_1/services/senior_mode_controller.dart';
import 'package:flutter_application_1/shared/widgets/truku_bottom_tab.dart';

import '../helpers/fixtures.dart';
import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

/// 顯示大小調大後常見的最窄邏輯寬度。
const _narrowSurface = Size(320, 800);

/// 塞進清單標題的超長字串，模擬使用者自訂的長名稱。
const _longTitle = '太魯閣族傳統織布與苧麻工藝體驗暨部落長者口述歷史分享會';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // 切換精簡模式會寫入 SharedPreferences，測試環境沒有原生實作。
    SharedPreferences.setMockInitialValues({});
    stubCommonChannels(token: 'test-token');
    resetGlobals();
    await seniorModeController.setEnabled(false);
  });

  tearDown(() async {
    restoreHttp();
    resetGlobals();
    await seniorModeController.setEnabled(false);
  });

  /// fixture 清單的每一筆 title 都換成 [_longTitle]。
  Map<String, dynamic> withLongTitles(String fixture, String key) {
    final json = loadFixtureMap(fixture);
    json[key] = [
      for (final item in loadFixtureList(fixture, key))
        {...item, 'title': _longTitle},
    ];
    return json;
  }

  Map<String, Object?> routes() {
    final eventDetail = {
      ...loadFixtureMap('get_api_event_detail.json'),
      'title': _longTitle,
    };
    final videoDetail = {
      ...loadFixtureMap('get_api_video_detail.json'),
      'title': _longTitle,
    };
    return {
      '/api/me': loadFixtureMap('get_api_me.json'),
      '/api/shop/items': loadFixtureMap('get_api_shop_items.json'),
      '/api/checkin/status': {
        'checked_in_today': false,
        'streak': 0,
        'weekly_count': 0,
        'weekly_bonus_earned': false,
      },
      '/api/notifications/summary': loadFixtureMap(
        'get_api_notifications_summary.json',
      ),
      '/api/levels': loadFixtureMap('get_api_levels.json'),
      '/api/videos': withLongTitles('get_api_videos.json', 'videos'),
      '/api/articles': {'articles': <dynamic>[], 'total': 0},
      '/api/events': withLongTitles('get_api_events_scope_all.json', 'events'),
      '/api/events/${eventDetail['id']}': eventDetail,
      '/api/videos/${videoDetail['id']}': videoDetail,
      '/api/forum/boards': {'boards': <dynamic>[]},
      '/api/friends': {'friends': <dynamic>[]},
      '/api/friends/requests': {'requests': <dynamic>[]},
      '/api/friends/messages': {'conversations': <dynamic>[]},
      '/api/forum/posts': {'posts': <dynamic>[], 'total': 0},
    };
  }

  Future<void> tapText(
    WidgetTester tester,
    String label, {
    Finder? within,
  }) async {
    await tester.tap(
      within == null
          ? find.text(label).hitTestable().first
          : find.descendant(of: within, matching: find.text(label)),
    );
    await pumpFrames(tester);
  }

  /// 標題要完整顯示，不能被 maxLines + ellipsis 截斷。
  void expectNotTruncated(WidgetTester tester, String text) {
    final finder = find.text(text).hitTestable();
    expect(finder, findsWidgets, reason: '找不到可見的「$text」');
    final paragraph = tester.renderObject<RenderParagraph>(finder.first);
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: '「$text」在 ${_narrowSurface.width}dp 寬度下被截斷',
    );
  }

  Future<void> startApp(WidgetTester tester) async {
    installMockClient(routes());
    usePhoneSurface(tester, size: _narrowSurface);
    await tester.pumpWidget(buildTestApp(initialRoute: '/home'));
    await pumpFrames(tester, times: 10);
  }

  /// 推一頁、等它載完、再退回。overflow 會在 pump 過程中直接讓測試失敗。
  Future<void> visit(WidgetTester tester, Widget page) async {
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
    await pumpFrames(tester, times: 10);
    navigatorKey.currentState!.pop();
    await pumpFrames(tester);
  }

  for (final senior in [false, true]) {
    final mode = senior ? '精簡模式' : '一般模式';
    group(mode, () {
      // 在 testWidgets 的 FakeAsync 內切換會卡住，改在 setUp 切。
      setUp(() => seniorModeController.setEnabled(senior));

      testWidgets('320dp 寬度下廣場的頁首標題完整顯示', (tester) async {
        expect(seniorModeController.enabled, senior);
        await startApp(tester);

        await tapText(tester, '廣場活動', within: find.byType(TrukuBottomTab));
        expectNotTruncated(tester, senior ? '動態' : '族人在這裡');

        await tapText(tester, '活動');
        expectNotTruncated(tester, senior ? '活動' : '近期部落聚會');
      });

      testWidgets('320dp 寬度下五個分頁（含長標題資料）都不 overflow', (tester) async {
        expect(seniorModeController.enabled, senior);
        await startApp(tester);

        for (final label in ['學習影音', '廣場活動', '好友', '我的', '首頁']) {
          await tapText(tester, label, within: find.byType(TrukuBottomTab));
        }
      });

      testWidgets('320dp 寬度下常用子頁面都不 overflow', (tester) async {
        expect(seniorModeController.enabled, senior);
        await startApp(tester);

        // 影片詳情頁不測：better_player 在測試環境解析 HLS 會丟 RangeError。
        await visit(tester, const EventDetailScreen(eventId: 41));
        await visit(tester, const EventComposeScreen());
        await visit(tester, const EventSearchScreen());
        await visit(tester, const MyEventsScreen());
        await visit(tester, const ShopScreen());
        await visit(tester, const BackpackScreen());
      });
    });
  }
}
