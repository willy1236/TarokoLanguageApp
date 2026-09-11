String _two(int n) => n.toString().padLeft(2, '0');

String formatDateTime(DateTime dt) {
  return '${dt.year}/${_two(dt.month)}/${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
}

/// 「9月」。
String monthLabel(DateTime dt) => '${dt.month}月';

const _weekdays = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];

/// 「週四」。
String weekdayLabel(DateTime dt) => _weekdays[dt.weekday - 1];

/// 「14:05」。
String formatTime(DateTime dt) => '${_two(dt.hour)}:${_two(dt.minute)}';
