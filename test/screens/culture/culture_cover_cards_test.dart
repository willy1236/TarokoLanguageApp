// 影音、文章總覽每一則都是大圖卡，清單上看不到觀看／閱讀數。
// 取代的人工重測：「打開影音與文章總覽往下滑，每一則都有大封面與標題、沒有觀看數；
//   切精簡模式後標題移到封面下方、摘要不見」。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/video_models.dart';
import 'package:flutter_application_1/screens/culture/widgets/culture_article_section.dart';
import 'package:flutter_application_1/screens/culture/widgets/culture_cards.dart';
import 'package:flutter_application_1/screens/culture/widgets/culture_icons.dart';

import '../../helpers/flow_test_helpers.dart';
import '../../helpers/widget_test_helpers.dart';

Map<String, dynamic> _article(int id, {String? summary}) => {
  'id': id,
  'title': '文章 $id',
  'summary': summary,
  'cover_image_url': null,
  'category': 'education',
  'view_count': 1234,
  'weekly_view_count': 56,
  'like_count': 1,
  'is_liked': false,
  'is_bookmarked': false,
  'published_at': '2026-09-01T00:00:00Z',
};

VideoSummary _video({
  String title = '影片標題',
  String? description,
  int? durationSec,
  String? source,
}) => VideoSummary(
  id: 1,
  title: title,
  description: description,
  category: VideoCategory.all.first,
  source: source ?? VideoSource.hls,
  durationSec: durationSec,
  viewCount: 1234,
  weeklyViewCount: 56,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    resetGlobals();
  });

  tearDown(() {
    restoreHttp();
    resetGlobals();
  });

  group('文章總覽', () {
    Future<void> pumpSection(WidgetTester tester, {bool senior = false}) async {
      installMockClient({
        '/api/articles': {
          'total': 4,
          'page': 1,
          'page_size': 20,
          'sort': 'latest',
          'articles': [
            _article(1, summary: '摘要 1'),
            _article(2, summary: '摘要 2'),
            _article(3), // 沒有摘要
            _article(4, summary: '   '), // 只有空白也算沒有摘要
          ],
        },
      });
      usePhoneSurface(tester, size: const Size(414, 3000));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CultureArticleSection(seniorMode: senior),
            ),
          ),
        ),
      );
      await pumpFrames(tester, times: 10);
    }

    testWidgets('每一篇（含第一篇）都是大圖卡，看不到閱讀數', (tester) async {
      await pumpSection(tester);

      expect(find.byType(CultureCoverCard), findsNWidgets(4));
      expect(find.text('摘要 2'), findsOneWidget);
      expect(find.text('這篇文章還沒有摘要，點進去看看內容吧'), findsNWidgets(2));
      expect(find.textContaining('閱讀'), findsNothing);
      expect(find.textContaining('1234'), findsNothing);
      // 排序字「本週熱門」也含「本週」，改用本週次數本身判斷。
      expect(find.textContaining('56'), findsNothing);
    });

    testWidgets('精簡模式標題在封面下方、不顯示摘要', (tester) async {
      await pumpSection(tester, senior: true);

      expect(find.byType(CultureCoverCard), findsNWidgets(4));
      expect(find.text('文章 2'), findsOneWidget);
      expect(find.text('摘要 1'), findsNothing);
      expect(find.text('摘要 2'), findsNothing);
    });
  });

  group('影音總覽卡', () {
    Future<void> pumpCard(
      WidgetTester tester,
      VideoSummary video, {
      bool senior = false,
    }) async {
      usePhoneSurface(tester, size: const Size(320, 800));
      await tester.pumpWidget(
        wrap(
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CultureVideoCard(video: video, seniorMode: senior),
            ),
          ),
        ),
      );
    }

    testWidgets('精簡模式標題在封面下方、不顯示簡介，片長仍在封面右下', (tester) async {
      await pumpCard(
        tester,
        _video(
          title: '太魯閣族傳統織布與苧麻工藝體驗暨部落長者口述歷史分享會',
          description: '這是影片簡介',
          durationSec: 725,
        ),
        senior: true,
      );

      final cover = tester.getRect(find.byType(AspectRatio));
      expect(cover.width / cover.height, closeTo(16 / 9, 0.01));
      final title = tester.getRect(find.textContaining('太魯閣族傳統織布'));
      expect(title.top, greaterThanOrEqualTo(cover.bottom));
      expect(find.text('這是影片簡介'), findsNothing);
      final badge = tester.getRect(find.text('12:05'));
      expect(cover.contains(badge.center), isTrue);
      expect(badge.right, greaterThan(cover.center.dx));
      expect(badge.bottom, greaterThan(cover.center.dy));
      expect(find.textContaining('觀看'), findsNothing);
    });

    testWidgets('大圖卡顯示簡介與片長，看不到觀看數', (tester) async {
      await pumpCard(tester, _video(description: '這是影片簡介', durationSec: 725));

      expect(find.byType(CultureCoverCard), findsOneWidget);
      expect(find.text('這是影片簡介'), findsOneWidget);
      expect(find.text('12:05'), findsOneWidget);
      expect(find.textContaining('觀看'), findsNothing);
      expect(find.textContaining('1234'), findsNothing);
      expect(find.textContaining('56'), findsNothing);
    });

    testWidgets('封面是 16:9，片長角標在右下', (tester) async {
      await pumpCard(tester, _video(durationSec: 725));

      final cover = tester.getRect(find.byType(AspectRatio));
      expect(cover.width / cover.height, closeTo(16 / 9, 0.01));
      final badge = tester.getRect(find.text('12:05'));
      expect(badge.right, greaterThan(cover.center.dx));
      expect(badge.bottom, greaterThan(cover.center.dy));
    });

    testWidgets('一般模式標題排在封面下方、簡介之上，不疊在縮圖上', (tester) async {
      await pumpCard(
        tester,
        _video(
          durationSec: 725,
          title: '太魯閣族傳統織布與苧麻工藝體驗暨部落長者口述歷史分享會',
          description: '這是影片簡介',
        ),
      );

      final cover = tester.getRect(find.byType(AspectRatio));
      final title = tester.getRect(find.textContaining('太魯閣族傳統織布'));
      final summary = tester.getRect(find.text('這是影片簡介'));
      expect(title.top, greaterThanOrEqualTo(cover.bottom));
      expect(summary.top, greaterThanOrEqualTo(title.bottom));
    });

    testWidgets('沒有簡介時仍顯示封面下方的標題', (tester) async {
      await pumpCard(tester, _video(title: '織布影片', description: ''));

      final cover = tester.getRect(find.byType(AspectRatio));
      final title = tester.getRect(find.text('織布影片'));
      expect(title.top, greaterThanOrEqualTo(cover.bottom));
    });

    testWidgets('YouTube 影片沒有片長時標「YouTube」', (tester) async {
      await pumpCard(tester, _video(source: VideoSource.youtube));
      expect(find.text('YouTube'), findsOneWidget);
    });

    testWidgets('沒有簡介時整列省略', (tester) async {
      await pumpCard(tester, _video(description: '  '));
      expect(find.byType(CultureArrowIcon), findsNothing);
    });
  });
}
