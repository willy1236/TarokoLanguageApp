// FramedUserAvatar 的「自己的頭像以快取為準」測試。
//
// 這支取代的人工測試：換完頭像後到論壇滑自己的舊貼文、舊留言，確認頭像都跟著
// 變。貼文的 author 欄是發文當下的快照，人工要驗得先發文、再換頭像、再回看板，
// 而且只有自己的貼文會變、別人的不能被蓋掉——組合起來很花時間。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/services/user_service.dart';
import 'package:flutter_application_1/shared/widgets/user_avatar.dart';

const int _myUid = 100;
const int _otherUid = 200;

const _snapshotUrl = 'https://example.com/old.webp';
const _currentUrl = 'https://example.com/new.webp';

UserModel _me({String? avatarUrl = _currentUrl, String? avatarId}) => UserModel(
  uid: _myUid,
  email: 'me@example.com',
  createdAt: DateTime(2026),
  avatarUrl: avatarUrl,
  avatarId: avatarId,
);

Widget _app(int? userUid) => MaterialApp(
  home: Scaffold(
    body: FramedUserAvatar(
      avatarUrl: _snapshotUrl,
      size: 40,
      fallbackIconColor: Colors.grey,
      userUid: userUid,
    ),
  ),
);

String? _renderedUrl(WidgetTester tester) =>
    tester.widget<UserAvatar>(find.byType(UserAvatar)).avatarUrl;

void main() {
  tearDown(UserService.clearCache);

  testWidgets('是自己時用快取的頭像蓋掉貼文裡的舊快照', (tester) async {
    UserService.currentUid = _myUid;
    UserService.userNotifier.value = _me();

    await tester.pumpWidget(_app(_myUid));

    expect(_renderedUrl(tester), _currentUrl);
  });

  testWidgets('換頭像後不必重載清單，畫面即時跟著換', (tester) async {
    UserService.currentUid = _myUid;
    UserService.userNotifier.value = _me(avatarUrl: _snapshotUrl);

    await tester.pumpWidget(_app(_myUid));
    expect(_renderedUrl(tester), _snapshotUrl);

    UserService.userNotifier.value = _me(avatarUrl: _currentUrl);
    await tester.pump();

    expect(_renderedUrl(tester), _currentUrl);
  });

  testWidgets('別人的頭像一律照傳入值渲染', (tester) async {
    UserService.currentUid = _myUid;
    UserService.userNotifier.value = _me();

    await tester.pumpWidget(_app(_otherUid));

    expect(_renderedUrl(tester), _snapshotUrl);
  });

  testWidgets('沒有傳 userUid 時行為不變', (tester) async {
    UserService.currentUid = _myUid;
    UserService.userNotifier.value = _me();

    await tester.pumpWidget(_app(null));

    expect(_renderedUrl(tester), _snapshotUrl);
  });
}
