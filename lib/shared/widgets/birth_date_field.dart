// 出生日期欄位（POL-01）：完善資料頁與舊使用者補填頁共用，深色漸層背景樣式。
// 點選開日期選擇器，範圍是 120 年前到台灣時間的今天（與後端檢查一致）。

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
    final first = earliestBirthDate();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(today.year - 20, today.month, today.day),
      firstDate: first,
      lastDate: today,
      initialDatePickerMode: DatePickerMode.year,
      helpText: '選擇出生日期',
    );
    if (picked == null) return;
    onChanged(DateTime(picked.year, picked.month, picked.day));
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
