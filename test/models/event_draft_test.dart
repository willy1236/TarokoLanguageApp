import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/event_draft.dart';
import 'package:flutter_application_1/models/event_model.dart';

void main() {
  final now = DateTime(2026, 9, 11, 12);
  final future = DateTime(2026, 9, 20, 10);

  EventDraft valid({DateTime? startsAt, DateTime? deadline, String max = ''}) =>
      EventDraft(
        title: '走讀',
        description: '說明',
        address: '秀林鄉',
        startsAt: startsAt ?? future,
        registrationDeadline: deadline,
        maxParticipantsText: max,
      );

  EventDetail detail() => EventDetail(
    id: 1,
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
      expect(
        const EventDraft(
          title: '走讀',
          description: '說明',
          address: '  ',
        ).validate(creating: true, now: now),
        '請填寫地址',
      );
    });

    test('文字欄位超過後端長度上限（組字中直接送出）', () {
      String? check({
        String title = '走讀',
        String description = '說明',
        String address = '秀林鄉',
        String reminderNote = '',
      }) => EventDraft(
        title: title,
        description: description,
        address: address,
        reminderNote: reminderNote,
        startsAt: future,
      ).validate(creating: false, now: now);

      expect(check(title: 'a' * 100), isNull);
      expect(check(title: 'a' * 101), '活動名稱不能超過 100 字');
      // emoji 算 2，與後端 JS `.length` 一致。
      expect(check(title: '😀' * 51), '活動名稱不能超過 100 字');
      expect(check(description: 'a' * 2001), '活動說明不能超過 2000 字');
      expect(check(address: 'a' * 200), isNull);
      expect(check(address: 'a' * 201), '地址不能超過 200 字');
      expect(check(reminderNote: 'a' * 501), '提醒事項不能超過 500 字');
      // 後端 trim 後才比長度。
      expect(check(reminderNote: '${'a' * 500}  '), isNull);
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

    test('建立時檢查活動結束與報名開始', () {
      EventDraft withTimes({DateTime? ends, DateTime? regStart}) => EventDraft(
        title: '走讀',
        description: '說明',
        address: '秀林鄉',
        startsAt: future,
        endsAt: ends,
        registrationStartsAt: regStart,
      );
      expect(
        withTimes(ends: future).validate(creating: true, now: now),
        '活動結束時間需晚於開始時間',
      );
      expect(
        withTimes(
          ends: future.add(const Duration(days: 31)),
        ).validate(creating: true, now: now),
        '活動最長 30 天',
      );
      expect(
        withTimes(regStart: now).validate(creating: true, now: now),
        '報名開始時間需為未來，或留空表示立即開放',
      );
      expect(
        withTimes(regStart: future).validate(creating: true, now: now),
        '報名開始時間需早於活動開始時間',
      );
      final ok = withTimes(
        ends: future.add(const Duration(hours: 2)),
        regStart: now.add(const Duration(days: 1)),
      );
      expect(ok.validate(creating: true, now: now), isNull);
      final body = ok.toCreateBody();
      expect(
        body['ends_at'],
        future.add(const Duration(hours: 2)).toUtc().toIso8601String(),
      );
      expect(
        body['registration_starts_at'],
        now.add(const Duration(days: 1)).toUtc().toIso8601String(),
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

  group('地址', () {
    test('短名稱：有分隔符取最後一段', () {
      expect(EventDraft.shortNameOf('秀林鄉富世村 12 號／部落活動中心'), '部落活動中心');
      expect(EventDraft.shortNameOf('花蓮縣秀林鄉, 文蘭部落'), '文蘭部落');
      expect(EventDraft.shortNameOf('崇德、天祥'), '天祥');
      expect(EventDraft.shortNameOf('富世村/'), '富世村');
    });

    test('短名稱：空白不算分隔符，去掉郵遞區號與縣市鄉鎮前綴', () {
      expect(EventDraft.shortNameOf('花蓮縣秀林鄉富世村 12 號'), '富世村 12 號');
      expect(EventDraft.shortNameOf('972 花蓮縣秀林鄉富世村'), '富世村');
      expect(EventDraft.shortNameOf('臺北市信義區市府路 1 號'), '市府路 1 號');
      expect(EventDraft.shortNameOf('秀林鄉富世村'), '富世村');
      expect(EventDraft.shortNameOf('部落活動中心'), '部落活動中心');
    });

    test('短名稱：截完是空的用原文', () {
      expect(EventDraft.shortNameOf('花蓮縣秀林鄉'), '花蓮縣秀林鄉');
      expect(EventDraft.shortNameOf(' 秀林鄉 '), '秀林鄉');
    });

    test('送出時 location 由地址推得，address 送完整地址', () {
      final body = EventDraft(
        title: '走讀',
        description: '說明',
        address: ' 秀林鄉富世村 12 號／活動中心 ',
        startsAt: future,
      ).toCreateBody();
      expect(body['location'], '活動中心');
      expect(body['address'], '秀林鄉富世村 12 號／活動中心');
    });

    EventDetail old(String? location, String? address) => EventDetail(
      id: 1,
      title: 't',
      startsAt: future,
      location: location,
      address: address,
      status: 'active',
    );

    test('舊活動合成一欄時不丟任何一邊的資訊', () {
      expect(EventDraft.fromDetail(old('部落', '秀林鄉')).address, '部落 秀林鄉');
      expect(EventDraft.fromDetail(old('活動中心', '秀林鄉活動中心')).address, '秀林鄉活動中心');
      expect(EventDraft.fromDetail(old('秀林鄉', '秀林鄉')).address, '秀林鄉');
      expect(EventDraft.fromDetail(old(null, '秀林鄉')).address, '秀林鄉');
      expect(EventDraft.fromDetail(old('部落', null)).address, '部落');
    });

    test('沒改地址不送地點與地址；改了兩個都送', () {
      final e = old('部落', '秀林鄉');
      final d = EventDraft.fromDetail(e);
      expect(d.toPatchBody(e), isEmpty);
      final edited = EventDraft(
        title: d.title,
        description: d.description,
        address: '富世村／活動中心',
      );
      expect(edited.toPatchBody(e), {
        'location': '活動中心',
        'address': '富世村／活動中心',
      });
    });
  });

  group('相關部落', () {
    test('沒選部落時不送 tribe_id，也不送 notify_tribe', () {
      final body = EventDraft(
        title: 't',
        description: 'd',
        address: 'a',
        startsAt: future,
        notifyTribe: true,
      ).toCreateBody();
      expect(body.containsKey('tribe_id'), isFalse);
      expect(body.containsKey('notify_tribe'), isFalse);
    });

    test('選了部落才送 tribe_id 與 notify_tribe', () {
      final body = EventDraft(
        title: 't',
        description: 'd',
        address: 'a',
        startsAt: future,
        tribeId: 30,
        notifyTribe: true,
      ).toCreateBody();
      expect(body['tribe_id'], 30);
      expect(body['notify_tribe'], isTrue);
    });

    test('編輯清除部落送 tribe_id: null', () {
      final e = EventDetail(
        id: 1,
        title: 't',
        description: 'd',
        startsAt: future,
        location: 'l',
        address: 'a',
        tribeId: 30,
        status: 'active',
      );
      final d = EventDraft.fromDetail(e);
      final cleared = EventDraft(
        title: d.title,
        description: d.description,
        address: d.address,
        startsAt: d.startsAt,
      );
      expect(cleared.toPatchBody(e), {'tribe_id': null});
      expect(d.toPatchBody(e), isEmpty);
    });
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

    EventDraft editedFrom(
      EventDetail e, {
      String? title,
      String? max,
      DateTime? startsAt,
      DateTime? deadline,
    }) {
      final d = EventDraft.fromDetail(e);
      return EventDraft(
        title: title ?? d.title,
        description: d.description,
        address: d.address,
        startsAt: startsAt ?? d.startsAt,
        registrationDeadline: deadline ?? d.registrationDeadline,
        contactEmail: d.contactEmail,
        contactPhone: d.contactPhone,
        maxParticipantsText: max ?? d.maxParticipantsText,
        category: d.category,
        reminderNote: d.reminderNote,
      );
    }

    test('標題與名額可編輯，名額送 int', () {
      final e = detail();
      expect(editedFrom(e, title: ' 改標題 ', max: '99').toPatchBody(e), {
        'title': '改標題',
        'max_participants': 99,
      });
    });

    test('名額清空送 null（不限名額），不是空字串', () {
      final e = detail();
      final body = editedFrom(e, max: ' ').toPatchBody(e);
      expect(body, {'max_participants': null});
      expect(body.containsKey('max_participants'), isTrue);
    });

    test('時間欄位不可編輯，不會出現在 patch', () {
      final e = detail();
      expect(
        editedFrom(e, startsAt: now, deadline: now).toPatchBody(e),
        isEmpty,
      );
    });
  });
}
