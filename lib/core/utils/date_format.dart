// 日期時間的顯示格式。後端時間是 UTC，這裡的函式都先轉本地再取年月日時分，
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

/// 「9月」。
String monthLabel(DateTime dt) => '${dt.toLocal().month}月';

const _weekdays = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];

/// 「週四」。
String weekdayLabel(DateTime dt) => _weekdays[dt.toLocal().weekday - 1];

/// 「14:05」。
String formatTime(DateTime dt) {
  final local = dt.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}';
}

/// 論壇、通知的時間標示：7 天內顯示「剛剛／N 分鐘前／N 小時前／N 天前」，
/// 超過改顯示本地日期「2026/9/1」。
String formatRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '剛剛';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
  if (diff.inHours < 24) return '${diff.inHours} 小時前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  final local = time.toLocal();
  return '${local.year}/${local.month}/${local.day}';
}
