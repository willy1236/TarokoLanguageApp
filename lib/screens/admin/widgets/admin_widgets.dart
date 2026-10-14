// 後台畫面共用的小元件：畫面骨架、卡片、標籤、依狀態切換的分頁列表。

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../services/admin_service.dart';
import '../../../services/senior_mode_controller.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../admin_error.dart';
import 'admin_paged_list.dart';

/// 後台畫面骨架：返回鍵、標題、精簡模式連動。[body] 拿到目前是否精簡模式。
class AdminScaffold extends StatelessWidget {
  final String title;
  final Widget Function(BuildContext context, bool seniorMode) body;
  final List<Widget>? actions;
  final Widget Function(BuildContext context, bool seniorMode)? bottom;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: seniorModeController,
    builder: (context, _) {
      final senior = seniorModeController.enabled;
      return Theme(
        data: _lightTheme(Theme.of(context)),
        child: Scaffold(
          backgroundColor: AppColors.creamLight,
          appBar: AppBar(
            leading: const AppBackButton(),
            backgroundColor: AppColors.creamLight,
            elevation: 0,
            foregroundColor: AppColors.ink,
            title: Text(
              title,
              style: AppTypography.titleStyle(
                seniorMode: senior,
                color: AppColors.ink,
              ),
            ),
            actions: actions,
          ),
          body: body(context, senior),
          bottomNavigationBar: bottom?.call(context, senior),
        ),
      );
    },
  );
}

/// 後台畫面底色是淺色，但 App 全域主題是深色：輸入框、Chip、分段按鈕的預設文字與
/// 邊框會變成淺色（白字疊米白底）。這裡在後台範圍內換成淺色配色。
ThemeData _lightTheme(ThemeData base) {
  final scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.creamLight,
    // light() 預設的 secondary 是青色，Chip 切換動畫會閃過。
    secondary: AppColors.primary,
    onSecondary: AppColors.creamLight,
    secondaryContainer: AppColors.primary,
    onSecondaryContainer: AppColors.creamLight,
    surface: AppColors.creamLight,
    onSurface: AppColors.ink,
  );
  final border = OutlineInputBorder(
    borderSide: BorderSide(color: AppColors.ink.withValues(alpha: 0.35)),
  );
  return base.copyWith(
    colorScheme: scheme,
    // 下拉選單、彈出選單的底色取自 canvasColor／cardColor，copyWith 不會跟著 scheme 變。
    canvasColor: AppColors.creamLight,
    cardColor: AppColors.creamLight,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      labelStyle: TextStyle(color: AppColors.ink.withValues(alpha: 0.7)),
      hintStyle: TextStyle(color: AppColors.ink.withValues(alpha: 0.45)),
      helperStyle: TextStyle(color: AppColors.ink.withValues(alpha: 0.6)),
      prefixIconColor: AppColors.ink.withValues(alpha: 0.6),
      suffixIconColor: AppColors.primary,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.creamLight,
      selectedColor: AppColors.primary,
      surfaceTintColor: Colors.transparent,
      side: BorderSide(color: AppColors.ink.withValues(alpha: 0.3)),
      checkmarkColor: AppColors.creamLight,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.creamLight
              : AppColors.ink,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.creamLight,
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: AppColors.ink.withValues(alpha: 0.3)),
        ),
      ),
    ),
  );
}

/// 內容卡片。[onTap] 為 null 時不可點。
class AdminCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool seniorMode;

  const AdminCard({
    super.key,
    required this.child,
    this.onTap,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: seniorMode ? AppSpacing.sm : AppSpacing.xs,
    ),
    child: Material(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(seniorMode ? AppSpacing.md : 12),
          child: child,
        ),
      ),
    ),
  );
}

/// 小標籤（狀態、類型）。
class AdminBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool seniorMode;

  const AdminBadge(
    this.label, {
    super.key,
    this.color = AppColors.goldDeep,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: seniorMode ? 4 : 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: AppTypography.captionStyle(seniorMode: seniorMode, color: color),
    ),
  );
}

