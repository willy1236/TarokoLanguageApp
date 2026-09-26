// 發文／建立活動用的「相關部落」選填欄位。
//
// 預設不選，也不可預設帶入使用者自己的部落：這個標籤是作者自己決定要不要公開的，
// 後端改成作者自選正是為了不讓別人反推發文者屬於哪個部落。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/tribe_model.dart';
import 'tribe_picker_sheet.dart';

class RelatedTribeField extends StatelessWidget {
  final TribeTag? tribe;
  final ValueChanged<TribeTag?> onChanged;
  final bool seniorMode;

  const RelatedTribeField({
    super.key,
    required this.tribe,
    required this.onChanged,
    this.seniorMode = false,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showModalBottomSheet<Tribe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TribePickerSheet(clearLabel: '不標註部落'),
    );
    if (picked == null) return;
    onChanged(
      picked.id == kClearTribeId ? null : TribeTag(id: picked.id, name: picked.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = tribe;
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: seniorMode ? 14 : 10,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Row(
          children: [
            Icon(
              Icons.place_outlined,
              size: seniorMode ? 22 : 18,
              color: selected != null ? AppColors.primary : AppColors.fog,
            ),
            const SizedBox(width: 8),
            Text(
              '相關部落',
              style: AppTypography.serif(
                fontSize: AppTypography.size(
                  AppTypography.body,
                  seniorMode: seniorMode,
                ),
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected?.name ?? '選填，不標註',
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.serif(
                  fontSize: AppTypography.size(
                    AppTypography.caption,
                    seniorMode: seniorMode,
                  ),
                  fontWeight:
                      selected != null ? FontWeight.w600 : FontWeight.w400,
                  color: selected != null ? AppColors.primary : AppColors.fog,
                ),
              ),
            ),
            if (selected != null)
              IconButton(
                tooltip: '不標註部落',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close,
                  size: seniorMode ? 22 : 16,
                  color: AppColors.fog,
                ),
                onPressed: () => onChanged(null),
              )
            else
              Icon(Icons.chevron_right, color: AppColors.fog),
          ],
        ),
      ),
    );
  }
}

/// 內容上的「相關部落：xxx」標籤。刻意不寫成「作者部落」。
class RelatedTribeLabel extends StatelessWidget {
  final String name;
  final bool seniorMode;

  const RelatedTribeLabel({
    super.key,
    required this.name,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.place_outlined,
        size: seniorMode ? 18 : 13,
        color: AppColors.fog,
      ),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          '相關部落：$name',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppTypography.size(
              AppTypography.caption,
              seniorMode: seniorMode,
            ),
            color: AppColors.fog,
          ),
        ),
      ),
    ],
  );
}
