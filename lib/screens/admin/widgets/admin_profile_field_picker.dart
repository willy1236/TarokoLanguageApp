// 個人檔案「要重設哪些欄位」的勾選清單，檢舉判定成立與管理員直接重設共用。
// 預設三項全選；父層用 [selected] 判斷至少一項才能送出。

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/admin_models.dart';

class AdminProfileFieldPicker extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool seniorMode;

  const AdminProfileFieldPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.seniorMode = false,
  });

  /// 預設：三項全選。
  static Set<String> get allFields => {
    for (final f in adminProfileFields) f.key,
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '要重設的欄位',
        style: AppTypography.subtitleStyle(
          seniorMode: seniorMode,
          color: AppColors.ink,
        ),
      ),
      for (final field in adminProfileFields)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.primary,
          dense: !seniorMode,
          title: Text(
            field.label,
            style: AppTypography.bodyLargeStyle(
              seniorMode: seniorMode,
              color: AppColors.ink,
            ),
          ),
          value: selected.contains(field.key),
          onChanged: (checked) => onChanged({
            ...selected.where((k) => k != field.key),
            if (checked ?? false) field.key,
          }),
        ),
      if (selected.isEmpty)
        Text(
          '至少要選一項',
          style: AppTypography.captionStyle(
            seniorMode: seniorMode,
            color: AppColors.dangerDark,
          ),
        ),
    ],
  );
}
