// 後台模型解析：對照 test/fixtures/api_spec 裡照規格手寫的回應。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/admin_models.dart';
import 'package:flutter_application_1/models/user_model.dart';

import '../helpers/fixtures.dart';

void main() {
  group('AdminReport', () {
    final reports = [
      for (final r
          in loadSpecFixtureMap('get_api_admin_forum_reports.json')['reports']
              as List)
        AdminReport.fromJson(r as Map<String, dynamic>),
    ];

    test('貼文檢舉：預覽與檢舉人', () {
      final r = reports[0];
      expect(r.targetType, 'post');
      expect(r.targetPreview, '被檢舉貼文的標題');
      expect(r.reporterNickname, '小明');
      expect(r.targetDeleted, isFalse);
      expect(r.targetCall, isNull);
      expect(r.targetProfile, isNull);
    });

    test('內容已刪除', () => expect(reports[1].targetDeleted, isTrue));

    test('通話檢舉：帶 target_call、沒有預覽', () {
      final r = reports[2];
      expect(r.targetPreview, isNull);
      expect(r.targetDeleted, isFalse, reason: 'target_deleted 為 null 視為未刪除');
      expect(r.targetCall?.callerUid, 6);
      expect(r.targetCall?.calleeUid, 7);
      expect(r.targetCall?.endedAt, isNotNull);
    });

    test('個人檔案檢舉：帶 target_profile', () {
      final p = reports[3].targetProfile!;
      expect(p.uid, 9);
      expect(p.nickname, '不雅暱稱');
      expect(p.avatarUrl, 'https://example.com/a.webp');
    });

    test('舊寫法 reporter_name 仍讀得到', () {
      final r = AdminReport.fromJson({
        'id': 1,
        'target_type': 'post',
        'target_id': 1,
        'reason': 'x',
        'status': 'pending',
        'reporter_name': '舊欄位',
      });
      expect(r.reporterNickname, '舊欄位');
    });
  });

  test('UserModel.isAdmin 只有 admin 為 true', () {
    UserModel user(String? role) =>
        UserModel(uid: 1, email: '', createdAt: DateTime(2026), role: role);
    expect(user('admin').isAdmin, isTrue);
    expect(user('organizer').isAdmin, isFalse);
    expect(user('user').isAdmin, isFalse);
    expect(user(null).isAdmin, isFalse);
  });
}
