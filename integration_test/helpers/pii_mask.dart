// JSON 個資遮罩。
//
// 獨立成一個檔案（不依賴 flutter_test）是為了讓開發機上的
// tool/remask_fixtures.dart 也能 `dart run` 直接重用同一份名單——
// 遮罩規則只能有一份，複製一份到工具裡遲早會走鐘。

/// 遮罩後仍保留原型別的替代值。fixture 會被餵進 model.fromJson，
/// 所以不能把字串換成別的型別，也不能把欄位刪掉。
const Map<String, String> kStringMasks = {
  'email': 'redacted@example.com',
  'contact_email': 'redacted@example.com',
  'notification_email': 'redacted@example.com',
  'contact_phone': '0900000000',
  'phone': '0900000000',
  'display_name': '測試使用者',
  'video_nickname': '測試暱稱',
  'tribal_name': '測試族名',
  'tribe_name': '測試部落',
  'ethnic_group': '測試族群',
  'friend_code': 'TESTCODE',
  'avatar_url': 'https://example.com/avatar.png',
  'token': 'REDACTED',
  'id_token': 'REDACTED',
  'access_token': 'REDACTED',
  'refresh_token': 'REDACTED',
  'rtc_token': 'REDACTED',
  'fcm_token': 'REDACTED',
  'app_id': 'REDACTED',
  'device_id': 'REDACTED',
  'firebase_uid': 'REDACTED',
  // 使用者產生的內容：貼文、留言、活動描述等。
  // 契約驗的是「這個欄位是不是非空字串」，不是內容本身，
  // 所以換成固定假文字不影響防線，卻能讓 fixture 不夾帶任何真實發文。
  'title': '測試標題',
  'body': '測試內文',
  'content': '測試內文',
  'content_md': '測試內文',
  'summary': '測試摘要',
  'description': '測試描述',
  'comment': '測試留言',
  'location': '測試地點',
  'address': '測試地址',
};

/// 自由文字裡也可能夾著 email 或電話，那些不會落在上面的欄位名單裡。
/// 這層對「每一個字串值」再掃一次，接住沒有專屬欄位名的個資。
final RegExp _emailInText = RegExp(
  r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
);

/// 09xx-xxxxxx 手機與 0x-xxxxxxxx 市話。前後用非數字英文界定，
/// 避免把 UUID 或時間戳裡剛好長得像電話的片段也改掉。
final RegExp _phoneInText = RegExp(
  r'(?<![0-9A-Za-z])0(?:9[0-9]{2}[- ]?[0-9]{6}|[1-8][0-9]?[- ]?[0-9]{6,8})'
  r'(?![0-9A-Za-z])',
);

String _scrubFreeText(String value) => value
    .replaceAll(_emailInText, 'redacted@example.com')
    .replaceAll(_phoneInText, '0900000000');

/// 遞迴遮罩 JSON 中的個資，保留結構與型別。
///
/// 兩層防線：欄位名單（精準、換成有意義的假值），以及對所有字串做的
/// 自由文字掃描（兜底）。
Object? maskPii(Object? json) {
  if (json is List) return json.map(maskPii).toList();
  if (json is String) return _scrubFreeText(json);
  if (json is! Map) return json;
  final out = <String, dynamic>{};
  json.forEach((key, value) {
    final k = key.toString();
    final mask = kStringMasks[k];
    if (mask != null && value is String) {
      out[k] = mask;
    } else {
      out[k] = maskPii(value);
    }
  });
  return out;
}
