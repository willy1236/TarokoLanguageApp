// 出生日期（POL-01）的日期規則，與後端 backend/birthDate.ts 對齊：
// 只看年月日、以台灣時間的「今天」為準；不早於 120 年前以年份判斷。
// 規格：Truku_backend 說明文件/API/00_核心與認證.md §2.4a、用戶視訊.md。

const int _adultAge = 18;
const int _maxAgeYears = 120;

/// 台灣時間（UTC+8）的今天，只取年月日。
DateTime taiwanToday({DateTime? now}) {
  final t = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 8));
  return DateTime(t.year, t.month, t.day);
}

/// 可選的最早生日：120 年前那一年的 1 月 1 日（後端只比年份）。
DateTime earliestBirthDate({DateTime? now}) =>
    DateTime(taiwanToday(now: now).year - _maxAgeYears);

/// 送給後端的 `YYYY-MM-DD`：直接取年月日，不做時區換算。
String formatApiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// 顯示用的 `YYYY/MM/DD`。
String formatDisplayDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}/${_two(d.month)}/${_two(d.day)}';

/// 解析後端的 `YYYY-MM-DD`，格式不符回 null。
DateTime? parseApiDate(Object? value) {
  if (value is! String) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

/// [today] 當天是否已滿 18 歲；生日當天算滿，2/29 出生者非閏年 3/1 起算。
bool isAdultOn(DateTime birthDate, DateTime today) {
  var age = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age--;
  }
  return age >= _adultAge;
}

String _two(int n) => n.toString().padLeft(2, '0');
