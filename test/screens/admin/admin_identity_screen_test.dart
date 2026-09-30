// 更正族群／部落：查人後預帶目前身分，選新身分、填理由、確認後整組送出。
// PATCH 回應依 內部管理.md §8.10 手寫（錄製會真的改資料）。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/admin/admin_identity_screen.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

Widget _app() => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: const AdminIdentityScreen(),
);

Map<String, dynamic> _lookup({
  bool isIndigenous = true,
  String? ethnicGroup = '太魯閣族',
  int? tribeId = 5,
  String? tribeName = '富世',
}) => {
  'user': {
    'uid': 12,
    'friend_code': 'ABCD2345',
    'nickname': '阿華',
    'status': 'active',
    'role': 'user',
    'is_indigenous': isIndigenous,
    'ethnic_group': ethnicGroup,
    'tribe_id': tribeId,
    'tribe_name': tribeName,
  },
};

Map<String, dynamic> _tribe(int id, String name) => {
  'id': id,
  'ethnic_group': '太魯閣族',
  'name': name,
  'name_truku': name,
  'county': '花蓮縣',
  'township': '秀林鄉',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  List<http.Request> install({
    Map<String, dynamic>? lookup,
    http.Response Function(http.Request)? patch,
  }) {
    final requests = <http.Request>[];
    ApiClient.httpClient = MockClient((r) async {
      requests.add(r);
      if (r.method == 'PATCH') {
        return patch?.call(r) ??
            jsonResponse(
              loadSpecFixtureMap('patch_api_admin_user_identity.json'),
            );
      }
      return switch (r.url.path) {
        '/api/ethnic-groups' => jsonResponse({
          'ethnic_groups': [
            {'ethnic_group': '太魯閣族', 'tribe_count': 2},
          ],
        }),
        '/api/tribes' => jsonResponse({
          'tribes': [_tribe(5, '富世'), _tribe(6, '秀林')],
        }),
        _ => jsonResponse(lookup ?? _lookup()),
      };
    });
    return requests;
  }

  Future<void> lookUp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.enterText(find.byType(TextField), 'abcd2345');
    await tester.tap(find.text('查詢'));
    await tester.pumpAndSettle();
  }

  Future<void> submit(
    WidgetTester tester, {
    String reason = '使用者來信說選錯部落',
  }) async {
    await tester.tap(find.text('送出更正'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, reason);
    await tester.pump();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
  }

  http.Request patchOf(List<http.Request> requests) =>
      requests.singleWhere((r) => r.method == 'PATCH');

  testWidgets('查人後顯示對方目前的原住民身分、族群、部落', (tester) async {
    install();
    await lookUp(tester);

    expect(find.textContaining('原住民', findRichText: true), findsWidgets);
    expect(find.textContaining('目前的族群', findRichText: true), findsOneWidget);
    expect(find.textContaining('富世', findRichText: true), findsWidgets);
  });

  testWidgets('換部落：部落選單只查所選族群，整組送出 uid、族群、部落與理由', (tester) async {
    final requests = install();
    await lookUp(tester);

    await tester.tap(find.text('部落：富世'));
    await tester.pumpAndSettle();
    expect(
      requests
          .lastWhere((r) => r.url.path == '/api/tribes')
          .url
          .queryParameters,
      {'ethnic_group': '太魯閣族'},
    );
    await tester.tap(find.text('秀林'));
    await tester.pumpAndSettle();

    await submit(tester);
    expect(find.textContaining('太魯閣族・秀林'), findsOneWidget);
    await tester.tap(find.text('更正'));
    await tester.pumpAndSettle();

    final patch = patchOf(requests);
    expect(patch.url.path, '/api/admin/users/12/identity');
    expect(jsonDecode(patch.body), {
      'is_indigenous': true,
      'ethnic_group': '太魯閣族',
      'tribe_id': 6,
      'reason': '使用者來信說選錯部落',
    });
    expect(find.textContaining('已更正「阿華」的族群／部落'), findsOneWidget);
  });

  testWidgets('改成非原住民：不顯示族群與部落，確認框寫明會一起清空，只送身分與理由', (tester) async {
    final requests = install(
      patch: (_) => jsonResponse({
        'uid': 12,
        'is_indigenous': false,
        'ethnic_group': null,
        'tribe_id': null,
        'tribal_name': null,
      }),
    );
    await lookUp(tester);

    await tester.tap(find.text('非原住民'));
    await tester.pumpAndSettle();
    expect(find.text('部落：富世'), findsNothing);
    expect(find.text('族群'), findsNothing);

    await submit(tester, reason: '誤選');
    expect(find.textContaining('族群、部落、族語名會一起清空'), findsWidgets);
    await tester.tap(find.text('更正'));
    await tester.pumpAndSettle();

    expect(jsonDecode(patchOf(requests).body), {
      'is_indigenous': false,
      'reason': '誤選',
    });
    // 更正後的身分。
    expect(find.textContaining('非原住民', findRichText: true), findsWidgets);
    expect(find.textContaining('目前的族群', findRichText: true), findsNothing);
  });

  testWidgets('原本是非原住民、改成原住民：沒選部落不能送出', (tester) async {
    install(
      lookup: _lookup(
        isIndigenous: false,
        ethnicGroup: null,
        tribeId: null,
        tribeName: null,
      ),
    );
    await lookUp(tester);

    await tester.tap(find.text('原住民'));
    await tester.pumpAndSettle();

    expect(find.text('選擇部落'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '送出更正'))
          .onPressed,
      isNull,
    );
  });

  for (final (status, code) in [
    (400, 'INVALID_REQUEST'),
    (404, 'USER_NOT_FOUND'),
  ]) {
    testWidgets('$status $code：顯示後端 message', (tester) async {
      install(
        patch: (_) =>
            errorResponse(code, status: status, message: '後端說明：$code'),
      );
      await lookUp(tester);
      await submit(tester);
      await tester.tap(find.text('更正'));
      await tester.pumpAndSettle();

      expect(find.text('後端說明：$code'), findsOneWidget);
    });
  }
}
