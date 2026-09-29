// 管理員在既有畫面（貼文詳情、留言）上的入口：只有管理員看得到，流程含理由與二次確認。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/screens/admin/widgets/admin_reason_dialog.dart';
import 'package:flutter_application_1/screens/forum/forum_detail_screen.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../../helpers/widget_test_helpers.dart';

Map<String, dynamic> _author(String friendCode) => {
  'uid': 2,
  'display_name': '作者',
  'friend_code': friendCode,
};

Map<String, dynamic> _post({bool pinned = false, String author = 'OTHER123'}) =>
    {
      'post': {
        'id': 7,
        'board': {'id': 1, 'slug': 'general', 'name': '綜合'},
        'title': '貼文標題',
        'body': '貼文內文',
        'like_count': 0,
        'comment_count': 1,
        'is_pinned': pinned,
        'is_liked': false,
        'is_bookmarked': false,
        'images': <String>[],
        'tags': <Object>[],
        'created_at': '2026-09-25T15:01:15.985Z',
        'updated_at': '2026-09-25T15:01:15.985Z',
        'author': _author(author),
      },
    };

final _comments = {
  'comments': [
    {
      'id': 70,
      'post_id': 7,
      'parent_comment_id': null,
      'body': '一則留言',
      'is_deleted': false,
      'like_count': 0,
      'is_liked': false,
      'created_at': '2026-09-25T16:00:00.000Z',
      'author': _author('OTHER123'),
    },
  ],
  'replies': <Object>[],
  'page_info': {'next_cursor': null, 'has_more': false},
};

void _login(String role) {
  UserService.currentUid = 1;
  UserService.cacheUser(
    UserModel(
      uid: 1,
      email: '',
      createdAt: DateTime(2026),
      friendCode: 'ADMIN001',
      role: role,
    ),
  );
}

Widget _app({List<Object?>? popped}) => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () async {
          final result = await Navigator.of(
            context,
          ).push(ForumDetailScreen.route(postId: 7));
          popped?.add(result);
        },
        child: const Text('開貼文'),
      ),
    ),
  ),
);

Future<void> _openPost(WidgetTester tester) async {
  await tester.tap(find.text('開貼文'));
  await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
}

