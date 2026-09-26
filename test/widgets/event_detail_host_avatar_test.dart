// 活動詳情頁「發起人」那格的頭像測試。
//
// 這格原本是寫死的 Icons.person 佔位圖示，後端明明有回 avatar_url／avatar_id／
// frame_id 卻沒接。人工要驗得先換頭像再開自己發起的活動，繞一大圈。
//
// 注意後端只有在「看的人就是發起人」時才回 participants（見 events.ts 的
// GET /api/events/:id），所以非發起人視角本來就沒有頭像可顯示，這裡一併鎖住
// 這個預期，避免之後誤以為是 bug 而亂改。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/event_model.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/screens/events/widgets/event_detail_body.dart';
import 'package:flutter_application_1/services/user_service.dart';
import 'package:flutter_application_1/shared/widgets/user_avatar.dart';

const int _hostUid = 100;
const _snapshotUrl = 'https://example.com/host-old.webp';
const _currentUrl = 'https://example.com/host-new.webp';

EventDetail _event({List<EventParticipant> participants = const []}) =>
    EventDetail(
      id: 1,
      hostUid: _hostUid,
      title: '部落豐年祭',
      startsAt: DateTime(2026, 12, 1),
      status: 'active',
      effectiveStatus: 'active',
      participants: participants,
    );

EventParticipant _host({String? avatarUrl = _snapshotUrl}) =>
    EventParticipant(uid: _hostUid, displayName: '織語者', avatarUrl: avatarUrl);

Widget _app(EventDetail event, {int? uid}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: EventDetailBody(
        event: event,
        uid: uid,
        reminders: const [],
        seniorMode: false,
        onToggleLike: () {},
        onToggleBookmark: () {},
      ),
    ),
  ),
);

void main() {
  tearDown(UserService.clearCache);

  testWidgets('發起人視角顯示發起人的真實頭像與名字', (tester) async {
    await tester.pumpWidget(
      _app(_event(participants: [_host()]), uid: _hostUid),
    );

    expect(
      tester.widget<UserAvatar>(find.byType(UserAvatar)).avatarUrl,
      _snapshotUrl,
    );
    expect(find.text('織語者'), findsOneWidget);
  });

  testWidgets('發起人換頭像後不必重載活動，這格就跟著換', (tester) async {
    UserService.currentUid = _hostUid;
    UserService.userNotifier.value = UserModel(
      uid: _hostUid,
      email: 'host@example.com',
      createdAt: DateTime(2026),
      avatarUrl: _currentUrl,
    );

    await tester.pumpWidget(
      _app(_event(participants: [_host()]), uid: _hostUid),
    );

    expect(
      tester.widget<UserAvatar>(find.byType(UserAvatar)).avatarUrl,
      _currentUrl,
    );
  });

  testWidgets('非發起人視角拿不到 participants，退回預設圖示不會壞版', (tester) async {
    await tester.pumpWidget(_app(_event(), uid: 999));

    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.text('發起人'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
