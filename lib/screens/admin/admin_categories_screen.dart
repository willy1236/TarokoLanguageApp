// 分類管理：文章、影音、活動三個分頁，各自列出全部分類與筆數，可新增、改名、調整排序。
// 規格：Truku_backend 說明文件/API/內部管理.md §6.1。
//
// 後端不提供刪除。`count` 算全部狀態（含草稿、下架、已結束）。
// 新增、修改成功後一律重抓清單：PATCH 回應沒有 count，不能拿來更新畫面。
// 也一併刷新 [CategoryService] 的快取，讓同一次啟動的前台名稱跟著變。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/content_category.dart';
import '../../services/admin_service.dart';
import '../../services/category_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/utils/utf16_length_limit.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/truku_empty_state.dart';
import 'admin_error.dart';
import 'widgets/admin_widgets.dart';

const int _sortOrderMax = 10000;

const Map<CategoryModule, String> _moduleLabels = {
  CategoryModule.articles: '文章',
  CategoryModule.videos: '影音',
  CategoryModule.events: '活動',
};

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen>
    with SingleTickerProviderStateMixin {
  /// 分頁順序（不用 `CategoryModule.values`：enum 的宣告順序是活動在前）。
  static const _modules = [
    CategoryModule.articles,
    CategoryModule.videos,
    CategoryModule.events,
  ];

  late final TabController _tabs = TabController(
    length: _modules.length,
    vsync: this,
  )..addListener(_onTab);

  final Map<CategoryModule, List<ContentCategory>> _lists = {};
  final Map<CategoryModule, Object> _errors = {};
  final Set<CategoryModule> _loading = {};

  /// 每個分頁的請求序號：重抓時晚回來的舊回應直接丟掉。
  final Map<CategoryModule, int> _generation = {};

  CategoryModule get _current => _modules[_tabs.index];

  @override
  void initState() {
    super.initState();
    _load(_current);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// 第一次切到某分頁才載入，之後切回來沿用已載入的清單。
  void _onTab() {
    final m = _current;
    if (!_lists.containsKey(m) && !_loading.contains(m) && _errors[m] == null) {
      _load(m);
    }
  }

  Future<void> _load(CategoryModule m) async {
    final generation = (_generation[m] ?? 0) + 1;
    _generation[m] = generation;
    setState(() {
      _loading.add(m);
      _errors.remove(m);
    });
    try {
      final list = await AdminService.fetchCategories(m);
      if (!mounted || _generation[m] != generation) return;
      setState(() {
        _lists[m] = list;
        _loading.remove(m);
      });
    } catch (e) {
      if (!mounted || _generation[m] != generation) return;
      if (handleAdminError(context, e, toast: false)) return;
      setState(() {
        _errors[m] = e;
        _loading.remove(m);
      });
    }
  }

  /// 讓前台快取也拿到新名稱；失敗不影響後台，前台下次打開會再抓。
  void _refreshAppCache(CategoryModule m) {
    CategoryService.fetch(m, refresh: true).then<void>(
      (_) {},
      onError: (Object e) => debugPrint('AdminCategoriesScreen: 前台分類快取刷新失敗：$e'),
    );
  }

  Future<void> _openDialog(CategoryModule m, {ContentCategory? editing}) async {
    final outcome = await showDialog<_DialogOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CategoryDialog(module: m, editing: editing),
    );
    if (outcome == null || !mounted) return;
    final error = outcome.error;
    if (error == null) {
      showAdminMessage(editing == null ? '已新增分類' : '已儲存');
      _refreshAppCache(m);
      _load(m);
      return;
    }
    if (error is ApiException && error.code == 'CATEGORY_NOT_FOUND') {
      showAdminMessage('這個分類已不存在');
      _load(m);
      return;
    }
    handleAdminError(context, error);
  }

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: '分類管理',
    actions: [
      IconButton(
        tooltip: '新增分類',
        icon: const Icon(Icons.add),
        onPressed: () => _openDialog(_current),
      ),
    ],
    body: (context, senior) => Column(
      children: [
        TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.inkSoft,
          indicatorColor: AppColors.primary,
          labelStyle: AppTypography.bodyLargeStyle(seniorMode: senior),
          unselectedLabelStyle: AppTypography.bodyLargeStyle(
            seniorMode: senior,
          ),
          tabs: [for (final m in _modules) Tab(text: _moduleLabels[m])],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [for (final m in _modules) _tab(m, senior)],
          ),
        ),
      ],
    ),
  );

  Widget _tab(CategoryModule m, bool senior) {
    final list = _lists[m];
    final error = _errors[m];
    if (error != null) {
      return TrukuErrorView(
        error: error,
        onRetry: () => _load(m),
        seniorMode: senior,
      );
    }
    if (list == null) return const TrukuLoadingView();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _load(m),
      child: list.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              children: [
                TrukuEmptyState(
                  icon: Icons.label_outline,
                  message: '還沒有分類',
                  subtitle: '',
                  seniorMode: senior,
                  scrollable: false,
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: list.length,
              itemBuilder: (context, i) => _row(m, list[i], senior),
            ),
    );
  }

  Widget _row(CategoryModule m, ContentCategory c, bool senior) => AdminCard(
    seniorMode: senior,
    onTap: () => _openDialog(m, editing: c),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.label,
                style: AppTypography.bodyLargeStyle(
                  seniorMode: senior,
                  color: AppColors.ink,
                ),
              ),
              // value 是送出用的代碼；與名稱相同時（新分類都是）不必重複顯示。
              if (c.value != c.label)
                Text(
                  '代碼 ${c.value}',
                  style: AppTypography.captionStyle(
                    seniorMode: senior,
                    color: AppColors.fog,
                  ),
                ),
              Text(
                '排序 ${c.sortOrder}',
                style: AppTypography.captionStyle(
                  seniorMode: senior,
                  color: AppColors.fog,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${c.count} 筆',
          style: AppTypography.bodyStyle(
            seniorMode: senior,
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        const Icon(Icons.edit_outlined, size: 18, color: AppColors.fog),
      ],
    ),
  );
}