/// 一行「標籤：內容」。
class AdminInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool seniorMode;

  const AdminInfoRow(
    this.label,
    this.value, {
    super.key,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label：',
            style: AppTypography.bodyStyle(
              seniorMode: seniorMode,
              color: AppColors.fog,
            ),
          ),
          TextSpan(
            text: value,
            style: AppTypography.bodyStyle(
              seniorMode: seniorMode,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 內容區塊（預覽的文字方塊）。
class AdminQuote extends StatelessWidget {
  final String text;
  final bool seniorMode;

  const AdminQuote(this.text, {super.key, this.seniorMode = false});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.creamLight,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Text(
      text,
      style: AppTypography.bodyLargeStyle(
        seniorMode: seniorMode,
        color: AppColors.inkSoft,
      ),
    ),
  );
}

typedef AdminStatusOption = ({String label, String value});

/// 「上方狀態切換＋下方分頁列表」的後台畫面，檢舉、違規區、申訴、禁言、題目回報共用；
/// 翻頁狀態在 [AdminPagedListController]。
///
/// [fetch] 每次以狀態與游標取一頁；捲到底時用 `pageInfo.nextCursor` 載下一頁，
/// 下拉重新整理回到第一頁。[itemBuilder] 拿到 `reload`：子畫面處理完一筆回來後
/// 呼叫，列表改以伺服器最新狀態為準（連帶結案的其他筆也會一起消失）。
class AdminStatusListScreen<T> extends StatefulWidget {
  final String title;
  final List<AdminStatusOption> statuses;
  final Future<AdminPage<T>> Function(String status, String? cursor) fetch;
  final Widget Function(
    BuildContext context,
    T item,
    bool seniorMode,
    Future<void> Function() reload,
  )
  itemBuilder;
  final String emptyMessage;

  const AdminStatusListScreen({
    super.key,
    required this.title,
    required this.statuses,
    required this.fetch,
    required this.itemBuilder,
    this.emptyMessage = '目前沒有資料',
  });

  @override
  State<AdminStatusListScreen<T>> createState() =>
      _AdminStatusListScreenState<T>();
}

class _AdminStatusListScreenState<T> extends State<AdminStatusListScreen<T>> {
  late String _status = widget.statuses.first.value;
  late final AdminPagedListController<T> _list = AdminPagedListController<T>(
    fetch: (cursor) => widget.fetch(_status, cursor),
    onError: (e) => mounted && handleAdminError(context, e, toast: false),
  );

  @override
  void initState() {
    super.initState();
    _list.reload();
  }

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  void _selectStatus(String status) {
    if (status == _status) return;
    setState(() => _status = status);
    _list.reset();
  }

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: widget.title,
    body: (context, senior) => Column(
      children: [
        // 只有一種狀態（例如禁言列表）就不必顯示切換列。
        if (widget.statuses.length > 1) _statusBar(senior),
        Expanded(
          child: AdminPagedListView<T>(
            controller: _list,
            seniorMode: senior,
            emptyMessage: widget.emptyMessage,
            itemBuilder: (context, item) =>
                widget.itemBuilder(context, item, senior, _list.reload),
          ),
        ),
      ],
    ),
  );

  Widget _statusBar(bool senior) => SizedBox(
    width: double.infinity,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        children: [
          for (final option in widget.statuses)
            ChoiceChip(
              label: Text(
                option.label,
                style: AppTypography.bodyStyle(
                  seniorMode: senior,
                  color: option.value == _status
                      ? AppColors.creamLight
                      : AppColors.ink,
                ),
              ),
              selected: option.value == _status,
              selectedColor: AppColors.primary,
              onSelected: (_) => _selectStatus(option.value),
            ),
        ],
      ),
    ),
  );
}

/// 後端沒有查單筆的端點：沿 [fetch] 的分頁找 [matches] 的那一筆。
///
/// - 找到：`found` 是伺服器上的最新資料。
/// - 翻完都沒有：`gone` 為 true，代表這筆已不在這個狀態（通常是被其他管理員處理了）。
/// - 翻了 [maxPages] 頁還沒找到也沒翻完：兩者皆空，呼叫端維持原狀。
Future<({T? found, bool gone})> findInAdminPages<T>(
  Future<AdminPage<T>> Function(String? cursor) fetch,
  bool Function(T item) matches, {
  int maxPages = 10,
}) async {
  String? cursor;
  for (var i = 0; i < maxPages; i++) {
    final page = await fetch(cursor);
    for (final item in page.items) {
      if (matches(item)) return (found: item, gone: false);
    }
    cursor = page.pageInfo.nextCursor;
    if (cursor == null) return (found: null, gone: true);
  }
  return (found: null, gone: false);
}

/// 分頁列表的尾端：載入下一頁時轉圈；失敗時顯示「載入失敗，點此重試」，
/// 點了才重送（列表在失敗後不會因捲動自動重打）。
class AdminLoadMoreFooter extends StatelessWidget {
  final bool failed;
  final VoidCallback onRetry;
  final bool seniorMode;

  const AdminLoadMoreFooter({
    super.key,
    required this.failed,
    required this.onRetry,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Center(
      child: failed
          ? TextButton(
              onPressed: onRetry,
              child: Text(
                '載入失敗，點此重試',
                style: AppTypography.bodyLargeStyle(
                  seniorMode: seniorMode,
                  color: AppColors.primary,
                ),
              ),
            )
          : const CircularProgressIndicator(color: AppColors.primary),
    ),
  );
}

/// 只有一顆「知道了」的結果對話框（審核結果、處置說明）。
Future<void> showAdminInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
}) => showDialog<void>(
  context: context,
  builder: (ctx) => AppDialog(
    title: title,
    message: message,
    primaryText: '知道了',
    onPrimary: () => Navigator.pop(ctx),
  ),
);

/// 兩顆並排的操作按鈕列（畫面底部）。
class AdminActionBar extends StatelessWidget {
  final List<Widget> children;

  const AdminActionBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: children[i]),
          ],
        ],
      ),
    ),
  );
}
