// 四模組（影音/文章/活動/論壇）搜尋頁共用的搜尋列：AppBar 關鍵字輸入框 +
// 時間區間/部落篩選 Chip 列。四模組原本各自複製一份幾乎相同的程式碼，這裡
// 抽出共用版本；配色（深色影音文章 vs 淺色活動論壇）與論壇獨有的看板篩選
// 用參數/插槽處理，各模組的分頁邏輯（頁碼 vs 游標）維持在各自檔案不動。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../search_range.dart';
import 'tribe_picker_sheet.dart';
import '../../models/tribe_model.dart';

/// 搜尋列配色。影音/文章走深色（midnight/gold），活動/論壇走淺色（cream/primary）。
class SearchBarPalette {
  final Color background;
  final Color foreground;
  final Color accent; // 搜尋鈕、選中 chip 的強調色
  final Color soft; // hint、未選中文字
  final Color chipBackground;
  final Color chipBorder;
  final Color chipBorderSelected;
  final Color chipSelectedBackground;

  const SearchBarPalette({
    required this.background,
    required this.foreground,
    required this.accent,
    required this.soft,
    required this.chipBackground,
    required this.chipBorder,
    required this.chipBorderSelected,
    required this.chipSelectedBackground,
  });

  /// 深色版：影音、文章模組。
  static const dark = SearchBarPalette(
    background: AppColors.midnight,
    foreground: AppColors.creamLight,
    accent: AppColors.gold,
    soft: AppColors.fog,
    chipBackground: AppColors.midnightSoft,
    chipBorder: Color(0x26F2E8D5), // cream, alpha 0.15
    chipBorderSelected: Color(0x80C9A961), // gold, alpha 0.5
    chipSelectedBackground: Color(0x33C9A961), // gold, alpha 0.2
  );

  /// 淺色版：活動、論壇模組。
  static const light = SearchBarPalette(
    background: AppColors.creamLight,
    foreground: AppColors.ink,
    accent: AppColors.primary,
    soft: AppColors.inkSoft,
    chipBackground: AppColors.cream,
    chipBorder: AppColors.creamDeep,
    chipBorderSelected: Color(0x737A1F1A), // primary, alpha 0.45
    chipSelectedBackground: Color(0x297A1F1A), // primary, alpha 0.16
  );
}

/// 搜尋頁的 AppBar：關鍵字輸入框 + 搜尋鈕。
class ModuleSearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmit;
  final SearchBarPalette palette;
  final bool seniorMode;
  final double titleFontSize;

  const ModuleSearchAppBar({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSubmit,
    required this.palette,
    required this.seniorMode,
    required this.titleFontSize,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: palette.background,
      elevation: 0,
      foregroundColor: palette.foreground,
      title: TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(
          color: palette.foreground,
          fontSize: seniorMode ? titleFontSize : null,
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: palette.soft,
            fontSize: seniorMode ? titleFontSize : null,
          ),
          border: InputBorder.none,
        ),
      ),
      actions: [
        IconButton(
          onPressed: onSubmit,
          icon: Icon(
            Icons.search,
            color: palette.accent,
            size: seniorMode ? 30 : null,
          ),
        ),
      ],
    );
  }
}

/// 時間區間 + 部落篩選列，可選插入額外的 chip（論壇看板篩選）在最前面。
class ModuleSearchFilterRow extends StatelessWidget {
  final String? range;
  final ValueChanged<String?> onRangeSelected;
  final Tribe? tribe;
  final ValueChanged<Tribe?> onTribeSelected;
  final SearchBarPalette palette;
  final bool seniorMode;
  final double chipFontSize;

  /// 論壇看板篩選等模組特有的 chip，顯示在時間區間 chip 之前。
  final List<Widget> leading;

  const ModuleSearchFilterRow({
    super.key,
    required this.range,
    required this.onRangeSelected,
    required this.tribe,
    required this.onTribeSelected,
    required this.palette,
    required this.seniorMode,
    required this.chipFontSize,
    this.leading = const [],
  });

  Future<void> _pickTribe(BuildContext context) async {
    final picked = await showModalBottomSheet<Tribe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TribePickerSheet(),
    );
    if (picked == null) return;
    onTribeSelected(picked.id == kClearTribeId ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: seniorMode ? 64 : 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...leading,
          for (final r in SearchRange.values) _rangeChip(r),
          const SizedBox(width: 4),
          _tribeChip(context),
        ],
      ),
    );
  }

  Widget _rangeChip(String r) {
    final selected = range == r;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
      child: ChoiceChip(
        label: Text(SearchRange.label(r)),
        selected: selected,
        showCheckmark: false,
        backgroundColor: palette.chipBackground,
        selectedColor: palette.chipSelectedBackground,
        labelStyle: TextStyle(
          fontSize: seniorMode ? chipFontSize : 12,
          color: selected ? palette.accent : palette.soft,
        ),
        side: BorderSide(
          color: selected ? palette.chipBorderSelected : palette.chipBorder,
        ),
        onSelected: (_) => onRangeSelected(selected ? null : r),
      ),
    );
  }

  Widget _tribeChip(BuildContext context) {
    final selected = tribe != null;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: ActionChip(
        avatar: Icon(
          Icons.place_outlined,
          size: seniorMode ? 22 : 16,
          color: selected ? palette.accent : palette.soft,
        ),
        label: Text(tribe?.name ?? '部落'),
        backgroundColor: palette.chipBackground,
        labelStyle: TextStyle(
          fontSize: seniorMode ? chipFontSize : 12,
          color: selected ? palette.accent : palette.soft,
        ),
        side: BorderSide(
          color: selected ? palette.chipBorderSelected : palette.chipBorder,
        ),
        onPressed: () => _pickTribe(context),
      ),
    );
  }
}
