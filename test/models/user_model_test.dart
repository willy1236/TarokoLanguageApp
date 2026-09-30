import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/user_model.dart';

void main() {
  group('UserModel.fromJson', () {
    test('容忍頭像/頭像框/幣別欄位缺失', () {
      final json = {
        'uid': 456,
        'display_name': 'Alice',
        'avatar_url': 'https://lh3.googleusercontent.com/a/xyz',
        'email': 'alice@example.com',
        'created_at': '2026-01-01T00:00:00.000Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.uid, 456);
      expect(user.displayName, 'Alice');
      expect(user.avatarUrl, 'https://lh3.googleusercontent.com/a/xyz');
      expect(user.avatarId, isNull);
      expect(user.frameId, isNull);
      expect(user.ownedAvatarIds, isEmpty);
      expect(user.ownedFrameIds, isEmpty);
      expect(user.millet, 0);
    });

    test('容忍非必填欄位缺失或為 null', () {
      final json = {
        'uid': 789,
        'display_name': null,
        'avatar_url': null,
        'email': 'anon@example.com',
        'created_at': '2026-01-01T00:00:00.000Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.uid, 789);
      expect(user.displayName, isNull);
      expect(user.avatarUrl, isNull);
      expect(user.avatarId, isNull);
      expect(user.ownedAvatarIds, <String>[]);
      expect(user.millet, 0);
    });

    test('Apple 帳號 email 為 null 時不崩潰，驗證欄位預設 false', () {
      final user = UserModel.fromJson({
        'uid': 1,
        'email': null,
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      expect(user.email, '');
      expect(user.emailVerified, isFalse);
      expect(user.emailIsCustom, isFalse);
    });
  });

  group('出生日期（POL-01）', () {
    // 後端 POL-01 尚未部署、錄不到新欄位，依規格 00_核心與認證.md §2.3 手寫；
    // 上線後以 inspector 重錄 get_api_me.json 核對。
    Map<String, dynamic> me() => {
      'uid': 5,
      'email': 'a@example.com',
      'created_at': '2026-05-01T08:00:00Z',
      'profile_completed': true,
    };

    test('解析 birth_date 與 needs_birth_date', () {
      final user = UserModel.fromJson(
        me()
          ..['birth_date'] = '1995-03-15'
          ..['needs_birth_date'] = false,
      );
      expect(user.birthDate, DateTime(1995, 3, 15));
      expect(user.needsBirthDate, isFalse);
    });

    test('舊使用者尚未補填：birth_date 為 null、needs_birth_date 為 true', () {
      final user = UserModel.fromJson(
        me()
          ..['birth_date'] = null
          ..['needs_birth_date'] = true,
      );
      expect(user.birthDate, isNull);
      expect(user.needsBirthDate, isTrue);
    });

    test('舊後端沒有這兩個欄位時不擋人', () {
      final user = UserModel.fromJson(me());
      expect(user.birthDate, isNull);
      expect(user.needsBirthDate, isFalse);
    });
  });
}
