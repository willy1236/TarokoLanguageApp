import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/user_model.dart';

void main() {
  group('UserModel.fromJson', () {
    test('解析完整欄位（含未來頭像欄位一併回傳的情況）', () {
      final json = {
        'uid': '123',
        'display_name': '小明',
        'avatar_url': 'https://example.com/pic.png',
        'avatar_id': 'avatar_01',
        'owned_avatar_ids': ['avatar_01', 'avatar_02'],
        'coins': 150,
      };

      final user = UserModel.fromJson(json);

      expect(user.uid, '123');
      expect(user.displayName, '小明');
      expect(user.avatarUrl, 'https://example.com/pic.png');
      expect(user.avatarId, 'avatar_01');
      expect(user.ownedAvatarIds, ['avatar_01', 'avatar_02']);
      expect(user.coins, 150);
    });

    test('容忍後端目前實際回傳的 map（僅 uid/display_name/avatar_url，無頭像/幣別欄位）', () {
      final json = {
        'uid': '456',
        'display_name': 'Alice',
        'avatar_url': 'https://lh3.googleusercontent.com/a/xyz',
      };

      final user = UserModel.fromJson(json);

      expect(user.uid, '456');
      expect(user.displayName, 'Alice');
      expect(user.avatarUrl, 'https://lh3.googleusercontent.com/a/xyz');
      expect(user.avatarId, isNull);
      expect(user.ownedAvatarIds, isEmpty);
      expect(user.coins, 0);
    });

    test('容忍 uid 以外全部欄位缺失或為 null', () {
      final json = {
        'uid': '789',
        'display_name': null,
        'avatar_url': null,
      };

      final user = UserModel.fromJson(json);

      expect(user.uid, '789');
      expect(user.displayName, isNull);
      expect(user.avatarUrl, isNull);
      expect(user.avatarId, isNull);
      expect(user.ownedAvatarIds, <String>[]);
      expect(user.coins, 0);
    });

    test('uid 為數字型別時也能轉為 String', () {
      final json = {'uid': 42};

      final user = UserModel.fromJson(json);

      expect(user.uid, '42');
    });
  });

  group('UserModel.toJson', () {
    test('往返序列化保持一致', () {
      const user = UserModel(
        uid: '1',
        displayName: 'Bob',
        avatarUrl: 'url',
        avatarId: 'avatar_05',
        ownedAvatarIds: ['avatar_05'],
        coins: 30,
      );

      final json = user.toJson();

      expect(json, {
        'uid': '1',
        'display_name': 'Bob',
        'avatar_url': 'url',
        'avatar_id': 'avatar_05',
        'owned_avatar_ids': ['avatar_05'],
        'coins': 30,
      });

      final roundTripped = UserModel.fromJson(json);
      expect(roundTripped.uid, user.uid);
      expect(roundTripped.displayName, user.displayName);
      expect(roundTripped.avatarUrl, user.avatarUrl);
      expect(roundTripped.avatarId, user.avatarId);
      expect(roundTripped.ownedAvatarIds, user.ownedAvatarIds);
      expect(roundTripped.coins, user.coins);
    });
  });

  group('UserModel.copyWith', () {
    const base = UserModel(
      uid: '1',
      displayName: 'Bob',
      avatarUrl: 'url',
      coins: 10,
    );

    test('未傳入的欄位維持原值', () {
      final copy = base.copyWith(coins: 20);

      expect(copy.uid, base.uid);
      expect(copy.displayName, base.displayName);
      expect(copy.avatarUrl, base.avatarUrl);
      expect(copy.avatarId, base.avatarId);
      expect(copy.ownedAvatarIds, base.ownedAvatarIds);
      expect(copy.coins, 20);
    });

    test('可更新頭像相關欄位', () {
      final copy = base.copyWith(
        avatarId: 'avatar_09',
        ownedAvatarIds: ['avatar_09'],
      );

      expect(copy.avatarId, 'avatar_09');
      expect(copy.ownedAvatarIds, ['avatar_09']);
      // 其餘欄位不受影響
      expect(copy.uid, base.uid);
      expect(copy.coins, base.coins);
    });
  });
}
