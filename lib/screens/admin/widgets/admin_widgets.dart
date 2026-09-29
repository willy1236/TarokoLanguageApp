// 後台畫面共用的小元件：畫面骨架、卡片、標籤、依狀態切換的分頁列表。

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../services/admin_service.dart';
import '../../../services/senior_mode_controller.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/truku_empty_state.dart';
import '../admin_error.dart';

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
      return Scaffold(
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
      );
    },
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

/// 「上方狀態切換＋下方分頁列表」的後台畫面，檢舉、違規區、題目回報共用。
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
  final _scroll = ScrollController();
  late String _status = widget.statuses.first.value;
  final List<T> _items = [];
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  /// 每次重載加一：切換狀態或重新整理時，晚回來的舊回應直接丟掉。
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final page = await widget.fetch(_status, null);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.pageInfo.nextCursor;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      if (handleAdminError(context, e, toast: false)) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (_loadingMore || _loading || cursor == null) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.fetch(_status, cursor);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.pageInfo.nextCursor;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _loadingMore = false);
      handleAdminError(context, e);
    }
  }

  void _selectStatus(String status) {
    if (status == _status) return;
    setState(() {
      _status = status;
      _items.clear();
      _cursor = null;
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: widget.title,
    body: (context, senior) => Column(
      children: [
        _statusBar(senior),
        Expanded(child: _content(senior)),
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

  Widget _content(bool senior) {
    if (_loading) return const TrukuLoadingView();
    if (_error != null) {
      return TrukuErrorView(
        error: _error,
        onRetry: _reload,
        seniorMode: senior,
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _reload,
      child: _items.isEmpty
          ? ListView(
              children: [
                TrukuEmptyState(
                  icon: Icons.inbox_outlined,
                  message: widget.emptyMessage,
                  subtitle: '',
                  seniorMode: senior,
                  scrollable: false,
                ),
              ],
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: _items.length + (_cursor != null ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }
                return widget.itemBuilder(context, _items[i], senior, _reload);
              },
            ),
    );
  }
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
