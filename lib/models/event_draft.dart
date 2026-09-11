import 'event_model.dart';

/// 發起／編輯活動表單的值物件：集中欄位、驗證與送出 body 的組裝，
/// 讓表單畫面只負責 TextEditingController ↔ EventDraft 的轉換。
///
/// 文字欄位保留使用者輸入的原樣，trim 在驗證與組 body 時才做；
/// [maxParticipantsText] 也保留原字串，才能區分「留空＝不限」與「亂填」。
///
/// 後端契約（PATCH /api/events/:id）：只接受 [editableFields] 這七個欄位，
/// 空字串或 null 視為清空；title／starts_at／報名截止／名額不可改。
class EventDraft {
  final String title;
  final String description;
  final String location;
  final String address;
  final DateTime? startsAt;
  final DateTime? registrationDeadline;
  final String contactEmail;
  final String contactPhone;
  final String maxParticipantsText;
  final String? category; // null = 不分類
  final String reminderNote;

  const EventDraft({
    this.title = '',
    this.description = '',
    this.location = '',
    this.address = '',
    this.startsAt,
    this.registrationDeadline,
    this.contactEmail = '',
    this.contactPhone = '',
    this.maxParticipantsText = '',
    this.category,
    this.reminderNote = '',
  });

  factory EventDraft.fromDetail(EventDetail e) => EventDraft(
    title: e.title,
    description: e.description ?? '',
    location: e.location ?? '',
    address: e.address ?? '',
    startsAt: e.startsAt,
    registrationDeadline: e.registrationDeadline,
    contactEmail: e.contactEmail ?? '',
    contactPhone: e.contactPhone ?? '',
    maxParticipantsText: e.maxParticipants?.toString() ?? '',
    category: e.category,
    reminderNote: e.reminderNote ?? '',
  );

  /// 後端 PATCH 接受的欄位（JSON key）。
  static const editableFields = {
    'description',
    'location',
    'address',
    'contact_email',
    'contact_phone',
    'reminder_note',
    'category',
  };

  /// 名額：留空 = 不限（null）；格式錯誤時也回 null，先呼叫 [validate] 擋掉。
  int? get maxParticipants => int.tryParse(maxParticipantsText.trim());

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
    if (registrationDeadline != null) {
      body['registration_deadline'] = registrationDeadline!
          .toUtc()
          .toIso8601String();
    }
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
    return body;
  }

  /// PATCH body：只含可編輯且與 [original] 不同的欄位；清空送空字串。
  /// 回傳空 map 表示沒有變更（後端對空 body 回 400，呼叫端應略過）。
  Map<String, dynamic> toPatchBody(EventDetail original) {
    final before = _editableValues(EventDraft.fromDetail(original));
    final after = _editableValues(this);
    return {
      for (final key in editableFields)
        if (before[key] != after[key]) key: after[key],
    };
  }

  static Map<String, String> _editableValues(EventDraft d) => {
    'description': d.description.trim(),
    'location': d.location.trim(),
    'address': d.address.trim(),
    'contact_email': d.contactEmail.trim(),
    'contact_phone': d.contactPhone.trim(),
    'reminder_note': d.reminderNote.trim(),
    'category': d.category?.trim() ?? '',
  };
}
