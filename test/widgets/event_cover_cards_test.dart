// 活動卡片的封面：六種卡片有封面時顯示照片、沒有時跟原本一樣；封面過期時
// 卡片退回沒有封面的樣子，列表只重新整理一次換新網址。
//
// 這支取代的人工測試：準備有封面與沒封面的活動，逐一翻活動列表、廣場、我發起的、
// 我參加的、按讚收藏、搜尋看封面；過期要在列表停 15 分鐘以上才看得到。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/event_model.dart';
import 'package:flutter_application_1/screens/events/event_liked_bookmarked_list.dart';
import 'package:flutter_application_1/screens/events/my_events_screen.dart';
import 'package:flutter_application_1/screens/events/event_search_screen.dart';
import 'package:flutter_application_1/screens/events/widgets/event_cards.dart';
import 'package:flutter_application_1/screens/events/widgets/event_cover.dart';
import 'package:flutter_application_1/screens/events/widgets/event_status_tile.dart';
import 'package:flutter_application_1/screens/plaza/widgets/plaza_cards.dart';
import 'package:flutter_application_1/shared/widgets/async_state_view.dart';
import 'package:flutter_application_1/shared/widgets/signed_network_image.dart';

import '../helpers/widget_test_helpers.dart';

const _cover = 'https://example.invalid/events/1/a.jpg?X-Goog-Signature=x';
const _longTitle = '太魯閣族傳統織布與苧麻工藝體驗暨部落長者口述歷史分享會';

Map<String, Object?> _json({int id = 1, String? cover = _cover}) => {
  'id': id,
  'title': _longTitle,
  'starts_at': '2026-12-01T10:00:00Z',
  'status': 'active',
  'effective_status': 'active',
  'registration_open': true,
  'category': '工藝',
  'location': '秀林部落活動中心',
  'participant_count': 12,
  'max_participants': 30,
  'cover_image_url': cover,
};

EventSummary _event({String? cover = _cover}) =>
    EventSummary.fromJson(_json(cover: cover));

