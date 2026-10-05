// 文章表單、文章詳情的管理員操作、發布條款。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/models/article_models.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/screens/admin/admin_article_form_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_error.dart';
import 'package:flutter_application_1/screens/admin/admin_terms_publish_screen.dart';
import 'package:flutter_application_1/screens/culture/article_detail_screen.dart';
import 'package:flutter_application_1/services/admin_service.dart';
import 'package:flutter_application_1/services/article_refresh_notifier.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../../helpers/widget_test_helpers.dart';

Widget _host(Widget Function() screen, List<Object?> result) => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () async =>
            result.add(await pushAdmin<bool>(context, screen())),
        child: const Text('開啟'),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('開啟'));
  await tester.pumpAndSettle();
}

/// 表單是 lazy ListView，預設視窗放不下所有欄位；拉高才找得到下方的欄位。
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void _login(String role) {
  UserService.currentUid = 1;
  UserService.cacheUser(
    UserModel(uid: 1, email: '', createdAt: DateTime(2026), role: role),
  );
}

final _article = {
  'id': 1,
  'title': '太魯閣族的織布',
  'category': 'cultural',
  'content_md': '# 織布\n\n這是內文。',
  'summary': '關於織布的故事',
  'cover_image_url': 'https://example.com/cover.jpg',
  'like_count': 1,
  'is_liked': false,
  'is_bookmarked': false,
  'view_count': 10,
  'published_at': '2026-09-01T00:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    restoreHttp();
    UserService.clearCache();
  });

  group('AdminService 文章與條款', () {
    test('createArticle：發布一次帶 status=published、空欄位不送；草稿為 draft', () async {
      final bodies = <Map<String, dynamic>>[];
      installMockClient(
        {
          '/api/admin/articles': {'id': 5},
        },
        onRequest: (r) =>
            bodies.add(jsonDecode(r.body) as Map<String, dynamic>),
      );

      final id = await AdminService.createArticle(
        title: ' 標題 ',
        category: 'cultural',
        contentMd: '內文',
        summary: '  ',
        coverImageUrl: 'https://x/y.jpg',
        tribeId: 3,
        publish: true,
      );
      await AdminService.createArticle(
        title: 't',
        category: 'other',
        contentMd: 'c',
        publish: false,
      );

      expect(id, 5);
      expect(bodies[0], {
        'title': '標題',
        'category': 'cultural',
        'content_md': '內文',
        'cover_image_url': 'https://x/y.jpg',
        'tribe_id': 3,
        'status': 'published',
      });
      expect(bodies[1]['status'], 'draft');
    });

    test('updateArticle／publish／archive／publishTerms 的端點與 body', () async {
      final calls = <String, Object?>{};
      installMockClient(
        {
          '/api/admin/articles/2': {'id': 2},
          '/api/admin/articles/2/publish': {'id': 2},
          '/api/admin/articles/2/archive': {'id': 2},
          '/api/admin/terms': {'id': 1, 'version': 8},
        },
        onRequest: (r) => calls['${r.method} ${r.url.path}'] = r.body.isEmpty
            ? null
            : jsonDecode(r.body),
      );

      await AdminService.updateArticle(2, {'summary': null, 'title': 'x'});
      await AdminService.publishArticle(2);
      await AdminService.archiveArticle(2);
      final version = await AdminService.publishTerms('tos', ' 標題 ', ' 全文 ');

      expect(calls['PATCH /api/admin/articles/2'], {
        'summary': null,
        'title': 'x',
      });
      expect(calls.containsKey('POST /api/admin/articles/2/publish'), isTrue);
      expect(calls.containsKey('POST /api/admin/articles/2/archive'), isTrue);
      expect(calls['POST /api/admin/terms'], {
        'doc_type': 'tos',
        'title': '標題',
        'content_md': '全文',
      });
      expect(version, 8);
    });
  });

  group('文章表單', () {
    void mockCreate({
      void Function(Map<String, dynamic>)? onBody,
      Object? response,
    }) {
      installMockClient(
        {
          '/api/tribes': {'tribes': <Object>[]},
          '/api/admin/articles': response ?? {'id': 9},
        },
        onRequest: (r) {
          if (r.method == 'POST') {
            onBody?.call(jsonDecode(r.body) as Map<String, dynamic>);
          }
        },
      );
    }

    testWidgets('標題與內文必填；封面只收 https；顯示需先上傳的說明', (tester) async {
      _tall(tester);
      var posts = 0;
      mockCreate(onBody: (_) => posts++);
      await tester.pumpWidget(
        _host(() => const AdminArticleFormScreen(), <Object?>[]),
      );
      await _open(tester);
      expect(find.text('需先上傳到雲端儲存'), findsOneWidget);

      await tester.tap(find.text('發布'));
      await tester.pumpAndSettle();
      expect(find.text('標題必填'), findsOneWidget);
      expect(find.text('內文必填'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '標題（必填）'), '標題');
      await tester.enterText(
        find.widgetWithText(TextField, '內文（Markdown，必填）'),
        '內文',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '封面圖網址'),
        'http://x/y.jpg',
      );
      await tester.tap(find.text('發布'));
      await tester.pumpAndSettle();
      expect(find.text('封面網址必須以 https:// 開頭'), findsOneWidget);
      expect(posts, 0, reason: '驗證沒過不送出');
    });

    testWidgets('發布：一次呼叫、成功後關閉並回報變動', (tester) async {
      _tall(tester);
      final result = <Object?>[];
      Map<String, dynamic>? sent;
      mockCreate(onBody: (b) => sent = b);
      await tester.pumpWidget(
        _host(() => const AdminArticleFormScreen(), result),
      );
      await _open(tester);
      final revision = ArticleRefreshNotifier.revision.value;

      await tester.enterText(find.widgetWithText(TextField, '標題（必填）'), '新文章');
      await tester.enterText(
        find.widgetWithText(TextField, '內文（Markdown，必填）'),
        '# 內文',
      );
      await tester.tap(find.text('發布'));
      await tester.pumpAndSettle();

      expect(ArticleRefreshNotifier.revision.value, revision + 1);
      expect(sent?['status'], 'published');
      expect(sent?['category'], 'tribal_intro');
      expect(find.text('已發布'), findsOneWidget);
      expect(result, [true]);
    });

    testWidgets('存草稿：先提示無法在 App 內找回，確認後才送出', (tester) async {
      _tall(tester);
      Map<String, dynamic>? sent;
      mockCreate(onBody: (b) => sent = b);
      await tester.pumpWidget(
        _host(() => const AdminArticleFormScreen(), <Object?>[]),
      );
      await _open(tester);
      await tester.enterText(find.widgetWithText(TextField, '標題（必填）'), 't');
      await tester.enterText(
        find.widgetWithText(TextField, '內文（Markdown，必填）'),
        'c',
      );

      await tester.tap(find.text('存草稿'));
      await tester.pumpAndSettle();
      expect(find.textContaining('草稿目前無法在 App 內找回'), findsOneWidget);
      expect(sent, isNull);

      await tester.tap(find.text('存草稿').last);
      await tester.pumpAndSettle();
      expect(sent?['status'], 'draft');
    });

    testWidgets('後端 400：顯示 message，留在表單', (tester) async {
      _tall(tester);
      mockCreate(
        response: errorResponse(
          'INVALID_CATEGORY',
          status: 400,
          message: 'category 不合法',
        ),
      );
      await tester.pumpWidget(
        _host(() => const AdminArticleFormScreen(), <Object?>[]),
      );
      await _open(tester);
      await tester.enterText(find.widgetWithText(TextField, '標題（必填）'), 't');
      await tester.enterText(
        find.widgetWithText(TextField, '內文（Markdown，必填）'),
        'c',
      );

      await tester.tap(find.text('發布'));
      await tester.pumpAndSettle();

      expect(find.text('category 不合法'), findsOneWidget);
      expect(find.text('新增文章'), findsOneWidget);
    });

    testWidgets('預覽用文章頁的 Markdown 樣式渲染', (tester) async {
      _tall(tester);
      mockCreate();
      await tester.pumpWidget(
        _host(() => const AdminArticleFormScreen(), <Object?>[]),
      );
      await _open(tester);
      await tester.enterText(find.widgetWithText(TextField, '標題（必填）'), '預覽標題');
      await tester.enterText(
        find.widgetWithText(TextField, '內文（Markdown，必填）'),
        '## 小標\n\n**粗體**內文',
      );

      await tester.tap(find.byTooltip('預覽'));
      await tester.pumpAndSettle();

      expect(find.text('預覽標題'), findsOneWidget);
      expect(find.text('小標'), findsOneWidget, reason: 'Markdown 標題已渲染成文字');
      expect(find.textContaining('## 小標'), findsNothing);
    });

    testWidgets('編輯：帶入原值，只送有改的欄位，清空封面送 null', (tester) async {
      _tall(tester);
      final result = <Object?>[];
      Map<String, dynamic>? sent;
      installMockClient({
        '/api/admin/articles/1': {'id': 1},
      }, onRequest: (r) => sent = jsonDecode(r.body) as Map<String, dynamic>);
      await tester.pumpWidget(
        _host(
          () =>
              AdminArticleFormScreen(editing: ArticleDetail.fromJson(_article)),
          result,
        ),
      );
      await _open(tester);
      expect(find.text('編輯文章'), findsOneWidget);
      expect(find.text('太魯閣族的織布'), findsOneWidget);
      expect(find.text('作者'), findsNothing, reason: '編輯模式不顯示作者與部落標籤');

      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();
      expect(sent, isNull, reason: '沒改任何欄位不送出');
      expect(find.text('沒有變更'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '標題（必填）'), '新標題');
      await tester.enterText(find.widgetWithText(TextField, '封面圖網址'), '');
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      expect(sent, {'title': '新標題', 'cover_image_url': null});
      expect(result, [true]);
    });
  });

  group('文章詳情的管理員操作', () {
    void mockDetail({void Function(String)? onCall}) {
      installMockClient({
        '/api/articles/1': _article,
        '/api/admin/articles/1/archive': {'id': 1},
        '/api/admin/articles/1/publish': {'id': 1},
      }, onRequest: (r) => onCall?.call('${r.method} ${r.url.path}'));
    }

    Future<void> openDetail(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<bool>(
                    builder: (_) => const ArticleDetailScreen(articleId: 1),
                  ),
                ),
                child: const Text('開文章'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開文章'));
      await tester.pumpAndSettle();
    }

    testWidgets('一般使用者沒有編輯／下架選單', (tester) async {
      _login('user');
      mockDetail();
      await openDetail(tester);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('管理員：選單有編輯與下架', (tester) async {
      _login('admin');
      mockDetail();
      await openDetail(tester);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('編輯'), findsOneWidget);
      expect(find.text('下架'), findsOneWidget);
    });

    testWidgets('下架：二次確認並提示找不回、成功後關閉詳情並通知列表重抓；可復原', (tester) async {
      _login('admin');
      final calls = <String>[];
      mockDetail(onCall: calls.add);
      final revision = ArticleRefreshNotifier.revision.value;
      await openDetail(tester);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('下架'));
      await tester.pumpAndSettle();
      expect(find.textContaining('無法在 App 內找回'), findsOneWidget);
      await tester.tap(find.text('下架').last);
      await tester.pumpAndSettle();

      expect(calls, contains('POST /api/admin/articles/1/archive'));
      expect(find.text('開文章'), findsOneWidget, reason: '詳情頁已關閉');
      expect(ArticleRefreshNotifier.revision.value, revision + 1);

      await tester.tap(find.text('復原'));
      await tester.pumpAndSettle();
      expect(calls, contains('POST /api/admin/articles/1/publish'));
      expect(find.text('已重新發布'), findsOneWidget);
      expect(ArticleRefreshNotifier.revision.value, revision + 2);
    });
    testWidgets('下架送出中：管理員選單停用，連點只送一次', (tester) async {
      _login('admin');
      final calls = <String>[];
      installMockClient(
        {
          '/api/articles/1': _article,
          '/api/admin/articles/1/archive': {'id': 1},
        },
        onRequest: (r) => calls.add('${r.method} ${r.url.path}'),
        delayFor: (r) =>
            r.method == 'POST' ? const Duration(seconds: 1) : Duration.zero,
      );
      await openDetail(tester);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('下架'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('下架').last);
      await tester.pump();

      expect(
        tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .enabled,
        isFalse,
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pump();
      expect(find.text('編輯'), findsNothing, reason: '停用時點了不會開選單');

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
        calls.where((c) => c == 'POST /api/admin/articles/1/archive'),
        hasLength(1),
      );
      expect(find.text('開文章'), findsOneWidget, reason: '成功後照舊關閉詳情');
    });
  });

  group('發布條款', () {
    Map<String, dynamic> doc(String type, int version, String title) => {
      'document': {
        'doc_type': type,
        'version': version,
        'title': title,
        'content_md': '舊全文',
        'published_at': '2026-09-01T00:00:00Z',
        'consented': true,
        'consented_version': version,
      },
      'all_consented': true,
    };

    testWidgets('標題帶入目前版本；選隱私權政策會換成該份的標題', (tester) async {
      installMockClient({
        '/api/terms/tos': doc('tos', 4, '服務條款'),
        '/api/terms/privacy': doc('privacy', 7, '隱私權政策'),
      });
      await tester.pumpWidget(
        _host(() => const AdminTermsPublishScreen(), <Object?>[]),
      );
      await _open(tester);
      expect(find.widgetWithText(TextField, '服務條款'), findsOneWidget);

      await tester.tap(find.text('隱私權政策'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '隱私權政策'), findsOneWidget);
    });

    testWidgets('發布前明寫要重新同意；成功後顯示新版本號', (tester) async {
      Map<String, dynamic>? sent;
      installMockClient(
        {
          '/api/terms/tos': doc('tos', 4, '服務條款'),
          '/api/admin/terms': {'id': 1, 'doc_type': 'tos', 'version': 5},
        },
        onRequest: (r) {
          if (r.method == 'POST') {
            sent = jsonDecode(r.body) as Map<String, dynamic>;
          }
        },
      );
      final result = <Object?>[];
      await tester.pumpWidget(
        _host(() => const AdminTermsPublishScreen(), result),
      );
      await _open(tester);
      await tester.enterText(
        find.widgetWithText(TextField, '全文（Markdown，貼上）'),
        '# 新條款',
      );

      await tester.tap(find.text('發布'));
      await tester.pumpAndSettle();
      expect(find.textContaining('所有使用者下次使用都要重新同意'), findsOneWidget);
      expect(sent, isNull, reason: '確認前不送出');
      await tester.tap(find.text('發布').last);
      await tester.pumpAndSettle();

      expect(sent, {'doc_type': 'tos', 'title': '服務條款', 'content_md': '# 新條款'});
      expect(find.textContaining('第 5 版'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      expect(result, [true]);
    });

    testWidgets('該類型尚未發布（TERMS_NOT_FOUND）：標題留空、預覽顯示第 1 版', (tester) async {
      installMockClient({
        '/api/terms/tos': errorResponse(
          'TERMS_NOT_FOUND',
          status: 404,
          message: '尚未發布',
        ),
      });
      await tester.pumpWidget(
        _host(() => const AdminTermsPublishScreen(), <Object?>[]),
      );
      await _open(tester);
      await tester.enterText(find.widgetWithText(TextField, '標題'), '新標題');
      await tester.enterText(
        find.widgetWithText(TextField, '全文（Markdown，貼上）'),
        '內容',
      );

      await tester.tap(find.byTooltip('預覽'));
      await tester.pumpAndSettle();

      expect(find.text('第 1 版'), findsOneWidget);
    });

    testWidgets('讀目前版本失敗（非 404）：確認框不寫推算的版本號，可重試', (tester) async {
      var gets = 0;
      installMockClient({
        '/api/terms/tos': errorResponse('INTERNAL', status: 500),
      }, onRequest: (_) => gets++);
      await tester.pumpWidget(
        _host(() => const AdminTermsPublishScreen(), <Object?>[]),
      );
      await _open(tester);
      expect(find.textContaining('讀取目前版本失敗'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '標題'), '自填標題');
      await tester.enterText(
        find.widgetWithText(TextField, '全文（Markdown，貼上）'),
        '內容',
      );
      await tester.tap(find.text('發布'));
      await tester.pumpAndSettle();
      expect(find.textContaining('版本號會自動遞增'), findsOneWidget);
      expect(find.textContaining('第 1 版'), findsNothing);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      installMockClient({
        '/api/terms/tos': doc('tos', 4, '服務條款'),
      }, onRequest: (_) => gets++);
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      expect(gets, 2);
      expect(find.textContaining('讀取目前版本失敗'), findsNothing);
      expect(
        find.widgetWithText(TextField, '自填標題'),
        findsOneWidget,
        reason: '重試不覆寫已填的標題',
      );
      await tester.tap(find.text('發布'));
      await tester.pumpAndSettle();
      expect(find.textContaining('第 5 版'), findsOneWidget);
    });

    testWidgets('讀目前版本失敗（非 404）：預覽不顯示推算的版本號', (tester) async {
      installMockClient({
        '/api/terms/tos': errorResponse('INTERNAL', status: 500),
      });
      await tester.pumpWidget(
        _host(() => const AdminTermsPublishScreen(), <Object?>[]),
      );
      await _open(tester);
      await tester.enterText(find.widgetWithText(TextField, '標題'), '新標題');
      await tester.enterText(
        find.widgetWithText(TextField, '全文（Markdown，貼上）'),
        '內容',
      );

      await tester.tap(find.byTooltip('預覽'));
      await tester.pumpAndSettle();

      expect(find.text('新標題'), findsOneWidget);
      expect(find.textContaining(RegExp(r'第 \d+ 版')), findsNothing);
    });

    testWidgets('讀取目前版本中：標題欄不可輸入', (tester) async {
      installMockClient({
        '/api/terms/tos': doc('tos', 4, '服務條款'),
      }, delayFor: (_) => const Duration(seconds: 1));
      await tester.pumpWidget(
        _host(() => const AdminTermsPublishScreen(), <Object?>[]),
      );
      await tester.tap(find.text('開啟'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      TextField title() => tester.widget<TextField>(
        find.ancestor(of: find.text('標題'), matching: find.byType(TextField)),
      );
      expect(title().enabled, isFalse);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(title().enabled, isTrue);
    });

    testWidgets('400：顯示後端 message，留在畫面', (tester) async {
      installMockClient({
        '/api/terms/tos': doc('tos', 4, '服務條款'),
        '/api/admin/terms': errorResponse(
          'INVALID_REQUEST',
          status: 400,
          message: 'content_md 必填',
        ),
      });
      await tester.pumpWidget(
        _host(() => const AdminTermsPublishScreen(), <Object?>[]),
      );
      await _open(tester);
      await tester.enterText(
        find.widgetWithText(TextField, '全文（Markdown，貼上）'),
        '內容',
      );

      await tester.tap(find.text('發布'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('發布').last);
      await tester.pumpAndSettle();

      expect(find.text('content_md 必填'), findsOneWidget);
      expect(find.text('發布條款'), findsOneWidget);
    });
  });
}
