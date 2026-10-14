// 影片管理：列出所有影片（含處理中、失敗、已下架），依狀態、來源篩選、搜尋標題。
// 規格：Truku_backend 說明文件/API/內部管理.md §6.2。
//
// 處理中的影片靠下拉重新整理看狀態，不自動輪詢。
// 列尾選單由之後的功能加項目（編輯、下架、重新上傳），見 _rowActions。

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../models/admin_models.dart';
import '../../models/content_category.dart';
import '../../services/admin_service.dart';
import '../../services/category_service.dart';
import 'admin_error.dart';
import 'widgets/admin_paged_list.dart';
import 'widgets/admin_widgets.dart';

/// 標題搜尋上限，同後端 `q`。
const adminVideoSearchMax = 80;

/// 停止輸入多久後送出搜尋。
const _searchDebounce = Duration(milliseconds: 400);

// 「全部」不帶參數。
const _statuses = <AdminStatusOption>[
  (label: '全部', value: ''),
  (label: '處理中', value: 'processing'),
  (label: '已上架', value: 'ready'),
  (label: '失敗', value: 'failed'),
  (label: '已下架', value: 'archived'),
];

const _sources = <AdminStatusOption>[
  (label: '全部來源', value: ''),
  (label: '自家', value: 'hls'),
  (label: 'YouTube', value: 'youtube'),
];

/// 列尾選單的一個項目。
typedef _RowAction = ({String label, VoidCallback onSelected});

class AdminVideosScreen extends StatefulWidget {
  const AdminVideosScreen({super.key});

  @override
  State<AdminVideosScreen> createState() => _AdminVideosScreenState();
}

class _AdminVideosScreenState extends State<AdminVideosScreen> {
  String _status = '';
  String _source = '';
  String _query = '';
  final _search = TextEditingController();
  Timer? _debounce;

  late final AdminPagedListController<AdminVideo> _list =
      AdminPagedListController<AdminVideo>(
        fetch: (cursor) => AdminService.fetchVideos(
          status: _status,
          source: _source,
          q: _query,
          cursor: cursor,
        ),
        onError: (e) => mounted && handleAdminError(context, e, toast: false),
      );

  @override
  void initState() {
    super.initState();
    _list.reload();
    _loadCategoryLabels();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _list.dispose();
    super.dispose();
  }

  /// 列表只有分類代碼；抓一次影音分類清單，讓新增的分類也顯示名稱。
  /// 失敗就沿用內建對照，不影響列表。
  Future<void> _loadCategoryLabels() async {
    try {
      await CategoryService.fetch(CategoryModule.videos);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _selectStatus(String value) {
    if (value == _status) return;
    setState(() => _status = value);
    _list.reset();
  }

  void _selectSource(String value) {
    if (value == _source) return;
    setState(() => _source = value);
    _list.reset();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () => _applySearch(text));
  }

  void _applySearch(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query == _query) return;
    setState(() => _query = query);
    _list.reset();
  }

  /// 每一列的選單項目；沒有項目時不顯示選單鈕。
  List<_RowAction> _rowActions(AdminVideo video) => const [];

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: '影片管理',
    body: (context, senior) => Column(
      children: [
        _searchField(senior),
        _chips(_statuses, _status, _selectStatus, senior),
        const SizedBox(height: AppSpacing.xs),
        _chips(_sources, _source, _selectSource, senior),
        Expanded(
          child: AdminPagedListView<AdminVideo>(
            controller: _list,
            seniorMode: senior,
            emptyMessage: '沒有符合條件的影片',
            itemBuilder: (context, video) => _AdminVideoTile(
              key: ValueKey(video.id),
              video: video,
              seniorMode: senior,
              actions: _rowActions(video),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _searchField(bool senior) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      0,
    ),
    child: TextField(
      controller: _search,
      maxLength: adminVideoSearchMax,
      onChanged: _onSearchChanged,
      onSubmitted: _applySearch,
      textInputAction: TextInputAction.search,
      style: AppTypography.bodyLargeStyle(
        seniorMode: senior,
        color: AppColors.ink,
      ),
      decoration: const InputDecoration(
        hintText: '搜尋標題',
        prefixIcon: Icon(Icons.search),
        counterText: '',
        isDense: true,
      ),
    ),
  );

  Widget _chips(
    List<AdminStatusOption> options,
    String selected,
    ValueChanged<String> onSelected,
    bool senior,
  ) => SizedBox(
    width: double.infinity,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          for (final option in options)
            ChoiceChip(
              label: Text(
                option.label,
                style: AppTypography.bodyStyle(
                  seniorMode: senior,
                  color: option.value == selected
                      ? AppColors.creamLight
                      : AppColors.ink,
                ),
              ),
              selected: option.value == selected,
              selectedColor: AppColors.primary,
              onSelected: (_) => onSelected(option.value),
            ),
        ],
      ),
    ),
  );
}

Color _statusColor(String status) => switch (status) {
  'ready' => AppColors.moss,
  'failed' => AppColors.dangerDark,
  'archived' => AppColors.fog,
  _ => AppColors.goldDeep,
};

class _AdminVideoTile extends StatelessWidget {
  final AdminVideo video;
  final bool seniorMode;
  final List<_RowAction> actions;

  const _AdminVideoTile({
    super.key,
    required this.video,
    required this.seniorMode,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final failReason = video.failReason;
    return AdminCard(
      seniorMode: seniorMode,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumbnail(url: video.thumbnailUrl, seniorMode: seniorMode),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLargeStyle(
                    seniorMode: seniorMode,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    AdminBadge(
                      adminVideoStatusLabel(video.status),
                      color: _statusColor(video.status),
                      seniorMode: seniorMode,
                    ),
                    AdminBadge(
                      adminVideoSourceLabel(video.source),
                      color: AppColors.inkSoft,
                      seniorMode: seniorMode,
                    ),
                    AdminBadge(
                      CategoryService.labelOf(
                        CategoryModule.videos,
                        video.category,
                      ),
                      seniorMode: seniorMode,
                    ),
                  ],
                ),
                if (video.isFailed && failReason != null && failReason != '')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '失敗原因：$failReason',
                      style: AppTypography.captionStyle(
                        seniorMode: seniorMode,
                        color: AppColors.dangerDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (actions.isNotEmpty)
            PopupMenuButton<int>(
              tooltip: '更多操作',
              icon: const Icon(Icons.more_vert, color: AppColors.inkSoft),
              onSelected: (i) => actions[i].onSelected(),
              itemBuilder: (context) => [
                for (var i = 0; i < actions.length; i++)
                  PopupMenuItem(value: i, child: Text(actions[i].label)),
              ],
            ),
        ],
      ),
    );
  }
}

/// 16:9 縮圖；沒有縮圖（處理中、失敗）或載入失敗時顯示影片圖示。
class _Thumbnail extends StatelessWidget {
  final String? url;
  final bool seniorMode;

  const _Thumbnail({required this.url, required this.seniorMode});

  @override
  Widget build(BuildContext context) {
    final width = seniorMode ? 112.0 : 96.0;
    final placeholder = Container(
      color: AppColors.creamDeep,
      alignment: Alignment.center,
      child: const Icon(
        Icons.movie_outlined,
        key: ValueKey('admin-video-thumbnail-placeholder'),
        color: AppColors.fog,
      ),
    );
    final src = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        width: width,
        height: width * 9 / 16,
        child: src == null || src.isEmpty
            ? placeholder
            : Image.network(
                src,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
