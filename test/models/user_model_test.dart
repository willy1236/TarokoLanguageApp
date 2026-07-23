import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/user_model.dart';

void main() {
  group('UserModel.fromJson', () {
    test('解析完整欄位（含頭像商店欄位）', () {
      final json = {
        'uid': 123,
        'display_name': '小明',
        'avatar_url': 'https://example.com/pic.png',
        'avatar_id': 'avatar_01',
        'frame_id': 'frame_01',
        'owned_avatar_ids': ['avatar_01', 'avatar_02'],
        'owned_frame_ids': ['frame_01'],
        'millet': 150,
        'email': 'ming@example.com',
        'created_at': '2026-01-01T00:00:00.000Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.uid, 123);
      expect(user.displayName, '小明');
      expect(user.avatarUrl, 'https://example.com/pic.png');
      expect(user.avatarId, 'avatar_01');
      expect(user.frameId, 'frame_01');
      expect(user.ownedAvatarIds, ['avatar_01', 'avatar_02']);
      expect(user.ownedFrameIds, ['frame_01']);
      expect(user.millet, 150);
      expect(user.email, 'ming@example.com');
    });

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
  });

  group('UserModel.toJson', () {
    test('往返序列化保持一致', () {
      final user = UserModel(
        uid: 1,
        displayName: 'Bob',
        avatarUrl: 'url',
        avatarId: 'avatar_05',
        frameId: 'frame_05',
        ownedAvatarIds: const ['avatar_05'],
        ownedFrameIds: const ['frame_05'],
        millet: 30,
        email: 'bob@example.com',
        createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
      );

      final json = user.toJson();

      expect(json, {
        'uid': 1,
        'display_name': 'Bob',
        'avatar_url': 'url',
        'avatar_id': 'avatar_05',
        'frame_id': 'frame_05',
        'owned_avatar_ids': ['avatar_05'],
        'owned_frame_ids': ['frame_05'],
        'millet': 30,
        'email': 'bob@example.com',
        'created_at': user.createdAt.toIso8601String(),
      });

      final roundTripped = UserModel.fromJson(json);
      expect(roundTripped.uid, user.uid);
      expect(roundTripped.displayName, user.displayName);
      expect(roundTripped.avatarUrl, user.avatarUrl);
      expect(roundTripped.avatarId, user.avatarId);
      expect(roundTripped.frameId, user.frameId);
      expect(roundTripped.ownedAvatarIds, user.ownedAvatarIds);
      expect(roundTripped.ownedFrameIds, user.ownedFrameIds);
      expect(roundTripped.millet, user.millet);
      expect(roundTripped.email, user.email);
    });
  });

  group('UserModel.copyWith', () {
    final base = UserModel(
      uid: 1,
      displayName: 'Bob',
      avatarUrl: 'url',
      millet: 10,
      email: 'bob@example.com',
      createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
    );

    test('未傳入的欄位維持原值', () {
      final copy = base.copyWith(millet: 20);

      expect(copy.uid, base.uid);
      expect(copy.displayName, base.displayName);
      expect(copy.avatarUrl, base.avatarUrl);
      expect(copy.avatarId, base.avatarId);
      expect(copy.ownedAvatarIds, base.ownedAvatarIds);
      expect(copy.millet, 20);
    });

    test('可更新頭像相關欄位', () {
      final copy = base.copyWith(
        avatarId: 'avatar_09',
        ownedAvatarIds: ['avatar_09'],
        frameId: 'frame_09',
        ownedFrameIds: ['frame_09'],
      );

      expect(copy.avatarId, 'avatar_09');
      expect(copy.ownedAvatarIds, ['avatar_09']);
      expect(copy.frameId, 'frame_09');
      expect(copy.ownedFrameIds, ['frame_09']);
      // 其餘欄位不受影響
      expect(copy.uid, base.uid);
      expect(copy.millet, base.millet);
    });
  });
}
