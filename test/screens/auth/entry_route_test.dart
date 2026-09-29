import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/screens/auth/entry_route.dart';

UserModel _user({bool profileCompleted = true, bool needsBirthDate = false}) =>
    UserModel(
      uid: 1,
      email: '',
      createdAt: DateTime(2026),
      profileCompleted: profileCompleted,
      needsBirthDate: needsBirthDate,
    );

void main() {
  test('未完成基本資料優先於其他檢查', () {
    expect(
      entryRouteFor(
        _user(profileCompleted: false, needsBirthDate: true),
        allConsented: false,
      ),
      '/complete-profile',
    );
  });

  test('基本資料完成但要補填生日，先於條款', () {
    expect(
      entryRouteFor(_user(needsBirthDate: true), allConsented: false),
      '/birth-date',
    );
    expect(
      entryRouteFor(_user(needsBirthDate: true), allConsented: true),
      '/birth-date',
    );
  });

  test('資料齊全但條款未同意 → 條款頁', () {
    expect(entryRouteFor(_user(), allConsented: false), '/terms-consent');
  });

  test('都完成 → 首頁', () {
    expect(entryRouteFor(_user(), allConsented: true), '/home');
  });

  test('查不到使用者時不擋，只看條款', () {
    expect(entryRouteFor(null, allConsented: true), '/home');
    expect(entryRouteFor(null, allConsented: false), '/terms-consent');
  });
}
