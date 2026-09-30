// 收件匣：解析錄製的真實回應，以及「點一則之後去哪」的判斷。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/inbox_models.dart';

import '../helpers/fixtures.dart';

InboxItem _item({
  required String category,
  required String kind,
  String targetState = 'ok',
  int? postId,
  int? commentId,
  int? eventId,
  int? caseId,
}) => InboxItem(
  id: 1,
  category: category,
  kind: kind,
  title: '標題',
  isRead: false,
  createdAt: DateTime(2026, 9, 30),
  postId: postId,
  commentId: commentId,
  eventId: eventId,
  caseId: caseId,
  targetState: targetState,
);

void main() {
  test('解析錄製的列表：論壇回覆帶 actor，貼文已刪除時 body 為 null', () {
    final page = InboxPage.fromJson(loadFixtureMap('get_api_inbox.json'));

    expect(page.items, isNotEmpty);
    final reply = page.items.firstWhere((i) => i.category == 'forum');
    expect(reply.actor, isNotNull);
    expect(reply.postId, isNotNull);
    expect(page.pageInfo.hasMore, isFalse);
  });

  test('未讀數：依分類取值，null 取總數，缺欄位視為 0', () {
    final unread = InboxUnread.fromJson({
      'forum': 1,
      'event': 2,
      'moderation': 3,
      'announcement': 4,
      'total': 10,
    });
    expect(unread.of(null), 10);
    expect(unread.of(InboxCategory.forum), 1);
    expect(unread.of(InboxCategory.event), 2);
    expect(unread.of(InboxCategory.moderation), 3);
    expect(unread.of(InboxCategory.announcement), 4);
    expect(InboxUnread.fromJson(null), InboxUnread.empty);
  });

  group('inboxTargetFor', () {
    test('論壇回覆：開貼文並帶留言 id', () {
      final target = inboxTargetFor(
        _item(
          category: 'forum',
          kind: 'reply_comment',
          postId: 13,
          commentId: 8,
        ),
      );
      expect(target, isA<InboxOpenPost>());
      expect((target as InboxOpenPost).postId, 13);
      expect(target.commentId, 8);
    });

    test('貼文已刪除／下架：不開頁，只提示', () {
      final deleted = inboxTargetFor(
        _item(
          category: 'forum',
          kind: 'reply_post',
          postId: 5,
          targetState: 'deleted',
        ),
      );
      final removed = inboxTargetFor(
        _item(
          category: 'forum',
          kind: 'reply_post',
          postId: 5,
          targetState: 'removed',
        ),
      );
      expect((deleted as InboxGone).message, '貼文已被刪除');
      expect((removed as InboxGone).message, '貼文已被下架');
    });

    test('活動提醒、取消、部落新活動：開活動詳情（已取消也開）', () {
      for (final kind in ['event_reminder', 'event_cancelled', 'tribe_event']) {
        final target = inboxTargetFor(
          _item(
            category: 'event',
            kind: kind,
            eventId: 55,
            targetState: kind == 'event_cancelled' ? 'cancelled' : 'ok',
          ),
        );
        expect((target as InboxOpenEvent).eventId, 55, reason: kind);
      }
    });

    test('活動已刪除／下架：看 kind 或 target_state，不開頁', () {
      String message(String kind, String state) =>
          (inboxTargetFor(
                    _item(
                      category: 'event',
                      kind: kind,
                      eventId: 55,
                      targetState: state,
                    ),
                  )
                  as InboxGone)
              .message;

      expect(message('event_deleted', 'deleted'), '該活動已被刪除');
      expect(message('event_removed', 'removed'), '該活動已被下架');
      // 提醒當時還在，之後才被刪除或下架。
      expect(message('event_reminder', 'deleted'), '該活動已被刪除');
      expect(message('event_reminder', 'removed'), '該活動已被下架');
    });

    test('審核：有 case_id 開處置詳情，沒有就只顯示內文', () {
      final withCase = inboxTargetFor(
        _item(category: 'moderation', kind: 'case_opened', caseId: 31),
      );
      final lifted = inboxTargetFor(
        _item(category: 'moderation', kind: 'mute_lifted'),
      );
      expect((withCase as InboxOpenCase).caseId, 31);
      expect((lifted as InboxShowBody).refreshMe, isFalse);
    });

    test('帳號權限變更：顯示內文並重抓 /api/me', () {
      final target = inboxTargetFor(
        _item(category: 'moderation', kind: 'account_role'),
      );
      expect((target as InboxShowBody).refreshMe, isTrue);
    });

    test('公告：開公告內容頁', () {
      expect(
        inboxTargetFor(_item(category: 'announcement', kind: 'announcement')),
        isA<InboxOpenAnnouncement>(),
      );
    });
  });
}
