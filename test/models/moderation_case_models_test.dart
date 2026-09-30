// 處置詳情：錄製帳號沒有被處置過，回應依規格範例（收件匣與申訴.md §3）。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/moderation_case_models.dart';

import '../helpers/fixtures.dart';

void main() {
  test('規格範例：已確認違規、可申訴', () {
    final c = MyModerationCase.fromJson(
      loadSpecFixtureMap('get_api_me_moderation_case.json'),
    );

    expect(c.id, 31);
    expect(c.targetType, 'post');
    expect(c.status, 'confirmed');
    expect(c.reason, '廣告洗版');
    expect(c.preview.title, '違規標題');
    expect(c.preview.body, '違規內文');
    expect(c.penalty!.strikeNumber, 1);
    expect(c.penalty!.muteUntil, DateTime.utc(2026, 10, 14, 8).toLocal());
    expect(c.penalty!.muteLifted, isFalse);
    expect(c.penalty!.locked, isFalse);
    expect(c.appeal, isNull);
    expect(c.canAppeal, isTrue);
    expect(c.appealDeadline, DateTime.utc(2026, 10, 30, 8).toLocal());
  });

  test('各類型的 preview：活動用 description 當內文、私訊與通話帶時間、個人檔案帶重設前的值', () {
    MyCasePreview preview(Object? raw) => MyCasePreview.fromJson(raw);

    final event = preview({'title': '走讀', 'description': '活動說明'});
    expect(event.title, '走讀');
    expect(event.body, '活動說明');

    expect(preview({'body': '留言', 'post_id': 3}).body, '留言');
    expect(
      preview({'body': '私訊', 'sent_at': '2026-09-30T08:00:00Z'}).time,
      isNotNull,
    );
    expect(preview({'started_at': '2026-09-30T08:00:00Z'}).time, isNotNull);
    expect(
      preview({
        'before': {'video_nickname': '舊暱稱'},
      }).profileBefore,
      {'video_nickname': '舊暱稱'},
    );
    // 自動禁言案件沒有內容。
    expect(preview(null).isEmpty, isTrue);
  });

  test('待審或已撤銷沒有處罰；已申訴帶申訴狀態與回覆', () {
    final c = MyModerationCase.fromJson({
      'case': {
        'id': 5,
        'target_type': 'comment',
        'status': 'overturned',
        'reason': '經其他使用者檢舉，管理員判定違反社群規範',
        'penalty': null,
        'preview': {'body': '留言', 'post_id': 9},
      },
      'appeal': {
        'id': 7,
        'status': 'accepted',
        'reason': '我沒有違規',
        'reply': '經複查後撤銷',
        'created_at': '2026-09-30T10:00:00Z',
        'handled_at': '2026-10-01T10:00:00Z',
      },
      'can_appeal': false,
      'appeal_deadline': '2026-10-30T08:00:00Z',
    });

    expect(c.penalty, isNull);
    expect(c.appeal!.status, 'accepted');
    expect(c.appeal!.reply, '經複查後撤銷');
    expect(c.canAppeal, isFalse);
  });

  test('送出申訴後：帶上申訴、不能再申訴', () {
    final c = MyModerationCase.fromJson(
      loadSpecFixtureMap('get_api_me_moderation_case.json'),
    );
    final appeal = MyAppeal.fromJson(
      loadSpecFixtureMap('post_api_me_moderation_case_appeal.json')['appeal']
          as Map<String, dynamic>,
    );

    final updated = c.withAppeal(appeal);

    expect(updated.appeal!.status, 'pending');
    expect(updated.canAppeal, isFalse);
  });

  test('狀態文案', () {
    expect(moderationCaseStatusLabel('pending'), '待複審');
    expect(moderationCaseStatusLabel('confirmed'), '已確認');
    expect(moderationCaseStatusLabel('overturned'), '已撤銷');
    expect(appealStatusLabel('pending'), '處理中');
    expect(appealStatusLabel('accepted'), '已成立');
    expect(appealStatusLabel('rejected'), '已駁回');
  });
}
