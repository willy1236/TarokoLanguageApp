// 上傳影片：上方切換來源（貼上 YouTube 網址｜選擇影片檔），下方填標題、說明、分類、部落。
// 規格：Truku_backend 說明文件/API/內部管理.md §6.2。
//
// YouTube：網址停止輸入約 500ms（貼上時立刻）先預覽，預覽成功才能上架；
// 已上架過的不能再上架；不允許嵌入的影片標題必填（後端拿不到標題）。
//
// 影片檔（後台影片 T-04）：手機「從相簿」「從檔案」，網頁只有「選擇影片檔」；選完檢查
// mp4／mov 與 2GB，標題必填。送出後建立影片，交給 App 層級的 VideoUploadManager 分段上傳，
// 這頁換成進度頁（列表同時重抓，看得到這支「處理中」）。一次只傳一支，未傳完時再選檔會提示。
// 手機選完檔常駐「建議使用 Wi-Fi」提醒。選了但沒送出就離開，刪掉手機上的暫存複本。
// 選檔區塊與「一次一支」檢查和重新上傳頁共用（widgets/admin_video_file_field.dart）。

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
import '../../services/video_upload/video_upload_manager.dart';
import 'admin_error.dart';
import 'admin_video_upload_progress_screen.dart';
import 'widgets/admin_video_file_field.dart';
import 'widgets/admin_video_meta_fields.dart';
import 'widgets/admin_widgets.dart';

/// 停止輸入多久後預覽。
const _previewDebounce = Duration(milliseconds: 500);

/// 影片來源。
enum AdminVideoUploadSource { youtube, file }

/// 送出成功時以 true 結束這頁（YouTube 直接回列表；影片檔換成進度頁），列表據此重抓。
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

  /// 選好、還沒送出的影片檔；選了但沒送出就離開時由它刪掉暫存複本。
  final _file = AdminVideoFileController();

  @override
  void initState() {
    super.initState();
    _file.addListener(_onFileChanged);
  }

  void _onFileChanged() => setState(() {});

  @override
  void dispose() {
    _file.dispose();
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
      // 預覽之後才被別人上架：標成已上架，上架鍵停用、顯示提示。
      if (e is ApiException && e.code == 'VIDEO_EXISTS') {
        _previewer.markExists(_int(e.errorField('video_id')));
      }
      handleAdminError(context, e);
    }
  }

  Future<void> _submitFile() async {
    final picked = _file.picked;
    if (picked == null || _busy) return;
    if (!_meta.validate()) return;
    if (blockedByActiveUpload(context)) return;
    final meta = _meta.value;
    final isNewCategory = _meta.isNewCategory;
    setState(() => _busy = true);
    try {
      final created = await AdminService.createUploadVideo(picked.info, meta);
      VideoUploadManager.instance.start(
        created.video,
        created.session,
        picked.source,
        fileName: picked.info.name,
      );
      // 交給上傳服務了，離開這頁時不能刪。
      _file.handOver();
      if (isNewCategory) _refreshVideoCategories();
      if (mounted) {
        await replaceWithAdmin<void, bool>(
          context,
          const AdminVideoUploadProgressScreen(),
          result: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e is UploadBusy) {
        blockedByActiveUpload(context);
        return;
      }
      final message = uploadSessionErrorMessage(e);
      if (message != null) {
        showAdminMessage(message);
      } else {
        handleAdminError(context, e);
      }
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
              AdminVideoUploadSource.file => [
                AdminVideoFileField(
                  controller: _file,
                  enabled: !_busy,
                  seniorMode: senior,
                ),
                const SizedBox(height: AppSpacing.md),
                AdminVideoMetaFields(
                  controller: _meta,
                  titleRequired: true,
                  seniorMode: senior,
                ),
              ],
            },
          ],
        ),
      ),
      bottom: (context, senior) => AdminActionBar(
        children: [
          switch (_source) {
            AdminVideoUploadSource.youtube => FilledButton(
              onPressed: _busy || !_previewer.canSubmit ? null : _submitYouTube,
              style: _submitStyle,
              child: Text(_busy ? '上架中…' : '上架'),
            ),
            AdminVideoUploadSource.file => FilledButton(
              onPressed: _busy || _file.preparing || _file.picked == null
                  ? null
                  : _submitFile,
              style: _submitStyle,
              child: Text(_busy ? '建立中…' : '上傳'),
            ),
          },
        ],
      ),
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

  static final _submitStyle = FilledButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.creamLight,
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

  /// 輸入框內容變了：一次放進的內容看起來像網址（含 `http` 或 `youtu`，含選取後貼上取代）
  /// 視為貼上，立刻預覽；否則等停止輸入。手機鍵盤整詞輸入、選字也會一次放進多個字，
  /// 只看字數會在網址打到一半時就送預覽。
  void onTextChanged(String text) {
    final pasted = _looksLikeUrl(_inserted(_lastText, text));
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

  static bool _looksLikeUrl(String inserted) {
    final lower = inserted.toLowerCase();
    return lower.contains('http') || lower.contains('youtu');
  }

  /// [after] 比 [before] 多放進的內容：去掉前後相同的部分後，[after] 剩下的那段。
  static String _inserted(String before, String after) {
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
    return after.substring(prefix, after.length - suffix);
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

  /// 上架時後端回已上架（409 VIDEO_EXISTS）：把目前的預覽標成已上架。
  /// [videoId] 是既有影片的 id，後端沒給時仍視為已上架。
  void markExists(int? videoId) {
    final p = _preview;
    if (p == null || p.alreadyExists) return;
    _preview = AdminYouTubePreview(
      youtubeVideoId: p.youtubeVideoId,
      title: p.title,
      thumbnailUrl: p.thumbnailUrl,
      embeddable: p.embeddable,
      existsVideoId: videoId ?? 0,
    );
    _notify();
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

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
