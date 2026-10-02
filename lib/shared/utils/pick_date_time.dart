import 'package:flutter/material.dart';

/// 依序跳出日期、時間選擇器，回傳合起來的本地時間；任一步取消回 null。
///
/// [initial] 的日期超出 [firstDate]～[lastDate] 時，日曆停在最近的邊界那天；
/// 時間選擇器一律帶 [initial] 的時分。
Future<DateTime?> pickDateTime(
  BuildContext context, {
  required DateTime initial,
  required DateTime firstDate,
  required DateTime lastDate,
  required String dateHelp,
  required String timeHelp,
}) async {
  final initialDate = initial.isBefore(firstDate)
      ? firstDate
      : (initial.isAfter(lastDate) ? lastDate : initial);
  final date = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: dateHelp,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    helpText: timeHelp,
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
