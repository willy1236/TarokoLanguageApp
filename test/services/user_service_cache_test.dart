import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/services/user_service.dart';

UserModel _user(int uid, String name) =>
    UserModel(uid: uid, email: '', createdAt: DateTime(2026), displayName: name);

void main() {
  tearDown(UserService.clearCache);

  test('cacheUser 更新快取並通知 userNotifier', () {
    UserService.currentUid = 1;
    var notified = 0;
    void listener() => notified++;
    UserService.userNotifier.addListener(listener);
    addTearDown(() => UserService.userNotifier.removeListener(listener));

    UserService.cacheUser(_user(1, '新名字'));

    expect(notified, 1);
    expect(UserService.cachedUser?.displayName, '新名字');
  });

  test('cacheUser 忽略非目前登入者（已登出或換帳號）的晚到回應', () {
    UserService.cacheUser(_user(1, 'A'));
    expect(UserService.cachedUser, isNull);

    UserService.currentUid = 2;
    UserService.cacheUser(_user(1, 'A'));
    expect(UserService.cachedUser, isNull);
  });

  test('clearCache 清空快取並通知', () {
    UserService.currentUid = 1;
    UserService.cacheUser(_user(1, 'A'));
    UserService.clearCache();
    expect(UserService.cachedUser, isNull);
    expect(UserService.currentUid, isNull);
  });
}
