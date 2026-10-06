// 後台官方公告：已發布列表、發布表單、確認框與結果。
// 回應依 收件匣與申訴.md §5 手寫（POST 會真的發給所有人，不錄）。

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/admin/admin_announcement_form_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_announcements_screen.dart';
import 'package:flutter_application_1/services/admin_service.dart';
import 'package:flutter_application_1/shared/widgets/ephemeral_network_image.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

Widget _app(Widget home) =>
    MaterialApp(scaffoldMessengerKey: scaffoldMessengerKey, home: home);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.BaseRequest> seen;

  setUp(() {
    stubCommonChannels();
    seen = [];
  });
  tearDown(restoreHttp);

  void install({
    http.Response? post,
    Object? postError,
    Future<void>? postGate,
  }) {
    ApiClient.httpClient = MockClient.streaming((request, _) async {
      seen.add(request);
      if (request.method == 'POST' && postGate != null) await postGate;
      if (request.method == 'POST' && postError != null) throw postError;
      final response = request.method == 'POST'
          ? post ??
                jsonResponse(
                  loadSpecFixtureMap('post_api_admin_announcements.json'),
                  status: 201,
                )
          : jsonResponse(
              loadSpecFixtureMap('get_api_admin_announcements.json'),
            );
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    });
  }

  http.MultipartRequest posted() =>
      seen.singleWhere((r) => r.method == 'POST') as http.MultipartRequest;

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), ' 新公告 ');
    await tester.enterText(find.byType(TextField).at(1), '公告內文');
    await tester.pump();
  }

  test(
    'createAnnouncement：multipart 欄位；不推播才送 push=false；圖片欄位名為 image',
    () async {
      install();

      await AdminService.createAnnouncement(title: ' 標題 ', body: ' 內文 ');
      expect(posted().fields, {'title': '標題', 'body': '內文'});
      expect(posted().files, isEmpty);

      seen.clear();
      final result = await AdminService.createAnnouncement(
        title: 't',
        body: 'b',
        imageBytes: [1, 2, 3],
        push: false,
      );
      expect(posted().fields['push'], 'false');
      expect(posted().files.single.field, 'image');
      expect(posted().files.single.contentType.mimeType, 'image/jpeg');
      expect(result.announcement.recipients, 128);
      expect(result.pushed, 97);
    },
  );

  testWidgets('列表顯示標題、時間、發布人、收件人數；點開看內文與圖片', (tester) async {
    install();
    await tester.pumpWidget(_app(const AdminAnnouncementsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('系統維護公告'), findsOneWidget);
    expect(find.text('歡迎使用語見太魯閣'), findsOneWidget);
    expect(find.textContaining('管理員甲', findRichText: true), findsNWidgets(2));
    expect(find.textContaining('128 人', findRichText: true), findsOneWidget);

    await tester.tap(find.text('系統維護公告'));
    await tester.pumpAndSettle();

    expect(find.text('週六凌晨 2 點到 4 點維護，期間無法使用。'), findsOneWidget);
    expect(find.byType(EphemeralNetworkImage), findsOneWidget);
  });

  testWidgets('表單：標題或內文空白不能發布，「同時推播」預設開啟', (tester) async {
    install();
    await tester.pumpWidget(_app(const AdminAnnouncementFormScreen()));

    FilledButton publish() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '發布'));
    expect(publish().onPressed, isNull);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.enterText(find.byType(TextField).at(0), '標題');
    await tester.pump();
    expect(publish().onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(1), '內文');
    await tester.pump();
    expect(publish().onPressed, isNotNull);
  });

  testWidgets('發布：確認框寫明會發給所有使用者與是否推播，成功後顯示寫入人數與推播成功數', (tester) async {
    install();
    await tester.pumpWidget(_app(const AdminAnnouncementFormScreen()));
    await fill(tester);

    await tester.tap(find.widgetWithText(FilledButton, '發布'));
    await tester.pumpAndSettle();
    expect(find.textContaining('會發給所有使用者'), findsOneWidget);
    expect(find.textContaining('同時會推播通知所有人'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '發布').last);
    await tester.pumpAndSettle();

    expect(posted().fields, {'title': '新公告', 'body': '公告內文'});
    expect(find.textContaining('已寫入 128 人的收件匣'), findsOneWidget);
    expect(find.textContaining('推播成功 97 則'), findsOneWidget);
  });

  testWidgets('關掉推播：確認框寫明不推播，送 push=false', (tester) async {
    install();
    await tester.pumpWidget(_app(const AdminAnnouncementFormScreen()));
    await fill(tester);
    await tester.tap(find.byType(Switch));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, '發布'));
    await tester.pumpAndSettle();
    expect(find.textContaining('只進收件匣，不推播'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '發布').last);
    await tester.pumpAndSettle();

    expect(posted().fields['push'], 'false');
    expect(find.textContaining('沒有推播'), findsOneWidget);
  });

  testWidgets('取消確認就不送出', (tester) async {
    install();
    await tester.pumpWidget(_app(const AdminAnnouncementFormScreen()));
    await fill(tester);

    await tester.tap(find.widgetWithText(FilledButton, '發布'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(seen.where((r) => r.method == 'POST'), isEmpty);
  });

  for (final code in [
    'FILE_TOO_LARGE',
    'INVALID_FILE_TYPE',
    'INVALID_REQUEST',
  ]) {
    testWidgets('400 $code：顯示後端 message，留在表單', (tester) async {
      install(post: errorResponse(code, message: '後端說明：$code'));
      await tester.pumpWidget(_app(const AdminAnnouncementFormScreen()));
      await fill(tester);
      await tester.tap(find.widgetWithText(FilledButton, '發布'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '發布').last);
      await tester.pumpAndSettle();

      expect(find.text('後端說明：$code'), findsOneWidget);
      expect(find.byType(AdminAnnouncementFormScreen), findsOneWidget);
    });
  }

  // T-14：後端要等全體推播送完才回應，這段時間公告已 commit。結果不明時不能讓
  // 管理員直接重送，否則全體會收到兩則收不回的公告。
  for (final (label, postError, post) in <(String, Object?, http.Response?)>[
    ('斷線（SocketException）', const SocketException('reset'), null),
    ('連線中斷（ClientException）', http.ClientException('closed'), null),
    ('閘道錯誤 502', null, errorResponse('BAD_GATEWAY', status: 502)),
    ('服務暫停 503', null, errorResponse('SERVICE_UNAVAILABLE', status: 503)),
    ('閘道逾時 504', null, errorResponse('GATEWAY_TIMEOUT', status: 504)),
  ]) {
    testWidgets('$label：提示可能已發出，按知道了回列表並重抓，不留在表單重送', (tester) async {
      install(postError: postError, post: post);
      await tester.pumpWidget(_app(const AdminAnnouncementsScreen()));
      await tester.pumpAndSettle();
      expect(seen.where((r) => r.method == 'GET'), hasLength(1));

      await tester.tap(find.byTooltip('新增公告'));
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.tap(find.widgetWithText(FilledButton, '發布'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '發布').last);
      await tester.pumpAndSettle();

      expect(find.text('公告可能已經發出，請回列表確認。'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminAnnouncementFormScreen), findsNothing);
      expect(find.byType(AdminAnnouncementsScreen), findsOneWidget);
      expect(seen.where((r) => r.method == 'GET'), hasLength(2));
      expect(seen.where((r) => r.method == 'POST'), hasLength(1));
    });
  }

  testWidgets('400 明確錯誤：解鎖發布鈕，修改後可再送', (tester) async {
    install(post: errorResponse('INVALID_REQUEST', message: '標題不符'));
    await tester.pumpWidget(_app(const AdminAnnouncementFormScreen()));
    await fill(tester);
    await tester.tap(find.widgetWithText(FilledButton, '發布'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '發布').last);
    await tester.pumpAndSettle();

    expect(find.text('公告可能已經發出，請回列表確認。'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '發布'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('送出中：返回鈕與系統返回都留在表單；成功後照常回列表', (tester) async {
    final gate = Completer<void>();
    install(postGate: gate.future);
    await tester.pumpWidget(_app(const AdminAnnouncementsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新增公告'));
    await tester.pumpAndSettle();
    await fill(tester);
    await tester.tap(find.widgetWithText(FilledButton, '發布'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '發布').last);
    await tester.pump();

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminAnnouncementFormScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AdminAnnouncementFormScreen), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('已寫入 128 人的收件匣'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminAnnouncementFormScreen), findsNothing);
    expect(find.byType(AdminAnnouncementsScreen), findsOneWidget);
  });

  testWidgets('沒在送出時返回鈕照常離開表單', (tester) async {
    install();
    await tester.pumpWidget(_app(const AdminAnnouncementsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新增公告'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminAnnouncementFormScreen), findsNothing);
  });
}