/// 對話框的結果：[error] 為 null 代表成功。409 同名在對話框內處理，不會走到這裡。
class _DialogOutcome {
  final Object? error;

  const _DialogOutcome([this.error]);
}

/// 新增（[editing] 為 null）或編輯分類。送出由對話框自己做：
/// 同名時留在對話框顯示錯誤，其他錯誤關閉對話框交給畫面處理。
class _CategoryDialog extends StatefulWidget {
  final CategoryModule module;
  final ContentCategory? editing;

  const _CategoryDialog({required this.module, this.editing});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final _label = TextEditingController(text: widget.editing?.label);
  late final _sort = TextEditingController(
    text: widget.editing?.sortOrder.toString(),
  );
  bool _busy = false;
  String? _labelError;

  bool get _isEdit => widget.editing != null;

  @override
  void dispose() {
    _label.dispose();
    _sort.dispose();
    super.dispose();
  }

  String get _trimmedLabel => _label.text.trim();

  /// 排序欄空白＝不填；有填就要是 0～10000 的整數，否則回 -1。
  int? get _sortOrder {
    final text = _sort.text.trim();
    if (text.isEmpty) return null;
    final v = int.tryParse(text);
    return v != null && v >= 0 && v <= _sortOrderMax ? v : -1;
  }

  String? get _sortError =>
      _sortOrder == -1 ? '排序須為 0～$_sortOrderMax 的整數' : null;

  bool get _canSubmit =>
      !_busy &&
      _trimmedLabel.isNotEmpty &&
      _trimmedLabel.length <= categoryLabelMax &&
      _sortError == null;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final label = _trimmedLabel;
    final sortOrder = _sortOrder;
    final editing = widget.editing;
    if (editing != null) {
      final labelChanged = label != editing.label;
      final sortChanged = sortOrder != null && sortOrder != editing.sortOrder;
      if (!labelChanged && !sortChanged) {
        Navigator.pop(context);
        return;
      }
      await _send(
        () => AdminService.updateCategory(
          widget.module,
          editing.value,
          label: labelChanged ? label : null,
          sortOrder: sortChanged ? sortOrder : null,
        ),
      );
    } else {
      await _send(
        () => AdminService.createCategory(
          widget.module,
          label,
          sortOrder: sortOrder,
        ),
      );
    }
  }

  Future<void> _send(Future<Object?> Function() request) async {
    setState(() {
      _busy = true;
      _labelError = null;
    });
    try {
      await request();
      if (mounted) Navigator.pop(context, const _DialogOutcome());
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.code == 'CATEGORY_EXISTS') {
        setState(() {
          _busy = false;
          _labelError = '分類名稱已存在';
        });
        return;
      }
      Navigator.pop(context, _DialogOutcome(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final senior = seniorModeController.enabled;
    final fieldStyle = AppTypography.bodyLargeStyle(
      seniorMode: senior,
      color: AppColors.ink,
    );
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        backgroundColor: AppColors.creamLight,
        title: Text(
          '${_isEdit ? '編輯' : '新增'}${_moduleLabels[widget.module]}分類',
          style: AppTypography.titleStyle(
            seniorMode: senior,
            color: AppColors.ink,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEdit && widget.editing!.value != widget.editing!.label)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    '代碼 ${widget.editing!.value} 不會改變，已使用這個分類的內容不受影響。',
                    style: AppTypography.captionStyle(
                      seniorMode: senior,
                      color: AppColors.fog,
                    ),
                  ),
                ),
              TextField(
                controller: _label,
                enabled: !_busy,
                autofocus: true,
                style: fieldStyle,
                inputFormatters: const [
                  Utf16LengthLimitingTextInputFormatter(categoryLabelMax),
                ],
                buildCounter: utf16CounterBuilder(_label, categoryLabelMax),
                onChanged: (_) => setState(() => _labelError = null),
                decoration: InputDecoration(
                  labelText: '名稱（必填）',
                  errorText: _labelError,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _sort,
                enabled: !_busy,
                style: fieldStyle,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '排序（選填）',
                  helperText: _isEdit ? '數字小的排前面' : '數字小的排前面，不填為 100',
                  errorText: _sortError,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: AppColors.inkSoft)),
          ),
          TextButton(
            onPressed: _canSubmit ? _submit : null,
            child: Text(_isEdit ? '儲存' : '新增'),
          ),
        ],
      ),
    );
  }
}
