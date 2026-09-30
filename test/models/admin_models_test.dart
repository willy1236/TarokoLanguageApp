// 後台模型解析：對照 test/fixtures/api_spec 裡照規格手寫的回應。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/admin_models.dart';

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

  group('檢舉當時的內容（target_snapshot／report_snapshot）', () {
    final reports = [
      for (final r
          in loadSpecFixtureMap(
                'get_api_admin_forum_reports_snapshot.json',
              )['reports']
              as List)
        AdminReport.fromJson(r as Map<String, dynamic>),
    ];

    test('貼文：當時的標題內文，檢舉後已修改', () {
      final r = reports[0];
      expect(r.targetChanged, isTrue);
      expect(r.targetSnapshot!.title, '檢舉當時的標題');
      expect(r.targetSnapshot!.body, '檢舉當時的內文');
      expect(r.targetPreview, '改過之後的標題');
    });

    test('活動：標題、說明、地點、地址', () {
      final s = reports[1].targetSnapshot!;
      expect(s.title, '當時的活動標題');
      expect(s.description, '當時的活動說明');
      expect(s.location, '當時的地點');
      expect(s.address, '當時的地址');
      expect(reports[1].targetChanged, isFalse);
    });

    test('個人檔案：有自訂頭像複本時帶 avatar_evidence_url', () {
      final s = reports[2].targetSnapshot!;
      expect(s.nickname, '當時的暱稱');
      expect(s.selfIntro, '當時的自介');
      expect(s.avatarEvidenceUrl, contains('evidence.webp'));
    });

    test('個人檔案：預設或商店頭像沒有複本，看 avatar_id', () {
      final s = reports[3].targetSnapshot!;
      expect(s.avatarEvidenceUrl, isNull);
      expect(s.avatarId, 'avatar_gold_03');
    });

    test('留言等沒有存證的類型、舊回應缺欄位：snapshot 為 null、視為未修改', () {
      expect(reports[4].targetSnapshot, isNull);
      expect(reports[4].targetChanged, isFalse);

      final old = AdminReport.fromJson({
        'id': 1,
        'target_type': 'post',
        'target_id': 1,
        'reason': 'x',
        'status': 'pending',
      });
      expect(old.targetSnapshot, isNull);
      expect(old.targetChanged, isFalse);
    });

    test('違規案件：開案那筆檢舉當時的內容與當事人好友碼', () {
      final cases = [
        for (final c
            in loadSpecFixtureMap(
                  'get_api_admin_moderation_cases_snapshot.json',
                )['cases']
                as List)
          AdminCase.fromJson(c as Map<String, dynamic>),
      ];

      expect(cases[0].offenderFriendCode, 'DDDD2345');
      expect(cases[0].reportSnapshot!.title, '檢舉當時的標題');
      expect(cases[1].reportSnapshot, isNull);
      // 解鎖後就地更新狀態時，這兩個欄位要留著。
      final unlocked = cases[0].withOffenderStatus('active');
      expect(unlocked.offenderFriendCode, 'DDDD2345');
      expect(unlocked.reportSnapshot, isNotNull);
    });
  });

  group('AdminCase', () {
    final cases = [
      for (final c
          in loadSpecFixtureMap('get_api_admin_moderation_cases.json')['cases']
              as List)
        AdminCase.fromJson(c as Map<String, dynamic>),
    ];

    test('七種類型的預覽各自解析成對應子型別', () {
      expect(cases.map((c) => c.preview.runtimeType).toList(), [
        PostCasePreview,
        CommentCasePreview,
        MessageCasePreview,
        CallCasePreview,
        EventCasePreview,
        MuteCasePreview,
        ProfileCasePreview,
      ]);
      expect((cases[0].preview as PostCasePreview).title, '違規標題');
      expect((cases[1].preview as CommentCasePreview).postId, 100);
      expect((cases[2].preview as MessageCasePreview).sentAt, isNotNull);
      expect((cases[3].preview as CallCasePreview).call.calleeUid, 4);
      expect((cases[4].preview as EventCasePreview).startsAt, isNotNull);
      expect((cases[5].preview as MuteCasePreview).scope, 'all');
    });

    test('個人檔案案件：重設前與目前並列，snapshot 保留', () {
      final c = cases[6];
      final p = c.preview as ProfileCasePreview;
      expect(p.before['video_nickname'], '不雅暱稱');
      expect(p.current!.nickname, '使用者9');
      expect(c.snapshot?['avatar_url'], 'https://example.com/a.webp');
    });

    test('自動禁言案件由系統開案；已審案件帶審核資訊', () {
      expect(cases[5].openedBy, isNull);
      expect(cases[5].openedByNickname, isNull);
      expect(cases[2].isPending, isFalse);
      expect(cases[2].reviewedByNickname, '管理員乙');
      expect(cases[2].strikeNumber, 3);
      expect(cases[2].offenderStatus, 'locked');
    });
  });

  test('AdminReviewResult：strike 用 camelCase，連帶取消活動數取清單長度', () {
    final result = AdminReviewResult.fromJson(
      loadSpecFixtureMap('post_api_admin_case_review_confirm.json'),
    );
    expect(result.reviewedCase.status, 'confirmed');
    expect(result.strike?.strikeNumber, 3);
    expect(result.strike?.locked, isTrue);
    expect(result.strike?.cancelledEventCount, 2);
    expect(result.autoLiftedMuteId, isNull);
  });

  test('AdminResolveResult：判定成立帶案件與連帶結案的檢舉', () {
    final result = AdminResolveResult.fromJson(
      loadSpecFixtureMap('post_api_admin_report_resolve_action.json'),
    );
    expect(result.status, 'actioned');
    expect(result.openedCase?.id, 7);
    expect(result.autoClosedReportIds, [501, 502]);

    final dismissed = AdminResolveResult.fromJson({
      'ok': true,
      'status': 'dismissed',
      'case': null,
      'auto_closed_report_ids': [],
      'auto_lifted_mute_id': 4,
    });
    expect(dismissed.openedCase, isNull);
    expect(dismissed.autoLiftedMuteId, 4);
  });

  test('AdminMute／AdminBannedWord／AdminQuestionReport 解析規格範例', () {
    final mutes = [
      for (final m
          in loadSpecFixtureMap('get_api_admin_mutes.json')['mutes'] as List)
        AdminMute.fromJson(m as Map<String, dynamic>),
    ];
    expect(mutes.map((m) => adminMuteReasonLabel(m.reason)), [
      '檢舉滿門檻',
      '違規累計',
      '髒話',
    ]);
    expect(mutes[2].scope, 'text');
    expect(mutes[0].muteUntil, isNotNull);

    final words = AdminBannedWord.fromJson({'id': 1, 'word': 'x'});
    expect((words.id, words.word), (1, 'x'));

    final reports = [
      for (final r
          in loadSpecFixtureMap(
                'get_api_admin_question_reports.json',
              )['reports']
              as List)
        AdminQuestionReport.fromJson(r as Map<String, dynamic>),
    ];
    expect(reports[0].contentTruku, 'Bsuring');
    expect(reports[0].reporterNickname, '小明');
    expect(reports[1].contentTruku, isNull, reason: '沒有對應單字或句子時為 null');
    expect(adminQuestionReportStatusLabel(reports[1].status), '已查看');
  });
}
