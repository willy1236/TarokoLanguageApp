// 上傳影片：上方切換來源（貼上 YouTube 網址｜選擇影片檔），下方填標題、說明、分類、部落。
// 規格：Truku_backend 說明文件/API/內部管理.md §6.2。
//
// YouTube：網址停止輸入約 500ms（貼上時立刻）先預覽，預覽成功才能上架；
// 已上架過的不能再上架；不允許嵌入的影片標題必填（後端拿不到標題）。
// 選擇影片檔由後台影片 T-04 接上，目前只顯示「即將開放」。

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/admin_models.dart';
import '../../models/content_category.dart';
import '../../services/admin_service.dart';
import '../../services/category_service.dart';
import 'admin_error.dart';
import 'widgets/admin_video_meta_fields.dart';
import 'widgets/admin_widgets.dart';

/// 停止輸入多久後預覽。
const _previewDebounce = Duration(milliseconds: 500);

/// 影片來源。
enum AdminVideoUploadSource { youtube, file }

/// 送出成功時 pop(true)，列表據此重抓。
class AdminVideoUploadScreen extends StatefulWidget {
  const AdminVideoUploadScreen({super.key});

  @override
  State<AdminVideoUploadScreen> createState() => _AdminVideoUploadScreenState();
}

class _AdminVideoUploadScreenState extends State<AdminVideoUploadScreen> {
  AdminVideoUploadSource _source = AdminVideoUploadSource.youtube;
  final _meta = AdminVideoMetaController();
  final _url = TextEditingController();
  late final _previewer = _YouTubePreviewer(
    onError: (e) => mounted && handleAdminError(context, e, toast: false),
  )..addListener(_onPreviewChanged);
  bool _busy = false;

  @override
  void dispose() {
    _previewer.dispose();
    _url.dispose();
    _meta.dispose();
    super.dispose();
  }

  /// 預覽換了：帶入（或清掉先前帶入的）YouTube 標題；使用者自己改過的標題不動。
  void _onPreviewChanged() {
    if (!_previewer.loading) _meta.suggestTitle(_previewer.preview?.title);
    setState(() {});
  }

  /// 可嵌入且 YouTube 有給標題時，標題可留空由後端帶入。
  bool get _titleRequired {
    final preview = _previewer.preview;
    return _source != AdminVideoUploadSource.youtube ||
        preview == null ||
        !preview.embeddable ||
        preview.title == null;
  }

  Future<void> _submitYouTube() async {
    final url = _previewer.previewedUrl;
    if (!_previewer.canSubmit || url == null) return;
    if (!_meta.validate()) return;
    final meta = _meta.value;
    final isNewCategory = _meta.isNewCategory;
    setState(() => _busy = true);
    try {
      await AdminService.createYouTubeVideo(url, meta);
      if (isNewCategory) _refreshVideoCategories();
      showAdminMessage('已上架');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      handleAdminError(context, e);
    }
  }

  /// 後端已把新分類加進影音分類表：刷新快取，列表與影音頁才拿得到名稱。失敗不影響上架結果。
  void _refreshVideoCategories() {
    CategoryService.fetch(CategoryModule.videos, refresh: true).then<void>(
      (_) {},
      onError: (Object e) =>
          debugPrint('AdminVideoUploadScreen: 影音分類快取刷新失敗：$e'),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AdminScaffold(
      title: '上傳影片',
      body: (context, senior) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<AdminVideoUploadSource>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: AdminVideoUploadSource.youtube,
                  label: Text('貼上 YouTube 網址'),
                ),
                ButtonSegment(
                  value: AdminVideoUploadSource.file,
                  label: Text('選擇影片檔'),
                ),
              ],
              selected: {_source},
              onSelectionChanged: _busy
                  ? null
                  : (s) => setState(() => _source = s.first),
            ),
            const SizedBox(height: AppSpacing.md),
            ...switch (_source) {
              AdminVideoUploadSource.youtube => [
                _urlField(senior),
                _previewSection(senior),
                const SizedBox(height: AppSpacing.md),
                AdminVideoMetaFields(
                  controller: _meta,
                  titleRequired: _titleRequired,
                  seniorMode: senior,
                ),
              ],
              AdminVideoUploadSource.file => [_fileComingSoon(senior)],
            },
          ],
        ),
      ),
      bottom: (context, senior) => _source == AdminVideoUploadSource.youtube
          ? AdminActionBar(
              children: [
                FilledButton(
                  onPressed: _busy || !_previewer.canSubmit
                      ? null
                      : _submitYouTube,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.creamLight,
                  ),
                  child: Text(_busy ? '上架中…' : '上架'),
                ),
              ],
            )
          : const SizedBox.shrink(),
    ),
  );

  Widget _urlField(bool senior) => TextField(
    controller: _url,
    enabled: !_busy,
    keyboardType: TextInputType.url,
    textInputAction: TextInputAction.done,
    autocorrect: false,
    onChanged: _previewer.onTextChanged,
    onSubmitted: _previewer.previewNow,
    style: AppTypography.bodyLargeStyle(
      seniorMode: senior,
      color: AppColors.ink,
    ),
    decoration: const InputDecoration(
      labelText: 'YouTube 網址',
      hintText: 'https://www.youtube.com/watch?v=…',
      prefixIcon: Icon(Icons.link),
      border: OutlineInputBorder(),
    ),
  );

  Widget _previewSection(bool senior) {
    final p = _previewer;
    final preview = p.preview;
    final error = p.error;
    if (p.loading) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                error,
                key: const ValueKey('admin-video-preview-error'),
                style: AppTypography.bodyStyle(
                  seniorMode: senior,
                  color: AppColors.dangerDark,
                ),
              ),
            ),
            if (p.retryable)
              TextButton(onPressed: p.retry, child: const Text('重試')),
          ],
        ),
      );
    }
    if (preview == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AdminCard(
        seniorMode: senior,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  preview.thumbnailUrl,
                  key: const ValueKey('admin-video-preview-thumbnail'),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.creamDeep,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.movie_outlined,
                      color: AppColors.fog,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              preview.title ?? '（YouTube 沒有提供標題）',
              style: AppTypography.bodyLargeStyle(
                seniorMode: senior,
                color: AppColors.ink,
              ),
            ),
            if (preview.alreadyExists)
              _notice('這支影片已經上架過', AppColors.dangerDark, senior),
            if (!preview.alreadyExists && !preview.embeddable)
              _notice(
                '這支影片不允許在 App 裡播放，會改成開 YouTube',
                AppColors.goldDeep,
                senior,
              ),
          ],
        ),
      ),
    );
  }

  Widget _notice(String text, Color color, bool senior) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Text(
      text,
      style: AppTypography.bodyStyle(seniorMode: senior, color: color),
    ),
  );

  // 後台影片 T-04 換成選檔流程。
  Widget _fileComingSoon(bool senior) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Column(
      children: [
        const Icon(Icons.video_file_outlined, size: 48, color: AppColors.fog),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '選擇影片檔即將開放，目前請先用 YouTube 網址上架。',
          textAlign: TextAlign.center,
          style: AppTypography.bodyStyle(
            seniorMode: senior,
            color: AppColors.inkSoft,
          ),
        ),
      ],
    ),
  );
}

