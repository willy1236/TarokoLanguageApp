// 影片管理：列出所有影片（含處理中、失敗、已下架），依狀態、來源篩選、搜尋標題。
// 規格：Truku_backend 說明文件/API/內部管理.md §6.2。
//
// 處理中的影片靠下拉重新整理看狀態，不自動輪詢。
// 右上角「上傳影片」開上傳頁，上架成功回來重抓第一頁。
// 列尾選單由之後的功能加項目（編輯、下架、重新上傳），見 _rowActions。
// 下架回 files_deleted: false 時，「再刪一次檔案」只記在本次畫面（後端沒有欄位記錄）。
// 上方顯示 App 正在傳的影片檔（VideoUploadManager），點它回進度頁；看過完成畫面後就移除。
// 再下面是還沒傳完的影片（App 被關掉、網頁重新整理前沒傳完，PendingUploads）：手機按「繼續上傳」
// 用原本的檔案接著傳，檔案不見時請管理員重選同一個檔案；網頁一律重選，檔名與大小相符才接著傳
// （後台影片 T-05）。App 啟動時不自動續傳。

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../core/platform/platform_features.dart';
import '../../models/admin_models.dart';
import '../../models/content_category.dart';
import '../../services/admin_service.dart';
import '../../services/category_service.dart';
import '../../services/user_service.dart';
import '../../services/video_upload/pending_uploads.dart';
import '../../services/video_upload/video_file_picker.dart';
import '../../services/video_upload/video_upload_manager.dart';
import '../../shared/utils/utf16_length_limit.dart';
import '../../shared/widgets/confirm_dialog.dart';
import 'admin_error.dart';
import 'admin_video_edit_screen.dart';
import 'admin_video_upload_progress_screen.dart';
import 'admin_video_upload_screen.dart';
import 'widgets/admin_paged_list.dart';
import 'widgets/admin_widgets.dart';

/// 標題搜尋上限，同後端 `q`（UTF-16 單位）。
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

/// 找不到原本的影片檔時的選擇。
enum _MissingFileChoice { repick, discard }

