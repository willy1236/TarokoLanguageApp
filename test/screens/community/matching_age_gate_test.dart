// 隨機配對年齡限制（POL-01）：未滿 18 歲時「開始配對」變暗、點了看說明並可
// 前往好友列表；後端回 UNDERAGE／BIRTH_DATE_REQUIRED 時的分流。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/screens/community/community_screen.dart';
import 'package:flutter_application_1/screens/community/matching_age_gate.dart';
import 'package:flutter_application_1/screens/friends/friends_list_screen.dart';
import 'package:flutter_application_1/services/user_service.dart';
import 'package:flutter_application_1/shared/utils/birth_date.dart';

import '../../helpers/flow_test_helpers.dart';
import '../../helpers/widget_test_helpers.dart';

UserModel _user(DateTime? birthDate) => UserModel(
  uid: 1,
  email: '',
  createdAt: DateTime(2026),
  profileCompleted: true,
  birthDate: birthDate,
);

ApiException _error(String code) =>
    ApiException(statusCode: 403, code: code, message: code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    restoreHttp();
    UserService.clearCache();
  });

  group('UserModel.isAdult', () {
    test('沒有生日回 null，交給後端判斷', () {
      expect(_user(null).isAdult, isNull);
    });

    test('依台灣今天判斷', () {
      final today = taiwanToday();
      final eighteen = DateTime(today.year - 18, today.month, today.day);
      expect(_user(eighteen).isAdult, isTrue);
      expect(_user(eighteen.add(const Duration(days: 1))).isAdult, isFalse);
    });
  });

  group('配對入口按鈕', () {
    Future<void> open(WidgetTester tester, DateTime? birthDate) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      installMockClient({
        '/api/friends': {'friends': <dynamic>[]},
        '/api/shop/items': {'items': <dynamic>[]},
      });
      UserService.currentUid = 1;
      UserService.cacheUser(_user(birthDate));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CommunityScreen())),
      );
      await pumpFrames(tester);
    }

    double buttonAlpha(WidgetTester tester) {
      final box = tester.widget<Container>(
        find
            .ancestor(of: find.text('開始配對'), matching: find.byType(Container))
            .first,
      );
      return (box.decoration! as BoxDecoration).color!.a;
    }

    DateTime tenYearsOld() => DateTime(taiwanToday().year - 10, 1, 1);

    testWidgets('未滿 18 歲時變暗，點了顯示說明並可前往好友列表', (tester) async {
      await open(tester, tenYearsOld());

      expect(buttonAlpha(tester), lessThan(0.5));

      await tester.tap(find.text('開始配對'));
      await pumpFrames(tester, times: 10);
      expect(find.text('未滿 18 歲無法使用隨機配對，可以與好友視訊'), findsOneWidget);

      await tester.tap(find.text('前往好友列表'));
      await pumpFrames(tester, times: 10);
      expect(find.byType(FriendsListScreen), findsOneWidget);
    });

    testWidgets('成年或沒有生日時照常顯示', (tester) async {
      await open(tester, DateTime(1990, 1, 1));
      expect(buttonAlpha(tester), 1.0);

      UserService.cacheUser(_user(null));
      await tester.pump();
      expect(buttonAlpha(tester), 1.0);
    });

    testWidgets('管理員更正生日後（重抓 /api/me）按鈕跟著變', (tester) async {
      await open(tester, DateTime(1990, 1, 1));

      UserService.cacheUser(_user(tenYearsOld()));
      await tester.pump();

      expect(buttonAlpha(tester), lessThan(0.5));
    });
  });

  group('handleMatchingAgeError', () {
    Future<BuildContext> host(WidgetTester tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold();
            },
          ),
          routes: {'/birth-date': (_) => const Text('BIRTH_DATE')},
        ),
      );
      return ctx;
    }

    testWidgets('UNDERAGE 顯示說明底板', (tester) async {
      final ctx = await host(tester);
      expect(handleMatchingAgeError(ctx, _error('UNDERAGE')), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('前往好友列表'), findsOneWidget);
    });

    testWidgets('BIRTH_DATE_REQUIRED 導去補填頁', (tester) async {
      final ctx = await host(tester);
      expect(
        handleMatchingAgeError(ctx, _error('BIRTH_DATE_REQUIRED')),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(find.text('BIRTH_DATE'), findsOneWidget);
    });

    testWidgets('其他錯誤交回呼叫端', (tester) async {
      final ctx = await host(tester);
      expect(handleMatchingAgeError(ctx, _error('MUTED')), isFalse);
    });
  });
}