/// 填理由 → 下一步 → 確認框按主按鈕。
Future<void> _fillReasonAndConfirm(
  WidgetTester tester,
  String confirmText,
) async {
  await tester.enterText(find.byType(TextField).last, '廣告洗版');
  await tester.pump();
  await tester.tap(find.text('下一步'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(confirmText).last);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    restoreHttp();
    UserService.clearCache();
  });

  void mockForum({
    bool pinned = false,
    Map<String, Object?> extra = const {},
    void Function(String path, Map<String, dynamic> body)? onWrite,
  }) {
    installMockClient(
      {
        '/api/forum/posts/7': _post(pinned: pinned),
        '/api/forum/posts/7/comments': _comments,
        '/api/shop/items': {'items': <Object>[]},
        ...extra,
      },
      onRequest: (r) {
        if (r.method == 'POST') {
          onWrite?.call(r.url.path, jsonDecode(r.body) as Map<String, dynamic>);
        }
      },
    );
  }

  testWidgets('一般使用者：選單只有檢舉，沒有置頂與管理員下架', (tester) async {
    _login('user');
    mockForum();
    await tester.pumpWidget(_app());
    await _openPost(tester);
    await _openMenu(tester);

    expect(find.byType(PopupMenuItem<String>), findsOneWidget);
    expect(find.text('置頂'), findsNothing);
    expect(find.text('管理員下架'), findsNothing);
  });

  testWidgets('管理員：貼文與留言都有管理員下架；置頂依 is_pinned 切換', (tester) async {
    _login('admin');
    mockForum(pinned: true);
    await tester.pumpWidget(_app());
    await _openPost(tester);

    expect(find.text('管理員下架'), findsOneWidget, reason: '留言旁的入口');
    await _openMenu(tester);
    expect(find.text('取消置頂'), findsOneWidget);
    expect(find.text('管理員下架'), findsNWidgets(2), reason: '選單裡另有一個');
  });

  testWidgets('置頂：成功後選單文字切換並提示', (tester) async {
    _login('admin');
    Map<String, dynamic>? sent;
    mockForum(
      extra: {
        '/api/admin/forum/posts/7/pin': {'id': 7, 'is_pinned': true},
      },
      onWrite: (_, body) => sent = body,
    );
    await tester.pumpWidget(_app());
    await _openPost(tester);

    await _openMenu(tester);
    await tester.tap(find.text('置頂'));
    await tester.pumpAndSettle();

    expect(sent, {'pinned': true});
    expect(find.text('已置頂'), findsOneWidget);
    await _openMenu(tester);
    expect(find.text('取消置頂'), findsOneWidget);
  });

  testWidgets('自己的貼文：管理員選單有置頂，沒有管理員下架', (tester) async {
    _login('admin');
    installMockClient({
      '/api/forum/posts/7': _post(author: 'ADMIN001'),
      '/api/forum/posts/7/comments': {
        'comments': <Object>[],
        'replies': <Object>[],
      },
      '/api/shop/items': {'items': <Object>[]},
    });
    await tester.pumpWidget(_app());
    await _openPost(tester);
    await _openMenu(tester);

    expect(find.text('置頂'), findsOneWidget);
    expect(find.text('管理員下架'), findsNothing);
    expect(find.text('刪除'), findsOneWidget);
  });

  testWidgets('下架貼文：理由必填、二次確認、成功後關閉詳情並回報已刪除', (tester) async {
    _login('admin');
    final popped = <Object?>[];
    Map<String, dynamic>? sent;
    mockForum(
      extra: {
        '/api/admin/forum/posts/7/remove': {
          'case': {'id': 1},
          'auto_closed_report_ids': <int>[],
        },
      },
      onWrite: (_, body) => sent = body,
    );
    await tester.pumpWidget(_app(popped: popped));
    await _openPost(tester);

    await _openMenu(tester);
    await tester.tap(find.text('管理員下架').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '下一步'))
          .onPressed,
      isNull,
      reason: '沒填理由不能送出',
    );
    await _fillReasonAndConfirm(tester, '下架');

    expect(sent, {'reason': '廣告洗版'});
    expect(find.text('已下架，等待其他管理員二審'), findsOneWidget);
    expect(popped.single, isA<ForumDetailResult>());
    expect((popped.single as ForumDetailResult).deleted, isTrue);
  });

  testWidgets('下架留言：換成「留言已被刪除」佔位', (tester) async {
    _login('admin');
    mockForum(
      extra: {
        '/api/admin/forum/comments/70/remove': {
          'case': {'id': 2},
          'auto_closed_report_ids': <int>[],
        },
      },
    );
    await tester.pumpWidget(_app());
    await _openPost(tester);

    await tester.tap(find.text('管理員下架'));
    await tester.pumpAndSettle();
    await _fillReasonAndConfirm(tester, '下架');

    expect(find.text('留言已被刪除'), findsOneWidget);
    expect(find.text('一則留言'), findsNothing);
    expect(find.text('已下架，等待其他管理員二審'), findsOneWidget);
  });

  testWidgets('CASE_ALREADY_OPEN：顯示後端訊息，貼文仍在', (tester) async {
    _login('admin');
    mockForum(
      extra: {
        '/api/admin/forum/comments/70/remove': errorResponse(
          'CASE_ALREADY_OPEN',
          status: 409,
          message: '這則內容已有待審或已確認的案件',
        ),
      },
    );
    await tester.pumpWidget(_app());
    await _openPost(tester);

    await tester.tap(find.text('管理員下架'));
    await tester.pumpAndSettle();
    await _fillReasonAndConfirm(tester, '下架');

    expect(find.text('這則內容已有待審或已確認的案件'), findsOneWidget);
    expect(find.text('一則留言'), findsOneWidget);
  });

  group('理由對話框', () {
    /// 只負責把對話框開起來，後續互動由各測試自己做。
    Future<void> open(
      WidgetTester tester, {
      bool required = true,
      bool profileFields = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => promptAdminReason(
                  context,
                  title: '標題',
                  description: '說明',
                  confirmMessage: '確認？',
                  confirmText: '執行',
                  required: required,
                  profileFields: profileFields,
                ),
                child: const Text('開'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開'));
      await tester.pumpAndSettle();
    }

    testWidgets('超過 500 字的理由不送出', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), '先輸入一個字啟用按鈕');
      await tester.pump();
      // formatter 會截斷輸入；直接寫 controller 模擬輸入法組字中放行的超長內容。
      tester.widget<TextField>(find.byType(TextField)).controller!.text =
          '字' * 501;
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      expect(find.textContaining('理由不能超過 500 字'), findsOneWidget);
      expect(find.text('確認？'), findsNothing, reason: '沒進到二次確認');
    });

    testWidgets('選填模式：可留空直接下一步；勾選欄位全清時擋下', (tester) async {
      await open(tester, required: false, profileFields: true);
      TextButton next() =>
          tester.widget<TextButton>(find.widgetWithText(TextButton, '下一步'));

      expect(next().onPressed, isNotNull);
      for (final label in ['暱稱', '自我介紹', '頭像']) {
        await tester.tap(find.text(label));
      }
      await tester.pump();
      expect(next().onPressed, isNull);
    });
  });
}
