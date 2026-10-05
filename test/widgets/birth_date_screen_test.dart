// 舊使用者補填出生日期（POL-01）：送出後依條款狀態接續、已填過直接放行、
// 不合法顯示後端訊息、不能返回。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/screens/auth/birth_date_screen.dart';
import 'package:flutter_application_1/services/user_service.dart';
import 'package:flutter_application_1/shared/widgets/confirm_dialog.dart';

import '../helpers/birth_date_test_helpers.dart';
import '../helpers/fixtures.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    restoreHttp();
    UserService.clearCache();
  });

  // 後端 POL-01 未部署，回應依規格 00_核心與認證.md §2.4c 手寫：完整 user 物件。
  Map<String, dynamic> filledMe() => loadFixtureMap('get_api_me.json')
    ..['birth_date'] = '2000-01-15'
    ..['needs_birth_date'] = false;

  late List<http.Request> requests;

  Future<void> open(WidgetTester tester, Map<String, Object?> routes) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    requests = [];
    installMockClient(routes, onRequest: requests.add);
    await tester.pumpWidget(
      MaterialApp(
        home: const BirthDateScreen(),
        routes: {
          '/home': (_) => const Text('HOME'),
          '/terms-consent': (_) => const Text('TERMS'),
          '/login': (_) => const Text('LOGIN'),
        },
      ),
    );
  }

  testWidgets('沒選日期不能送出', (tester) async {
    await open(tester, const {});

    await tester.tap(find.text('送　出'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(SnackBar, '請選擇出生日期'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('送出成功且條款已同意 → 首頁', (tester) async {
    await open(tester, {
      '/api/me/birth-date': filledMe(),
      '/api/terms': loadFixtureMap('get_api_terms.json'),
    });
    await pickBirthDate(tester, year: 2000, day: 15);

    await tester.tap(find.text('送　出'));
    await tester.pumpAndSettle();
    await confirmBirthDateDialog(tester);

    final post = requests.firstWhere((r) => r.url.path == '/api/me/birth-date');
    expect(
      (jsonDecode(post.body) as Map)['birth_date'],
      matches(RegExp(r'^2000-\d{2}-15$')),
    );
    expect(find.text('HOME'), findsOneWidget);
    expect(UserService.cachedUser?.needsBirthDate, isFalse);
  });

  testWidgets('送出成功但條款未同意 → 條款頁', (tester) async {
    await open(tester, {
      '/api/me/birth-date': filledMe(),
      '/api/terms': loadFixtureMap('get_api_terms.json')
        ..['all_consented'] = false,
    });
    await pickBirthDate(tester);

    await tester.tap(find.text('送　出'));
    await tester.pumpAndSettle();
    await confirmBirthDateDialog(tester);

    expect(find.text('TERMS'), findsOneWidget);
  });

  testWidgets('409 已填過 → 重抓 /api/me 直接放行', (tester) async {
    await open(tester, {
      '/api/me/birth-date': errorResponse(
        'BIRTH_DATE_ALREADY_SET',
        status: 409,
      ),
      '/api/me': filledMe(),
      '/api/terms': loadFixtureMap('get_api_terms.json'),
    });
    await pickBirthDate(tester);

    await tester.tap(find.text('送　出'));
    await tester.pumpAndSettle();
    await confirmBirthDateDialog(tester);

    expect(requests.map((r) => r.url.path), contains('/api/me'));
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('400 顯示後端訊息並留在原頁', (tester) async {
    await open(tester, {
      '/api/me/birth-date': errorResponse(
        'INVALID_REQUEST',
        message: '出生日期不合法',
      ),
    });
    await pickBirthDate(tester);

    await tester.tap(find.text('送　出'));
    await tester.pumpAndSettle();
    await confirmBirthDateDialog(tester);

    expect(find.widgetWithText(SnackBar, '出生日期不合法'), findsOneWidget);
    expect(find.byType(BirthDateScreen), findsOneWidget);
  });

  testWidgets('送出前確認框寫出所選日期與無法修改，按確認才送', (tester) async {
    await open(tester, {
      '/api/me/birth-date': filledMe(),
      '/api/terms': loadFixtureMap('get_api_terms.json'),
    });
    await pickBirthDate(tester, year: 2000, day: 15);

    await tester.tap(find.text('送　出'));
    await tester.pumpAndSettle();

    expect(requests, isEmpty, reason: '確認前不能送出');
    final dialog = find.byType(AppDialog);
    final message = tester.widget<AppDialog>(dialog).message;
    expect(message, matches(RegExp(r'^2000/\d{2}/15\n')));
    expect(message, contains('送出後無法自行修改'));

    await confirmBirthDateDialog(tester);
    expect(requests.map((r) => r.url.path), contains('/api/me/birth-date'));
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('確認框蓋上前送出被觸發兩次：只跳一個確認框、只送一次', (tester) async {
    await open(tester, {
      '/api/me/birth-date': filledMe(),
      '/api/terms': loadFixtureMap('get_api_terms.json'),
    });
    await pickBirthDate(tester);

    // 實體點擊在 push 確認框時會被 Navigator 吸收到下一幀；鍵盤、無障礙
    // 等直接觸發 onPressed 的路徑沒有這層保護，這裡直接連呼兩次重現。
    final submit = tester
        .widget<ElevatedButton>(
          find.ancestor(
            of: find.text('送　出'),
            matching: find.byType(ElevatedButton),
          ),
        )
        .onPressed!;
    submit();
    submit();
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsOneWidget);
    await confirmBirthDateDialog(tester);
    expect(find.byType(AppDialog), findsNothing);
    expect(
      requests.where((r) => r.url.path == '/api/me/birth-date'),
      hasLength(1),
    );
  });

  testWidgets('確認框按取消回到原頁，不送出，選的日期保留', (tester) async {
    await open(tester, const {});
    await pickBirthDate(tester, year: 2000, day: 15);
    final picked = find.textContaining(RegExp(r'^2000/\d{2}/15$'));
    expect(picked, findsOneWidget);

    await tester.tap(find.text('送　出'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsNothing);
    expect(requests, isEmpty);
    expect(picked, findsOneWidget);
    expect(find.byType(BirthDateScreen), findsOneWidget);
  });

  testWidgets('不能用返回鍵離開', (tester) async {
    await open(tester, const {});

    final popped = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    expect(find.byType(BirthDateScreen), findsOneWidget);
  });

  testWidgets('可以登出換帳號', (tester) async {
    await open(tester, const {});

    await tester.tap(find.text('登出，改用其他帳號'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN'), findsOneWidget);
  });
}
