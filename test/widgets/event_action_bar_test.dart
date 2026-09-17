// EventActionBar（活動詳情底部行動列）的測試。
//
// 這支取代的人工測試：拿不同身分（發起人／已報名／路人）在不同活動狀態下
// 開活動詳情頁，看底部按鈕對不對；以及帳號被鎖成唯讀時，寫入類動作有沒有被擋。
// 人工要湊齊這些組合得準備好幾個帳號與活動，是最不划算的重複勞動之一。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/models/event_model.dart';
import 'package:flutter_application_1/screens/events/widgets/event_action_bar.dart';
import 'package:flutter_application_1/services/account_lock_controller.dart';

import '../helpers/widget_test_helpers.dart';

const int _hostUid = 100;
const int _strangerUid = 200;

EventDetail _event({
  String status = 'active',
  String? effectiveStatus = 'active',
  bool registrationOpen = true,
  int? maxParticipants,
  int participantCount = 0,
  bool isJoined = false,
}) =>
    EventDetail(
      id: 1,
      hostUid: _hostUid,
      title: '部落豐年祭',
      startsAt: DateTime(2026, 12, 1),
      status: status,
      effectiveStatus: effectiveStatus,
      registrationOpen: registrationOpen,
      maxParticipants: maxParticipants,
      participantCountRaw: participantCount,
      isJoined: isJoined,
    );

/// blockIfReadOnly() 的提示走 main.dart 的全域 scaffoldMessengerKey，
/// 所以測試用的 App 必須掛同一把 key，否則提示不會出現在這棵樹裡。
Widget _app(Widget child) => MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: Scaffold(body: child),
    );

Widget _bar(
  EventDetail event, {
  int? uid,
  bool acting = false,
  VoidCallback? onJoin,
}) =>
    EventActionBar(
      event: event,
      uid: uid,
      acting: acting,
      seniorMode: false,
      onJoin: onJoin ?? () {},
      onLeave: () {},
      onCancel: () {},
      onEdit: () {},
      onExport: () {},
      onDelete: () {},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    accountLockController.setLocked(false);
  });

  tearDown(() => accountLockController.setLocked(false));

  testWidgets('一般使用者在可報名的活動看到「我要參加」', (tester) async {
    await tester.pumpWidget(_app(_bar(_event(), uid: _strangerUid)));

    expect(find.text('我要參加'), findsOneWidget);
  });

  testWidgets('名額已滿時顯示「名額已滿」而不是報名鈕', (tester) async {
    await tester.pumpWidget(_app(_bar(
      _event(maxParticipants: 10, participantCount: 10),
      uid: _strangerUid,
    )));

    expect(find.text('名額已滿'), findsOneWidget);
    expect(find.text('我要參加'), findsNothing);
  });

  testWidgets('報名已截止時顯示截止提示', (tester) async {
    await tester.pumpWidget(_app(_bar(
      _event(registrationOpen: false),
      uid: _strangerUid,
    )));

    expect(find.text('報名已截止'), findsOneWidget);
  });

  testWidgets('活動已結束／已取消時蓋過其他狀態', (tester) async {
    await tester.pumpWidget(_app(_bar(
      _event(effectiveStatus: 'ended'),
      uid: _strangerUid,
    )));
    expect(find.text('活動已結束'), findsOneWidget);

    await tester.pumpWidget(_app(_bar(
      _event(status: 'cancelled', effectiveStatus: 'cancelled'),
      uid: _hostUid,
    )));
    expect(find.text('活動已取消'), findsOneWidget);
    // 已取消的活動，發起人也不該還看得到發送提醒。
    expect(find.text('發送提醒'), findsNothing);
  });

  testWidgets('發起人看到發送提醒', (tester) async {
    await tester.pumpWidget(_app(_bar(_event(), uid: _hostUid)));

    expect(find.text('發送提醒'), findsOneWidget);
    expect(find.text('我要參加'), findsNothing);
  });

  testWidgets('操作進行中時顯示轉圈並吃掉重複點擊', (tester) async {
    var joined = false;
    await tester.pumpWidget(_app(_bar(
      _event(),
      uid: _strangerUid,
      acting: true,
      onJoin: () => joined = true,
    )));

    // 進行中時按鈕文字換成轉圈，避免使用者以為沒反應而連按。
    expect(find.text('我要參加'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(CircularProgressIndicator), warnIfMissed: false);
    await tester.pump();

    expect(joined, isFalse);
  });

  testWidgets('唯讀模式下發起人按發送提醒會被擋下並顯示提示', (tester) async {
    accountLockController.setLocked(true);

    await tester.pumpWidget(_app(_bar(_event(), uid: _hostUid)));
    await tester.tap(find.text('發送提醒'));
    await tester.pump();

    expect(find.text(readOnlyMessage), findsOneWidget);
    // 沒有被導去撰寫提醒的畫面。
    expect(find.text('發送提醒'), findsOneWidget);
  });

  testWidgets('非唯讀時發送提醒可正常進入撰寫畫面', (tester) async {
    await tester.pumpWidget(_app(_bar(_event(), uid: _hostUid)));
    await tester.tap(find.text('發送提醒'));
    await tester.pumpAndSettle();

    expect(find.text(readOnlyMessage), findsNothing);
  });
}
