import 'event_model.dart';
import 'picked_location.dart';

/// 發起／編輯活動表單的值物件：集中欄位、驗證與送出 body 的組裝，
/// 讓表單畫面只負責 TextEditingController ↔ EventDraft 的轉換。
///
/// 文字欄位保留使用者輸入的原樣，trim 在驗證與組 body 時才做；
/// [maxParticipantsText] 也保留原字串，才能區分「留空＝不限」與「亂填」。
///
/// 地點只有一個 [address] 輸入；後端仍要 location（列表、推播用的短名稱）
/// 與 address 兩個必填，location 由 [address] 推得，見 [location]。
/// 在地圖上選過位置時另外帶座標，見 [picked]。
///
/// 後端契約（PATCH /api/events/:id）：只接受 [editableFields]；省略＝不動，
/// 文字欄位送空字串或 null 皆為清空（title/location/address 不可清空），
/// 名額送 null＝不限名額。所有時間欄位（開始、結束、報名開始／截止）不可改。
class EventDraft {
  final String title;
  final String description;
  final String address;

  /// 在地圖上選的位置。地址欄改得跟選點時回填的不一樣，就當作手動地址，
  /// 座標與地點名稱都不再用（[_activePick]）。
  final PickedLocation? picked;
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
    this.address = '',
    this.picked,
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
    address: _pickedOf(e)?.address ?? _mergeAddress(e.location, e.address),
    picked: _pickedOf(e),
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
    'latitude',
    'longitude',
    'contact_email',
    'contact_phone',
    'reminder_note',
    'category',
    'max_participants',
    'tribe_id',
  };

  /// 有座標的活動，地點名稱是當初選點時的 Google 地點名稱（或截出的短名稱），
  /// 不是另外填的資訊，地址不跟它合併；名稱原樣保留，沒改地址時才不會被重新截取。
  static PickedLocation? _pickedOf(EventDetail e) {
    final lat = e.latitude;
    final lng = e.longitude;
    if (lat == null || lng == null) return null;
    return PickedLocation(
      name: e.location,
      address: e.address?.trim() ?? '',
      latitude: lat,
      longitude: lng,
    );
  }

  /// 舊活動的地點與地址是分開填的，合成一欄時兩邊的資訊都要留著：
  /// 地址已包含地點名稱就只用地址，否則接在前面。
  static String _mergeAddress(String? location, String? address) {
    final loc = location?.trim() ?? '';
    final addr = address?.trim() ?? '';
    if (loc.isEmpty || addr.contains(loc)) return addr;
    if (addr.isEmpty) return loc;
    return '$loc $addr';
  }

  /// 地圖選點仍有效（地址欄沒被改過）時回傳選點結果。
  PickedLocation? get _activePick {
    final p = picked;
    return p != null && p.address.trim() == address.trim() ? p : null;
  }

  /// 送給後端的地點名稱，列表卡片、搜尋結果、提醒推播都用它：
  /// 從地圖選到 Google 地點時用地點名稱，否則從地址截出。
  String get location {
    final name = _activePick?.name?.trim() ?? '';
    return name.isNotEmpty ? name : shortNameOf(address);
  }

  double? get latitude => _activePick?.latitude;
  double? get longitude => _activePick?.longitude;

  /// 從地址截出短名稱：有分隔符（逗號、頓號、斜線）取最後一段；否則去掉開頭的
  /// 郵遞區號與縣市、鄉鎮市區前綴；截完是空的就用原文。空白不算分隔符，
  /// 「富世村 12 號」才不會截成「號」。
  static String shortNameOf(String address) {
    final text = address.trim();
    final parts = text.split(RegExp(r'[,，、/／]'));
    final segments = parts.map((s) => s.trim()).where((s) => s.isNotEmpty);
    if (parts.length > 1 && segments.isNotEmpty) return segments.last;
    final stripped = text.replaceFirst(_regionPrefix, '').trim();
    return stripped.isEmpty ? text : stripped;
  }

  static final _regionPrefix = RegExp(
    r'^(\d{3,6}\s*)?(.{2,3}?[縣市])?(.{1,3}?[鄉鎮市區])?',
  );

  /// 名額：留空 = 不限（null）；格式錯誤時也回 null，先呼叫 [validate] 擋掉。
  int? get maxParticipants => int.tryParse(maxParticipantsText.trim());

  /// 後端的文字欄位長度上限，以 UTF-16 單位計（與 JS `.length` 一致）。
  static const titleMax = 100;
  static const descriptionMax = 2000;
  static const addressMax = 200;
  static const reminderNoteMax = 500;

  /// 活動最長時間（後端 INVALID_END_TIME 的上限）。
  static const maxDuration = Duration(days: 30);

  /// 回傳第一個錯誤訊息；null 表示可送出。
  /// [creating] 為 false（編輯模式）時時間欄位是唯讀的，不重驗。
  String? validate({required bool creating, required DateTime now}) {
    if (title.trim().isEmpty || description.trim().isEmpty) {
      return '請填寫所有必填欄位';
    }
    if (address.trim().isEmpty) return '請填寫地址';
    // 輸入框的 formatter 在組字中會先放行，直接送出時可能超過上限。
    for (final (label, text, max) in [
      ('活動名稱', title, titleMax),
      ('活動說明', description, descriptionMax),
      ('地址', address, addressMax),
      ('提醒事項', reminderNote, reminderNoteMax),
    ]) {
      if (text.trim().length > max) return '$label不能超過 $max 字';
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
    if (latitude != null) {
      body['latitude'] = latitude;
      body['longitude'] = longitude;
    }
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
    final body = {
      for (final key in editableFields)
        if (before[key] != after[key]) key: after[key],
    };
    // 後端要求座標成對：只往正北移動時經度沒變，也要一起送。
    if (body.containsKey('latitude') || body.containsKey('longitude')) {
      body['latitude'] = after['latitude'];
      body['longitude'] = after['longitude'];
    }
    return body;
  }

  static Map<String, Object?> _editableValues(EventDraft d) => {
    'title': d.title.trim(),
    'description': d.description.trim(),
    'location': d.location.trim(),
    'address': d.address.trim(),
    'latitude': d.latitude,
    'longitude': d.longitude,
    'contact_email': d.contactEmail.trim(),
    'contact_phone': d.contactPhone.trim(),
    'reminder_note': d.reminderNote.trim(),
    'category': d.category?.trim() ?? '',
    'max_participants': d.maxParticipants,
    'tribe_id': d.tribeId,
  };
}
