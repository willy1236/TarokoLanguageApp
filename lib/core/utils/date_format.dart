// 全 App 顯示給使用者看的日期時間格式，畫面不要自己組字串：
// 日期「2026/09/01」、時間 24 小時制「14:05」、日期時間「2026/09/01 14:05」。
// 送給後端的 YYYY-MM-DD／ISO 不走這裡。
//
// 後端時間是 UTC，這裡的函式都先轉本地再取年月日時分，
// 呼叫端不必自己 toLocal()，否則台灣凌晨 0～8 點的時間會差一天。

String _two(int n) => n.toString().padLeft(2, '0');

/// 「2026/09/01 14:05」。
String formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  return '${formatDate(local)} ${formatTime(local)}';
}

/// 「2026/09/01」。
String formatDate(DateTime dt) {
  final local = dt.toLocal();
  return '${local.year}/${_two(local.month)}/${_two(local.day)}';
}

/// 「14:05」。
String formatTime(DateTime dt) {
  final local = dt.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}';
}

/// 日期塊的月份「9月」。
String monthLabel(DateTime dt) => '${dt.toLocal().month}月';

/// 日期塊的日「01」，與 [formatDate] 一樣補零。
String dayLabel(DateTime dt) => _two(dt.toLocal().day);

const _weekdays = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];

/// 「週四」。
String weekdayLabel(DateTime dt) => _weekdays[dt.toLocal().weekday - 1];

/// 單字星期「四」，用在括號裡。
String weekdayShortLabel(DateTime dt) =>
    _weekdays[dt.toLocal().weekday - 1].substring(1);

/// 本地日期是否同一天。
bool isSameLocalDay(DateTime a, DateTime b) {
  final x = a.toLocal(), y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// 聊天室的日期分隔：「今天」「昨天」，今年更早「10月9日（五）」，往年
/// 「2025年10月9日（四）」。[now] 給測試固定今天用。
String chatDayLabel(DateTime dt, {DateTime? now}) {
  final local = dt.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  if (isSameLocalDay(local, today)) return '今天';
  if (isSameLocalDay(local, DateTime(today.year, today.month, today.day - 1))) {
    return '昨天';
  }
  final date = '${local.month}月${local.day}日（${weekdayShortLabel(local)}）';
  return local.year == today.year ? date : '${local.year}年$date';
}

/// 論壇、通知的時間標示：7 天內顯示「剛剛／N 分鐘前／N 小時前／N 天前」，
/// 超過改顯示本地日期，格式同 [formatDate]。
String formatRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '剛剛';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
  if (diff.inHours < 24) return '${diff.inHours} 小時前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return formatDate(time);
}