/// YouTube 網址預覽：停止輸入後送出、貼上立刻送出、晚回來的舊結果丟掉、錯誤轉成提示。
class _YouTubePreviewer extends ChangeNotifier {
  /// 錯誤先交給它；回 true 代表已處理（非管理員已退出後台），不再顯示錯誤。
  final bool Function(Object error) onError;

  _YouTubePreviewer({required this.onError});

  Timer? _debounce;
  int _generation = 0;
  bool _disposed = false;
  String _lastText = '';

  /// 目前要預覽（或已預覽）的網址，前後空白已去掉。
  String _url = '';
  bool _loading = false;
  AdminYouTubePreview? _preview;
  String? _error;
  bool _retryable = false;

  bool get loading => _loading;
  AdminYouTubePreview? get preview => _preview;
  String? get error => _error;

  /// 錯誤是暫時性的（YouTube 暫時查不到、網路、太頻繁），可以原網址重試。
  bool get retryable => _retryable;

  /// [preview] 對應的網址；沒有預覽結果時是 null。
  String? get previewedUrl => _preview == null ? null : _url;

  /// 預覽成功且還沒上架過。
  bool get canSubmit =>
      !_loading && _preview != null && !_preview!.alreadyExists;

  /// 輸入框內容變了：一次放進兩個字以上（含選取後貼上取代）視為貼上，立刻預覽；
  /// 否則等停止輸入。
  void onTextChanged(String text) {
    final pasted = _insertedLength(_lastText, text) > 1;
    _lastText = text;
    final url = text.trim();
    if (url == _url) return;
    _debounce?.cancel();
    _generation++;
    _url = url;
    _preview = null;
    _error = null;
    _retryable = false;
    _loading = false;
    if (url.isEmpty) {
      _notify();
    } else if (pasted) {
      _run();
    } else {
      // 等待期間就清掉舊預覽，避免拿舊影片的結果上架新網址。
      _notify();
      _debounce = Timer(_previewDebounce, _run);
    }
  }

  /// [after] 比 [before] 多放進幾個字：去掉前後相同的部分後，[after] 剩下的長度。
  static int _insertedLength(String before, String after) {
    var prefix = 0;
    while (prefix < before.length &&
        prefix < after.length &&
        before[prefix] == after[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < before.length - prefix &&
        suffix < after.length - prefix &&
        before[before.length - 1 - suffix] ==
            after[after.length - 1 - suffix]) {
      suffix++;
    }
    return after.length - prefix - suffix;
  }

  /// 按下鍵盤的完成鍵：不等計時器。
  void previewNow(String text) {
    onTextChanged(text);
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _run();
    }
  }

  void retry() {
    if (_url.isNotEmpty) _run();
  }

  Future<void> _run() async {
    final generation = ++_generation;
    final url = _url;
    _loading = true;
    _preview = null;
    _error = null;
    _retryable = false;
    _notify();
    try {
      final preview = await AdminService.previewYouTube(url);
      if (_disposed || generation != _generation) return;
      _preview = preview;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      if (onError(e)) return;
      _error = _messageOf(e);
      _retryable = _isRetryable(e);
    }
    _loading = false;
    _notify();
  }

  static String _messageOf(Object e) {
    if (e is ApiException && e.code == 'INVALID_YOUTUBE_URL') {
      return '只接受 YouTube 網址；影片檔請用「選擇影片檔」上傳';
    }
    // YOUTUBE_UNAVAILABLE／YOUTUBE_NOT_FOUND／YOUTUBE_CHECK_FAILED 的後端訊息已是給管理員看的說明。
    return apiErrorMessage(e, fallback: '無法預覽這個網址，請檢查網路後重試');
  }

  static bool _isRetryable(Object e) =>
      e is! ApiException ||
      e.code == 'YOUTUBE_CHECK_FAILED' ||
      e.isRateLimited ||
      e.isServiceBusy;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
