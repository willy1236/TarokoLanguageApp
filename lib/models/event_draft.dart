import 'event_model.dart';

/// 發起／編輯活動表單的值物件：集中欄位、驗證與送出 body 的組裝，
/// 讓表單畫面只負責 TextEditingController ↔ EventDraft 的轉換。
///
/// 文字欄位保留使用者輸入的原樣，trim 在驗證與組 body 時才做；
/// [maxParticipantsText] 也保留原字串，才能區分「留空＝不限」與「亂填」。
///
/// 後端契約（PATCH /api/events/:id）：只接受 [editableFields]；省略＝不動，
/// 文字欄位送空字串或 null 皆為清空（title/location/address 不可清空），
/// 名額送 null＝不限名額。所有時間欄位（開始、結束、報名開始／截止）不可改。
class EventDraft {
  final String title;
  final String description;
  final String location;
  final String address;
  final DateTime? startsAt;
  final DateTime? registrationDeadline;

  /// 報名開始，null = 建立即開放。
  final DateTime? registrationStartsAt;

  /// 活動結束，null = 後端預設開始後 3 小時（後端之後會改為必填）。
  final DateTime? endsAt;
  final String contactEmail;
  final String contactPhone;
  final String maxParticipantsText;
  final String? category; // null = 不分類
  final String reminderNote;

  /// 發起人自選的相關部落，null = 不標註；不可預設帶發起人自己的部落。
  final int? tribeId;

  /// 建立時推播給 [tribeId] 部落的成員；沒選部落時不送（後端會回
  /// 400 EVENT_TRIBE_REQUIRED）。只在建立時有效，編輯改標籤不會重新推播。
  final bool notifyTribe;

  const EventDraft({
    this.title = '',
    this.description = '',
    this.location = '',
    this.address = '',
    this.startsAt,
    this.registrationDeadline,
    this.registrationStartsAt,
    this.endsAt,
    this.contactEmail = '',
    this.contactPhone = '',
    this.maxParticipantsText = '',
    this.category,
    this.reminderNote = '',
    this.tribeId,
    this.notifyTribe = false,
  });

  factory EventDraft.fromDetail(EventDetail e) => EventDraft(
    title: e.title,
    description: e.description ?? '',
    location: e.location ?? '',
    address: e.address ?? '',
    startsAt: e.startsAt,
    registrationDeadline: e.registrationDeadline,
    registrationStartsAt: e.registrationStartsAt,
    endsAt: e.endsAt,
    contactEmail: e.contactEmail ?? '',
    contactPhone: e.contactPhone ?? '',
    maxParticipantsText: e.maxParticipants?.toString() ?? '',
    category: e.category,
    reminderNote: e.reminderNote ?? '',
    tribeId: e.tribeId,
  );

  /// 後端 PATCH 接受的欄位（JSON key）。
  static const editableFields = {
    'title',
    'description',
    'location',
    'address',
    'contact_email',
    'contact_phone',
    'reminder_note',
    'category',
    'max_participants',
    'tribe_id',
  };

  /// 名額：留空 = 不限（null）；格式錯誤時也回 null，先呼叫 [validate] 擋掉。
  int? get maxParticipants => int.tryParse(maxParticipantsText.trim());

  /// 活動最長時間（後端 INVALID_END_TIME 的上限）。
  static const maxDuration = Duration(days: 30);

  /// 回傳第一個錯誤訊息；null 表示可送出。
  /// [creating] 為 false（編輯模式）時時間欄位是唯讀的，不重驗。
  String? validate({required bool creating, required DateTime now}) {
    if (title.trim().isEmpty ||
        description.trim().isEmpty ||
        location.trim().isEmpty ||
        address.trim().isEmpty) {
      return '請填寫所有必填欄位';
    }
    if (maxParticipantsText.trim().isNotEmpty) {
      final n = maxParticipants;
      if (n == null || n < 1) return '名額上限需為正整數，或留空表示不限';
    }
    if (!creating) return null;
    final starts = startsAt;
    if (starts == null) return '請選擇活動開始時間';
    if (!starts.isAfter(now)) return '活動時間需為未來';
    final deadline = registrationDeadline;
    if (deadline != null && deadline.isAfter(starts)) {
      return '報名截止時間不能晚於活動開始時間';
    }
    final ends = endsAt;
    if (ends != null) {
      if (!ends.isAfter(starts)) return '活動結束時間需晚於開始時間';
      if (ends.difference(starts) > maxDuration) return '活動最長 30 天';
    }
    final regStart = registrationStartsAt;
    if (regStart != null) {
      if (!regStart.isAfter(now)) return '報名開始時間需為未來，或留空表示立即開放';
      if (!regStart.isBefore(starts)) return '報名開始時間需早於活動開始時間';
      if (deadline != null && !regStart.isBefore(deadline)) {
        return '報名開始時間需早於報名截止時間';
      }
    }
    return null;
  }

  /// POST /api/events 的 body；選填欄位空白就不送。需先通過 [validate]。
  Map<String, dynamic> toCreateBody() {
    final body = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'location': location.trim(),
      'address': address.trim(),
      'starts_at': startsAt!.toUtc().toIso8601String(),
    };
    void time(String key, DateTime? value) {
      if (value != null) body[key] = value.toUtc().toIso8601String();
    }

    time('registration_deadline', registrationDeadline);
    time('registration_starts_at', registrationStartsAt);
    time('ends_at', endsAt);
    void optional(String key, String? value) {
      final v = value?.trim() ?? '';
      if (v.isNotEmpty) body[key] = v;
    }

    optional('contact_email', contactEmail);
    optional('contact_phone', contactPhone);
    optional('reminder_note', reminderNote);
    optional('category', category);
    final max = maxParticipants;
    if (max != null) body['max_participants'] = max;
    final tribe = tribeId;
    if (tribe != null) {
      body['tribe_id'] = tribe;
      if (notifyTribe) body['notify_tribe'] = true;
    }
    return body;
  }

  /// PATCH body：只含可編輯且與 [original] 不同的欄位；文字清空送空字串，
  /// 名額留空送 null（不限名額）。需先通過 [validate]。
  /// 回傳空 map 表示沒有變更（後端對空 body 回 400，呼叫端應略過）。
  Map<String, dynamic> toPatchBody(EventDetail original) {
    final before = _editableValues(EventDraft.fromDetail(original));
    final after = _editableValues(this);
    return {
      for (final key in editableFields)
        if (before[key] != after[key]) key: after[key],
    };
  }

  static Map<String, Object?> _editableValues(EventDraft d) => {
    'title': d.title.trim(),
    'description': d.description.trim(),
    'location': d.location.trim(),
    'address': d.address.trim(),
    'contact_email': d.contactEmail.trim(),
    'contact_phone': d.contactPhone.trim(),
    'reminder_note': d.reminderNote.trim(),
    'category': d.category?.trim() ?? '',
    'max_participants': d.maxParticipants,
    'tribe_id': d.tribeId,
  };
}
