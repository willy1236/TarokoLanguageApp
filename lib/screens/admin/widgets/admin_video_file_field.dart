// 後台選影片檔區塊（上傳、重新上傳共用）：手機「從相簿」「從檔案」，網頁與桌面只有「選擇影片檔」；
// 選檔時顯示「準備檔案中」（Android 大檔要等系統複製），選好顯示檔名、大小，手機加上 Wi-Fi 提醒；
// 格式或大小不符顯示原因。
//
// 選檔狀態放在 [AdminVideoFileController]：選好、還沒交給上傳服務的檔案在換檔或 dispose 時
// 刪掉手機上的暫存複本；交給上傳服務時用 [AdminVideoFileController.handOver] 取走，之後不再刪。
// 一次只傳一支：選檔時由 [AdminVideoFileField] 用 [blockedByActiveUpload] 檢查（呼叫端不必自己擋），
// 送出前由畫面再檢查一次。

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/platform/platform_features.dart';
import '../../../services/video_upload/video_file_picker.dart';
import '../../../services/video_upload/video_upload_manager.dart';
import '../admin_error.dart';
import '../admin_video_upload_progress_screen.dart';
import 'admin_widgets.dart';

/// 一次只傳一支：還有一支沒傳完（傳送中或中斷待處理）時提示，回 true 代表擋下。
/// 提示附「查看進度」開進度頁。
bool blockedByActiveUpload(BuildContext context) {
  if (!VideoUploadManager.instance.isBusy) return false;
  showAdminMessage(
    '已有一支影片正在上傳，請等它傳完再上傳下一支',
    action: (
      label: '查看進度',
      onPressed: () {
        if (context.mounted) {
          pushAdmin<void>(context, const AdminVideoUploadProgressScreen());
        }
      },
    ),
  );
  return true;
}

/// 建立上傳（上傳、重新上傳）的錯誤提示；其他錯誤回 null，交給 [handleAdminError]。
String? uploadSessionErrorMessage(Object e) {
  if (e is! ApiException) return null;
  return switch (e.code) {
    'UPLOAD_SESSION_FAILED' => '暫時無法建立上傳，請稍後再試',
    'UNSUPPORTED_VIDEO_TYPE' => '只能上傳 mp4、mov 影片檔',
    'VIDEO_TOO_LARGE' => '影片檔最大 2GB，請壓縮或剪短後再上傳',
    _ => null,
  };
}

/// 選檔狀態：選好的檔案、準備中、選檔錯誤。
class AdminVideoFileController extends ChangeNotifier {
  PickedVideoFile? _picked;
  bool _preparing = false;
  String? _error;
  bool _disposed = false;

  /// 選好、還沒交給上傳服務的影片檔。
  PickedVideoFile? get picked => _picked;

  /// 選好後系統還在複製檔案（Android 大檔要等）。
  bool get preparing => _preparing;

  /// 選檔失敗（格式、大小不符或讀不到）給管理員看的原因。
  String? get error => _error;

  /// 從 [from] 選一支影片檔；選好就取代先前選的（舊的暫存複本刪掉），取消維持原樣。
  /// 準備中再呼叫不做事。
  Future<void> pick(VideoPickSource from) async {
    if (_preparing) return;
    _error = null;
    _notify();
    try {
      final picked = await pickAdminVideoFile(
        from,
        onPreparing: () {
          _preparing = true;
          _notify();
        },
      );
      if (_disposed) {
        await picked?.source.discard();
        return;
      }
      if (picked == null) return;
      await _picked?.source.discard();
      _picked = picked;
    } on VideoFileRejected catch (e) {
      _error = e.message;
    } catch (e) {
      debugPrint('AdminVideoFileController: 選檔失敗：$e');
      _error = '無法讀取這個檔案，請重新選擇';
    } finally {
      _preparing = false;
      _notify();
    }
  }

  /// 交給上傳服務：取走選好的檔案，之後換檔或 dispose 都不再刪它。
  PickedVideoFile? handOver() {
    final picked = _picked;
    _picked = null;
    return picked;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // 選了但沒送出：手機上的暫存複本用不到了。
    _picked?.source.discard();
    super.dispose();
  }
}

/// 選檔按鈕、準備中、選好的檔案與 Wi-Fi 提醒、選檔錯誤。
/// [enabled] 為 false（畫面送出中）、準備中時按鈕停用；已有一支在上傳時按了只提示、不開挑選器。
class AdminVideoFileField extends StatelessWidget {
  final AdminVideoFileController controller;
  final bool enabled;
  final bool seniorMode;

  const AdminVideoFileField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.seniorMode,
  });

  void _pick(BuildContext context, VideoPickSource from) {
    if (!enabled || controller.preparing) return;
    if (blockedByActiveUpload(context)) return;
    controller.pick(from);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final senior = seniorMode;
    final picked = controller.picked;
    final preparing = controller.preparing;
    final canPick = enabled && !preparing;
    final error = controller.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (PlatformFeatures.isMobile) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canPick
                      ? () => _pick(context, VideoPickSource.gallery)
                      : null,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('從相簿'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canPick
                      ? () => _pick(context, VideoPickSource.files)
                      : null,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('從檔案'),
                ),
              ),
            ] else
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canPick
                      ? () => _pick(context, VideoPickSource.files)
                      : null,
                  icon: const Icon(Icons.video_file_outlined),
                  label: const Text('選擇影片檔'),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '只能上傳 mp4、mov，最大 2GB',
          style: AppTypography.captionStyle(
            seniorMode: senior,
            color: AppColors.inkSoft,
          ),
        ),
        if (preparing)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '準備檔案中…大檔案需要一點時間',
                    style: AppTypography.bodyStyle(
                      seniorMode: senior,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              error,
              key: const ValueKey('admin-video-file-error'),
              style: AppTypography.bodyStyle(
                seniorMode: senior,
                color: AppColors.dangerDark,
              ),
            ),
          ),
        if (picked != null && !preparing)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: AdminCard(
              seniorMode: senior,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.movie_outlined,
                        color: AppColors.inkSoft,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          picked.info.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLargeStyle(
                            seniorMode: senior,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    formatUploadBytes(picked.info.size),
                    style: AppTypography.bodyStyle(
                      seniorMode: senior,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  if (PlatformFeatures.isMobile)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.wifi,
                            size: 18,
                            color: AppColors.goldDeep,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              '影片較大，建議使用 Wi-Fi',
                              style: AppTypography.bodyStyle(
                                seniorMode: senior,
                                color: AppColors.goldDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