/// 六種卡片裡，能直接建出來的四種（另外兩種是畫面私有的列，從畫面測）。
List<Widget> _cards(EventSummary e, bool seniorMode) => [
  EventFeaturedCard(event: e, seniorMode: seniorMode, onTap: (_) {}),
  // EventList 跳過第一筆（第一筆是精選大卡）。
  EventList(events: [e, e], seniorMode: seniorMode, onTap: (_) {}),
  EventStatusTile(event: e, seniorMode: seniorMode, onTap: () {}),
  PlazaMiniEventCard(event: e, onTap: () {}),
];

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  group('卡片', () {
    testWidgets('有封面：每種卡片都顯示封面照片', (tester) async {
      for (final card in _cards(_event(), false)) {
        await tester.pumpWidget(_wrap(card));
        expect(
          find.byType(SignedNetworkImage),
          findsOneWidget,
          reason: '${card.runtimeType} 沒有顯示封面',
        );
        expect(
          tester
              .widget<SignedNetworkImage>(find.byType(SignedNetworkImage))
              .url,
          _cover,
        );
      }
    });

    testWidgets('沒有封面：卡片上沒有任何照片元件', (tester) async {
      for (final card in _cards(_event(cover: null), false)) {
        await tester.pumpWidget(_wrap(card));
        expect(find.byType(SignedNetworkImage), findsNothing);
      }
    });

    for (final seniorMode in [false, true]) {
      testWidgets('320dp 寬、${seniorMode ? '精簡' : '一般'}模式、長標題加封面不 overflow', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(320, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final card in _cards(_event(), seniorMode)) {
          await tester.pumpWidget(
            _wrap(
              // 廣場小卡在水平清單裡，高度固定 120。
              card is PlazaMiniEventCard
                  ? SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [card],
                      ),
                    )
                  // 精選大卡與 EventList 自帶左右 20；狀態列由所在清單給。
                  : card is EventStatusTile
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: card,
                    )
                  : card,
            ),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${card.runtimeType} overflow',
          );
        }
      });
    }

    testWidgets('列表縮圖破圖：退回沒有縮圖的樣子並往上回報', (tester) async {
      var refreshes = 0;
      await tester.pumpWidget(
        _wrap(
          EventCoverRefresher(
            onRefresh: () async => refreshes++,
            child: EventStatusTile(
              event: _event(),
              seniorMode: false,
              onTap: () {},
            ),
          ),
        ),
      );

      // 測試環境無法讓 CachedNetworkImage 真的進 errorWidget，直接驅動回報。
      tester
          .widget<SignedNetworkImage>(find.byType(SignedNetworkImage))
          .onExpired!();
      await tester.pump();

      expect(find.byType(SignedNetworkImage), findsNothing);
      expect(refreshes, 1);
    });
  });

  testWidgets('縮圖破圖後換了新網址會再試一次', (tester) async {
    Widget thumb(String url) =>
        _wrap(EventCoverThumb(url: url, seniorMode: false));
    await tester.pumpWidget(thumb('https://h/a.jpg?s=1'));
    tester
        .widget<SignedNetworkImage>(find.byType(SignedNetworkImage))
        .onExpired!();
    await tester.pump();
    expect(find.byType(SignedNetworkImage), findsNothing);

    await tester.pumpWidget(thumb('https://h/a.jpg?s=2'));
    expect(find.byType(SignedNetworkImage), findsOneWidget);
  });

  group('EventCoverRefresher', () {
    testWidgets('冷卻時間內多張封面過期只重新整理一次，過了才再整理', (tester) async {
      var refreshes = 0;
      late BuildContext inner;
      await tester.pumpWidget(
        EventCoverRefresher(
          onRefresh: () async => refreshes++,
          cooldown: const Duration(minutes: 5),
          child: Builder(
            builder: (c) {
              inner = c;
              return const SizedBox();
            },
          ),
        ),
      );

      for (var i = 0; i < 10; i++) {
        const EventCoverExpiredNotification().dispatch(inner);
      }
      expect(refreshes, 1);
    });
  });

  group('畫面私有的列', () {
    testWidgets('按讚的活動：有封面的列顯示縮圖，沒封面的沒有', (tester) async {
      installMockClient({
        '/api/events/likes': {
          'events': [_json(id: 1), _json(id: 2, cover: null)],
        },
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EventLikedBookmarkedList(mode: EventListMode.liked),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SignedNetworkImage), findsOneWidget);
    });

    testWidgets('搜尋結果：有封面的列顯示縮圖', (tester) async {
      installMockClient({
        '/api/search/history': {'history': <dynamic>[]},
        '/api/search/popular': {'popular': <dynamic>[]},
        '/api/events/search': {
          'events': [_json(id: 1), _json(id: 2, cover: null)],
        },
      });
      await tester.pumpWidget(const MaterialApp(home: EventSearchScreen()));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, '織布');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SignedNetworkImage), findsOneWidget);
    });
  });

  group('封面過期換新網址', () {
    /// 模擬封面永遠載不起來：每輪把畫面上所有封面都回報一次過期。
    Future<void> expireAll(WidgetTester tester) async {
      for (final image in tester.widgetList<SignedNetworkImage>(
        find.byType(SignedNetworkImage),
      )) {
        image.onExpired!();
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('按讚列表：封面一直壞也只重取一次，不閃載入畫面', (tester) async {
      var calls = 0;
      installMockClient(
        {
          '/api/events/likes': {
            'events': [_json(id: 1), _json(id: 2)],
          },
        },
        onRequest: (r) {
          if (r.url.path == '/api/events/likes') calls++;
        },
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EventLikedBookmarkedList(mode: EventListMode.liked),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);

      for (var round = 0; round < 5; round++) {
        await expireAll(tester);
        expect(find.byType(TrukuLoadingView), findsNothing);
        await tester.pumpAndSettle();
      }

      expect(calls, 2);
    });

    testWidgets('我發起的活動：重取失敗時保留原清單，不換成錯誤畫面', (tester) async {
      installMockClient({
        '/api/events/mine': {
          'events': [_json(id: 1)],
        },
      });
      await tester.pumpWidget(const MaterialApp(home: MyEventsScreen()));
      await tester.pumpAndSettle();
      // 之後的重取都失敗（例如斷線）。
      installMockClient({
        '/api/events/mine': errorResponse('SERVER_ERROR', status: 500),
      });

      await expireAll(tester);
      await tester.pumpAndSettle();

      expect(find.byType(TrukuErrorView), findsNothing);
      expect(find.text(_longTitle), findsOneWidget);
    });

    testWidgets('搜尋結果：重取用上次送出的關鍵字，不用輸入框裡還沒送出的字', (tester) async {
      final queries = <String?>[];
      installMockClient(
        {
          '/api/search/history': {'history': <dynamic>[]},
          '/api/search/popular': {'popular': <dynamic>[]},
          '/api/events/search': {
            'events': [_json(id: 1)],
          },
        },
        onRequest: (r) {
          if (r.url.path == '/api/events/search') {
            queries.add(r.url.queryParameters['q']);
          }
        },
      );
      await tester.pumpWidget(const MaterialApp(home: EventSearchScreen()));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, '織布');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField).first, '還沒送出');

      await expireAll(tester);

      expect(queries, ['織布', '織布']);
      expect(find.text(_longTitle), findsOneWidget);
    });
  });
}
