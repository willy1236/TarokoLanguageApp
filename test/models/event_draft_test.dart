import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/event_draft.dart';
import 'package:flutter_application_1/models/event_model.dart';

void main() {
  final now = DateTime(2026, 9, 11, 12);
  final future = DateTime(2026, 9, 20, 10);

  EventDraft valid({
    DateTime? startsAt,
    DateTime? deadline,
    String max = '',
  }) => EventDraft(
    title: '走讀',
    description: '說明',
    location: '部落',
    address: '秀林鄉',
    startsAt: startsAt ?? future,
    registrationDeadline: deadline,
    maxParticipantsText: max,
  );

  EventDetail detail() => EventDetail(
    id: 1,
    hostUid: 9,
    title: '走讀',
    description: '說明',
    startsAt: future,
    location: '部落',
    address: '秀林鄉',
    contactEmail: 'a@b.c',
    reminderNote: '帶水',
    maxParticipants: 20,
    category: '走讀',
    status: 'active',
  );

  group('validate', () {
    test('必填欄位空白', () {
      expect(
        const EventDraft(title: ' ').validate(creating: true, now: now),
        '請填寫所有必填欄位',
      );
    });

    test('名額需為正整數，留空為不限', () {
      expect(valid(max: '0').validate(creating: true, now: now), isNotNull);
      expect(valid(max: 'abc').validate(creating: true, now: now), isNotNull);
      expect(valid(max: ' ').validate(creating: true, now: now), isNull);
      expect(valid(max: '5').validate(creating: true, now: now), isNull);
    });

    test('建立時檢查開始時間與報名截止', () {
      expect(
        const EventDraft(
          title: 't',
          description: 'd',
          location: 'l',
          address: 'a',
        ).validate(creating: true, now: now),
        '請選擇活動開始時間',
      );
      expect(
        valid(startsAt: now).validate(creating: true, now: now),
        '活動時間需為未來',
      );
      expect(
        valid(
          deadline: future.add(const Duration(hours: 1)),
        ).validate(creating: true, now: now),
        '報名截止時間不能晚於活動開始時間',
      );
    });

    test('編輯模式不驗唯讀的時間欄位', () {
      expect(valid(startsAt: now).validate(creating: false, now: now), isNull);
    });
  });

  test('toCreateBody 選填欄位空白不送、名額轉 int', () {
    final body = EventDraft(
      title: ' 走讀 ',
      description: '說明',
      location: '部落',
      address: '秀林鄉',
      startsAt: future,
      contactEmail: '  ',
      contactPhone: ' 0912 ',
      maxParticipantsText: '12',
      category: '',
    ).toCreateBody();
    expect(body['title'], '走讀');
    expect(body['contact_phone'], '0912');
    expect(body['max_participants'], 12);
    expect(body.containsKey('contact_email'), isFalse);
    expect(body.containsKey('category'), isFalse);
    expect(body.containsKey('reminder_note'), isFalse);
    expect(body['starts_at'], future.toUtc().toIso8601String());
  });

  group('toPatchBody', () {
    test('沒有變更回傳空 map', () {
      final e = detail();
      expect(EventDraft.fromDetail(e).toPatchBody(e), isEmpty);
    });

    test('只送有變動的欄位，清空送空字串', () {
      final e = detail();
      final d = EventDraft.fromDetail(e);
      final edited = EventDraft(
        title: d.title,
        description: '新說明',
        location: d.location,
        address: d.address,
        startsAt: d.startsAt,
        contactEmail: d.contactEmail,
        contactPhone: d.contactPhone,
        maxParticipantsText: d.maxParticipantsText,
        category: null,
        reminderNote: '',
      );
      expect(edited.toPatchBody(e), {
        'description': '新說明',
        'category': '',
        'reminder_note': '',
      });
    });

    test('不可編輯欄位不會出現在 patch', () {
      final e = detail();
      final d = EventDraft.fromDetail(e);
      final edited = EventDraft(
        title: '改標題',
        description: d.description,
        location: d.location,
        address: d.address,
        startsAt: now,
        contactEmail: d.contactEmail,
        maxParticipantsText: '99',
        category: d.category,
        reminderNote: d.reminderNote,
      );
      expect(edited.toPatchBody(e), isEmpty);
    });
  });
}
