// 出生日期欄位（POL-01）：完善資料頁與舊使用者補填頁共用，深色漸層背景樣式。
// 點選從底部彈出年／月／日三欄滾輪，範圍是 120 年前到台灣時間的今天（與後端檢查一致）。
// App 沒掛中文語系，CupertinoDatePicker 會顯示英文月份，所以自己組三欄。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../utils/birth_date.dart';

class BirthDateField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final bool seniorMode;

  const BirthDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.seniorMode = false,
  });

  Future<void> _pick(BuildContext context) async {
    final today = taiwanToday();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppColors.creamLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _BirthDateWheelSheet(
        initial: value ?? DateTime(today.year - 20, today.month, today.day),
        first: earliestBirthDate(),
        last: today,
        seniorMode: seniorMode,
      ),
    );
    if (picked == null) return;
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.creamLight.withValues(alpha: 0.08),
              border: Border.all(
                color: AppColors.cream.withValues(alpha: 0.18),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '出生日期',
                  style: TextStyle(
                    fontSize: AppTypography.size(
                      AppTypography.micro,
                      seniorMode: seniorMode,
                    ),
                    color: AppColors.cream.withValues(alpha: 0.65),
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value == null ? '請選擇出生日期' : formatDisplayDate(value!),
                        style: AppTypography.bodyLargeStyle(
                          seniorMode: seniorMode,
                          color: value == null
                              ? AppColors.cream.withValues(alpha: 0.35)
                              : AppColors.creamLight,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.cream.withValues(alpha: 0.5),
                      size: seniorMode ? 22 : 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Text(
            '用來確認是否年滿 18 歲，不會公開；填寫後無法自行修改',
            style: AppTypography.captionStyle(
              seniorMode: seniorMode,
              color: AppColors.cream.withValues(alpha: 0.55),
            ),
          ),
        ),
      ],
    );
  }
}

/// 年／月／日三欄滾輪；[first] 只看年份（1 月 1 日），[last] 之後的月、日不列出。
class _BirthDateWheelSheet extends StatefulWidget {
  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final bool seniorMode;

  const _BirthDateWheelSheet({
    required this.initial,
    required this.first,
    required this.last,
    required this.seniorMode,
  });

  @override
  State<_BirthDateWheelSheet> createState() => _BirthDateWheelSheetState();
}

class _BirthDateWheelSheetState extends State<_BirthDateWheelSheet> {
  late int _year;
  late int _month;
  late int _day;
  late final FixedExtentScrollController _yearCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _dayCtrl;

  int get _maxMonth => _year == widget.last.year ? widget.last.month : 12;

  int get _maxDay {
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    if (_year == widget.last.year && _month == widget.last.month) {
      return widget.last.day < daysInMonth ? widget.last.day : daysInMonth;
    }
    return daysInMonth;
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initial.isAfter(widget.last)
        ? widget.last
        : widget.initial.isBefore(widget.first)
            ? widget.first
            : widget.initial;
    _year = initial.year;
    _month = initial.month;
    _day = initial.day;
    _yearCtrl = FixedExtentScrollController(
      initialItem: _year - widget.first.year,
    );
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  // 年或月改變後，月、日超出新範圍就收回上限並把滾輪跟著轉過去。
  void _clampMonthAndDay() {
    if (_month > _maxMonth) {
      _month = _maxMonth;
      _monthCtrl.jumpToItem(_month - 1);
    }
    if (_day > _maxDay) {
      _day = _maxDay;
      _dayCtrl.jumpToItem(_day - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seniorMode = widget.seniorMode;
    final itemExtent = seniorMode ? 48.0 : 40.0;
    final itemStyle = AppTypography.bodyLargeStyle(
      seniorMode: seniorMode,
      color: AppColors.ink,
    );

    Widget wheel({
      required FixedExtentScrollController controller,
      required int count,
      required String Function(int index) label,
      required ValueChanged<int> onChanged,
    }) {
      return Expanded(
        child: CupertinoPicker(
          scrollController: controller,
          itemExtent: itemExtent,
          onSelectedItemChanged: onChanged,
          children: [
            for (var i = 0; i < count; i++)
              Center(child: Text(label(i), style: itemStyle)),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '取消',
                    style: AppTypography.bodyStyle(
                      seniorMode: seniorMode,
                      color: AppColors.fog,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '選擇出生日期',
                    textAlign: TextAlign.center,
                    style: AppTypography.subtitleStyle(
                      seniorMode: seniorMode,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, DateTime(_year, _month, _day)),
                  child: Text(
                    '確定',
                    style: AppTypography.bodyStyle(
                      seniorMode: seniorMode,
                      color: AppColors.primary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: itemExtent * 5,
              child: Row(
                children: [
                  wheel(
                    controller: _yearCtrl,
                    count: widget.last.year - widget.first.year + 1,
                    label: (i) => '${widget.first.year + i} 年',
                    onChanged: (i) => setState(() {
                      _year = widget.first.year + i;
                      _clampMonthAndDay();
                    }),
                  ),
                  wheel(
                    controller: _monthCtrl,
                    count: _maxMonth,
                    label: (i) => '${i + 1} 月',
                    onChanged: (i) => setState(() {
                      _month = i + 1;
                      _clampMonthAndDay();
                    }),
                  ),
                  wheel(
                    controller: _dayCtrl,
                    count: _maxDay,
                    label: (i) => '${i + 1} 日',
                    onChanged: (i) => setState(() => _day = i + 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
