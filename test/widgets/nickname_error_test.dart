// 暱稱含「管理員」「官方」等字樣時，後端回 400 INVALID_NICKNAME，message 要顯示在
// 暱稱欄位下方讓使用者直接改，一改字就消失；其他錯誤維持原本的提示方式。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/screens/auth/complete_profile_screen.dart';
import 'package:flutter_application_1/screens/profile/profile_info_screen.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../helpers/birth_date_test_helpers.dart';
import '../helpers/fixtures.dart';
import '../helpers/widget_test_helpers.dart';

const _blocked = '暱稱不能包含「官方」等字樣';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    restoreHttp();
    UserService.clearCache();
  });

  group('完善資料頁', () {
    Future<void> fillAndSubmit(WidgetTester tester, String nickname) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapScreen(CompleteProfileScreen(readGoogleName: () => '阿華')),
      );
      await tester.enterText(
        find.widgetWithText(TextField, '論壇、視訊、好友都會顯示這個名字'),
        nickname,
      );
      await pickBirthDate(tester);
      await tester.tap(find.text('完　成'));
      await tester.pumpAndSettle();
    }

    testWidgets('INVALID_NICKNAME 顯示在暱稱欄位下方，改字就消失', (tester) async {
      installMockClient({
        '/api/me/complete-profile': errorResponse(
          'INVALID_NICKNAME',
          message: _blocked,
        ),
      });

      await fillAndSubmit(tester, '官方小編');

      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, '官方小編'),
      );
      expect(field.decoration?.errorText, _blocked);
      expect(find.byType(SnackBar), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, '官方小編'), '小編');
      await tester.pump();
      expect(find.text(_blocked), findsNothing);
    });

    testWidgets('其他錯誤仍用 SnackBar', (tester) async {
      installMockClient({
        '/api/me/complete-profile': errorResponse(
          'INVALID_REQUEST',
          message: '資料格式錯誤',
        ),
      });

      await fillAndSubmit(tester, '小編');

      expect(find.widgetWithText(SnackBar, '資料格式錯誤'), findsOneWidget);
    });
  });

  group('個人資料頁「修改公開暱稱」', () {
    late List<http.Request> patches;

    void install(http.Response Function() patch) {
      patches = [];
      final me = loadFixtureMap('get_api_me.json');
      ApiClient.httpClient = MockClient((request) async {
        if (request.url.path != '/api/me') fail('未預期的 ${request.url.path}');
        if (request.method == 'PATCH') {
          patches.add(request);
          return patch();
        }
        return jsonResponse(me);
      });
    }

    Future<void> openDialog(WidgetTester tester) async {
      UserService.cacheUser(
        UserModel.fromJson(loadFixtureMap('get_api_me.json')),
      );
      await tester.pumpWidget(wrapScreen(const ProfileInfoScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('測試暱稱'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '官方小編');
    }

    testWidgets('被擋時對話框不關，原因顯示在欄位下方', (tester) async {
      install(() => errorResponse('INVALID_NICKNAME', message: _blocked));
      await openDialog(tester);

      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      expect(jsonDecode(patches.single.body), {'video_nickname': '官方小編'});
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(_blocked), findsOneWidget);

      await tester.enterText(find.byType(TextField), '小編');
      await tester.pump();
      expect(find.text(_blocked), findsNothing);
    });

    testWidgets('其他錯誤在對話框內顯示通用訊息，不關閉', (tester) async {
      install(() => errorResponse('INTERNAL_ERROR', status: 500));
      await openDialog(tester);

      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('更新失敗，請稍後再試'), findsOneWidget);
    });

    testWidgets('送出中點背景不會關閉對話框，被擋的原因仍看得到', (tester) async {
      final pending = Completer<http.Response>();
      patches = [];
      final me = loadFixtureMap('get_api_me.json');
      ApiClient.httpClient = MockClient((request) async {
        if (request.method == 'PATCH') {
          patches.add(request);
          return pending.future;
        }
        return jsonResponse(me);
      });
      await openDialog(tester);

      await tester.tap(find.text('儲存'));
      await tester.pump();
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);

      pending.complete(errorResponse('INVALID_NICKNAME', message: _blocked));
      await tester.pumpAndSettle();
      expect(find.text(_blocked), findsOneWidget);
    });

    testWidgets('成功才關閉並更新畫面', (tester) async {
      final updated = loadFixtureMap('patch_api_me.json')
        ..['video_nickname'] = '新暱稱';
      install(() => jsonResponse(updated));
      await openDialog(tester);

      await tester.enterText(find.byType(TextField), '新暱稱');
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('新暱稱'), findsOneWidget);
    });
  });
}