/// 列尾選單的一個項目；[onSelected] 為 null 時顯示但停用（例如請求進行中）。
typedef _RowAction = ({String label, VoidCallback? onSelected});

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

  /// 下架了但檔案沒刪乾淨的影片 id，這些列提供「再刪一次檔案」。重開列表就看不到。
  final Set<int> _filesPending = {};

  /// 下架請求送出中的影片 id：選單項目停用並顯示進行中，避免連點重送。
  final Set<int> _archiving = {};

  /// 正在準備續傳（檢查檔案、重選檔案），避免連點。
  bool _resuming = false;

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
    PendingUploads.instance.load();
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
    // 輸入法組字中 formatter 不截，停止輸入時可能仍超過上限，送出前再截一次。
    final query = truncateUtf16(text.trim(), adminVideoSearchMax);
    if (query == _query) return;
    setState(() => _query = query);
    _list.reset();
  }

  /// 上架成功回來時重抓第一頁（保留目前的篩選）。
  Future<void> _upload() async {
    final created = await pushAdmin<bool>(
      context,
      const AdminVideoUploadScreen(),
    );
    if ((created ?? false) && mounted) await _list.reload();
  }

  void _openProgress() {
    if (mounted) {
      pushAdmin<void>(context, const AdminVideoUploadProgressScreen());
    }
  }

  void _showBusy() => showAdminMessage(
    '已有一支影片正在上傳，請等它傳完再繼續',
    action: (label: '查看進度', onPressed: _openProgress),
  );

  /// 繼續一支沒傳完的：手機用原本的檔案，網頁（或手機檔案不見時）請管理員重選同一個檔案。
  /// 開始後換到進度頁。
  Future<void> _resumePending(PendingUpload upload) async {
    if (_resuming) return;
    if (VideoUploadManager.instance.isBusy) {
      _showBusy();
      return;
    }
    setState(() => _resuming = true);
    try {
      final started = PlatformFeatures.hasFileSystem
          ? await _resumeFromFile(upload)
          : await _resumeWithRepick(upload);
      if (started) _openProgress();
    } on UploadBusy {
      _showBusy();
    } catch (e) {
      debugPrint('AdminVideosScreen: 續傳失敗：$e');
      showAdminMessage('無法繼續上傳，請稍後再試');
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }

  /// 手機：用紀錄的檔案接著傳；檔案不見就問要不要重選。回 true 代表已開始上傳。
  Future<bool> _resumeFromFile(PendingUpload upload) async {
    try {
      await VideoUploadManager.instance.resume(upload);
      return true;
    } on PendingFileMissing {
      if (!mounted) return false;
      final choice = await showDialog<_MissingFileChoice>(
        context: context,
        builder: (context) => AppDialog(
          title: '找不到原本的影片檔',
          message:
              '檔案可能被刪除、搬走或被系統清掉。可以重新選擇同一個檔案'
              '（${upload.fileName}，${formatUploadBytes(upload.size)}）從中斷的地方接著傳；'
              '不想傳了就按「放棄」。\n'
              '放棄後影片會停在「處理中」，超過 6 小時後會在每日維護時標成失敗，'
              '之後可以用「重新上傳」補傳。',
          primaryText: '重新選擇檔案',
          onPrimary: () => Navigator.pop(context, _MissingFileChoice.repick),
          secondary: [
            ('放棄', () => Navigator.pop(context, _MissingFileChoice.discard)),
          ],
        ),
      );
      if (!mounted) return false;
      switch (choice) {
        case _MissingFileChoice.repick:
          return _resumeWithRepick(upload);
        case _MissingFileChoice.discard:
          await PendingUploads.instance.discard(upload);
          return false;
        case null: // 點外面關掉：維持原樣
          return false;
      }
    }
  }

  /// 重選同一個檔案接著傳；檔名或大小不符就提示重選。回 true 代表已開始上傳。
  Future<bool> _resumeWithRepick(PendingUpload upload) async {
    final from = PlatformFeatures.isMobile
        ? await _choosePickSource()
        : VideoPickSource.files;
    if (from == null || !mounted) return false;
    try {
      final picked = await pickAdminVideoFile(from);
      if (picked == null) return false;
      if (!mounted) {
        await picked.source.discard();
        return false;
      }
      await VideoUploadManager.instance.resume(upload, repicked: picked);
      return true;
    } on VideoFileRejected catch (e) {
      showAdminMessage(e.message);
    } on PendingFileMismatch {
      showAdminMessage(
        '選的檔案和原本的不同，請選 ${upload.fileName}'
        '（${formatUploadBytes(upload.size)}）',
      );
    }
    return false;
  }

  /// 手機重選檔案：從相簿或從檔案。
  Future<VideoPickSource?> _choosePickSource() =>
      showModalBottomSheet<VideoPickSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('從相簿'),
                onTap: () => Navigator.pop(context, VideoPickSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('從檔案'),
                onTap: () => Navigator.pop(context, VideoPickSource.files),
              ),
            ],
          ),
        ),
      );

  /// 放棄一支沒傳完的：刪本機紀錄與暫存檔；影片本身留給後端標失敗。
  Future<void> _discardPending(PendingUpload upload) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '放棄這次上傳？',
      message: '影片會停在「處理中」，超過 6 小時後會在每日維護時標成失敗，之後可以用「重新上傳」補傳。',
      confirmText: '放棄',
    );
    if (!confirmed) return;
    await PendingUploads.instance.discard(upload);
  }

  /// 編輯完回來：已更新就地換掉那一列（不再符合篩選也先留著，下拉重整後才消失），
  /// 影片已不存在就重抓第一頁。
  Future<void> _edit(AdminVideo video) async {
    final result = await pushAdmin<AdminVideoEditResult>(
      context,
      AdminVideoEditScreen(video: video),
    );
    if (!mounted) return;
    switch (result) {
      case AdminVideoUpdated(video: final updated):
        _list.replace((v) => v.id == updated.id, updated);
      case AdminVideoGone():
        await _list.reload();
      case null:
        break;
    }
  }

  /// 下架前先確認。YouTube 沒有播放檔，後端只改狀態；
  /// 處理中的影片轉檔可能晚於下架完成，多提醒一句。
  Future<void> _archive(AdminVideo video) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '下架這支影片？',
      message: video.isYouTube
          ? '下架後 App 不再顯示這支影片。'
          : video.status == 'processing'
          ? '下架會刪除播放檔，無法復原。轉檔中的影片之後可能仍有殘留檔案。'
          : '下架會刪除播放檔，無法復原。',
      confirmText: '下架',
    );
    if (confirmed && mounted) await _sendArchive(video);
  }

  /// 送出下架，成功後就地改成已下架（不再符合篩選也先留著，下拉重整後才消失）。
  /// 已下架的影片再送一次，後端只重試刪檔（「再刪一次檔案」走這裡，不再確認）。
  Future<void> _sendArchive(AdminVideo video) async {
    if (_archiving.contains(video.id)) return;
    setState(() => _archiving.add(video.id));
    try {
      final filesDeleted = await AdminService.archiveVideo(video.id);
      if (!mounted) return;
      setState(() {
        if (filesDeleted) {
          _filesPending.remove(video.id);
        } else {
          _filesPending.add(video.id);
        }
      });
      // 以列表裡現在那筆為底：請求期間可能已下拉重整或編輯過，送出前的快照已過時；
      // 換了篩選而那筆已不在列表上就不動。
      final current = _list.items.where((v) => v.id == video.id).firstOrNull;
      if (current != null) {
        _list.replace((v) => v.id == video.id, current.withStatus('archived'));
      }
      showAdminMessage(filesDeleted ? '已下架' : '已下架，但檔案沒刪乾淨，請再按一次');
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.code == 'VIDEO_NOT_FOUND') {
        showAdminMessage('這支影片已不存在');
        await _list.reload();
        return;
      }
      handleAdminError(context, e);
    } finally {
      if (mounted) setState(() => _archiving.remove(video.id));
    }
  }

  /// 每一列的選單項目；沒有項目時不顯示選單鈕。編輯不分狀態都能用（後端不限制）。
  /// 處理中的影片也能下架（後端不限制）。
  List<_RowAction> _rowActions(AdminVideo video) {
    final busy = _archiving.contains(video.id);
    return [
      (label: '編輯', onSelected: () => _edit(video)),
      if (!video.isArchived)
        busy
            ? (label: '下架中…', onSelected: null)
            : (label: '下架', onSelected: () => _archive(video)),
      if (video.isArchived && _filesPending.contains(video.id))
        busy
            ? (label: '刪除檔案中…', onSelected: null)
            : (label: '再刪一次檔案', onSelected: () => _sendArchive(video)),
    ];
  }

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: '影片管理',
    actions: [
      IconButton(
        tooltip: '上傳影片',
        onPressed: _upload,
        icon: const Icon(Icons.add, color: AppColors.primary),
      ),
    ],
    body: (context, senior) => Column(
      children: [
        _ActiveUploadBanner(seniorMode: senior, onTap: _openProgress),
        _PendingUploadsBanner(
          seniorMode: senior,
          onResume: _resumePending,
          onDiscard: _discardPending,
        ),
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
      // 後端以 UTF-16 單位計 80 字，maxLength 數字形叢集，emoji 會被放行後回 400。
      inputFormatters: const [
        Utf16LengthLimitingTextInputFormatter(adminVideoSearchMax),
      ],
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

/// 進行中的上傳（傳送中、中斷、剛傳完）；沒有時不佔空間。
class _ActiveUploadBanner extends StatelessWidget {
  final bool seniorMode;
  final VoidCallback onTap;

  const _ActiveUploadBanner({required this.seniorMode, required this.onTap});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ActiveUpload?>(
    valueListenable: VideoUploadManager.instance.active,
    builder: (context, upload, _) {
      if (upload == null) return const SizedBox.shrink();
      final progress = upload.progress;
      final (label, color) = switch (upload.state) {
        UploadState.uploading when progress.retrying => (
          '網路中斷，自動重試中',
          AppColors.dangerDark,
        ),
        UploadState.uploading => ('上傳中', AppColors.goldDeep),
        UploadState.interrupted => ('上傳中斷，點這裡重試或放棄', AppColors.dangerDark),
        UploadState.done => ('上傳完成，轉檔後會自動上架', AppColors.moss),
      };
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          0,
        ),
        child: AdminCard(
          key: const ValueKey('admin-active-upload'),
          seniorMode: seniorMode,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_upload_outlined, color: color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      upload.video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyLargeStyle(
                        seniorMode: seniorMode,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.inkSoft),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 6,
                color: color,
                backgroundColor: AppColors.creamDeep,
              ),
              const SizedBox(height: 4),
              Text(
                '$label・${formatUploadBytes(progress.sent)}／'
                '${formatUploadBytes(progress.total)}',
                style: AppTypography.captionStyle(
                  seniorMode: seniorMode,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 還沒傳完的影片（App 被關掉、網頁重新整理前沒傳完的）；正在傳的那支不重複列。沒有時不佔空間。
class _PendingUploadsBanner extends StatelessWidget {
  final bool seniorMode;
  final void Function(PendingUpload upload) onResume;
  final void Function(PendingUpload upload) onDiscard;

  const _PendingUploadsBanner({
    required this.seniorMode,
    required this.onResume,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      PendingUploads.instance.items,
      VideoUploadManager.instance.active,
    ]),
    builder: (context, _) {
      final activeId = VideoUploadManager.instance.active.value?.video.id;
      final uploads = PendingUploads.instance
          .visibleTo(UserService.currentUid)
          .where((p) => p.videoId != activeId)
          .toList();
      if (uploads.isEmpty) return const SizedBox.shrink();
      final now = DateTime.now();
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          0,
        ),
        child: AdminCard(
          key: const ValueKey('admin-pending-uploads'),
          seniorMode: seniorMode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppColors.goldDeep,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '有 ${uploads.length} 支影片還沒傳完',
                      style: AppTypography.bodyLargeStyle(
                        seniorMode: seniorMode,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              for (final upload in uploads)
                _PendingUploadRow(
                  upload: upload,
                  expired: upload.isExpiredAt(now),
                  seniorMode: seniorMode,
                  onResume: () => onResume(upload),
                  onDiscard: () => onDiscard(upload),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _PendingUploadRow extends StatelessWidget {
  final PendingUpload upload;
  final bool expired;
  final bool seniorMode;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  const _PendingUploadRow({
    required this.upload,
    required this.expired,
    required this.seniorMode,
    required this.onResume,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final hint = expired
        ? '上傳連結已超過一週失效，請放棄，再用「重新上傳」補傳。'
        : PlatformFeatures.hasFileSystem
        ? '${upload.fileName}・${formatUploadBytes(upload.size)}'
        : '請重新選擇同一個檔案（${upload.fileName}，${formatUploadBytes(upload.size)}），會從中斷的地方接著傳。';
    return Padding(
      key: ValueKey('admin-pending-upload-${upload.videoId}'),
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            upload.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyStyle(
              seniorMode: seniorMode,
              color: AppColors.ink,
            ),
          ),
          Text(
            hint,
            style: AppTypography.captionStyle(
              seniorMode: seniorMode,
              color: expired ? AppColors.dangerDark : AppColors.inkSoft,
            ),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            children: [
              TextButton(onPressed: onDiscard, child: const Text('放棄')),
              if (!expired)
                FilledButton(
                  onPressed: onResume,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.creamLight,
                  ),
                  child: Text(
                    PlatformFeatures.hasFileSystem ? '繼續上傳' : '選擇檔案繼續上傳',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
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
              onSelected: (i) => actions[i].onSelected?.call(),
              itemBuilder: (context) => [
                for (var i = 0; i < actions.length; i++)
                  PopupMenuItem(
                    value: i,
                    enabled: actions[i].onSelected != null,
                    child: Text(actions[i].label),
                  ),
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
