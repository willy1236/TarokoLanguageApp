// 影片上傳進度頁：只訂閱 VideoUploadManager 的狀態，不持有上傳器；離開這頁上傳照樣進行。
// 上傳頁送出後、影片管理列表上方的進度列、重新上傳（後台影片 T-09）都開這頁。
//
// 傳送中：進度條、已傳／總大小、剩餘大小；不提供取消（後台影片 T-04 決定）。
// 網路中斷時上傳器自動重試，這段期間顯示「網路中斷，自動重試中」（後台影片 T-05）。
// 手機能在背景傳時（iOS、Android 14 以上）提示可以切到別的 App；iOS 從斷點續傳前複製剩下的部分時
// 顯示「準備續傳中…」，空間不足時提示需要多少空間（後台影片 T-06）。
// 中斷：「重試」（查雲端已收到多少後接著傳）與「放棄」。工作階段失效時只能放棄。
// 完成：提示轉檔後會自動上架；離開這頁就把完成的上傳從列表上方移除。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/platform/platform_features.dart';
import '../../services/video_upload/background_upload.dart';
import '../../services/video_upload/video_upload_manager.dart';
import '../../shared/widgets/confirm_dialog.dart';
import 'widgets/admin_widgets.dart';

/// 位元組顯示成 MB／GB（一位小數）。
String formatUploadBytes(int bytes) {
  const mb = 1024 * 1024;
  const gb = 1024 * mb;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
  return '${(bytes / mb).toStringAsFixed(1)} MB';
}

/// 位元組顯示成 GB（一位小數，至少 0.1 GB）。
String formatUploadGigabytes(int bytes) {
  const gb = 1024 * 1024 * 1024;
  final value = bytes / gb;
  return '${(value < 0.1 ? 0.1 : value).toStringAsFixed(1)} GB';
}

class AdminVideoUploadProgressScreen extends StatefulWidget {
  const AdminVideoUploadProgressScreen({super.key});

  @override
  State<AdminVideoUploadProgressScreen> createState() =>
      _AdminVideoUploadProgressScreenState();
}

class _AdminVideoUploadProgressScreenState
    extends State<AdminVideoUploadProgressScreen> {
  final _manager = VideoUploadManager.instance;

  /// 這台裝置的上傳能在背景繼續（提示文字用）。
  bool _background = false;

  @override
  void initState() {
    super.initState();
    backgroundUploadSupported().then((supported) {
      if (mounted && supported) setState(() => _background = true);
    });
  }

  Future<void> _abandon() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '放棄這次上傳？',
      message: '影片會停在「處理中」，超過 6 小時後會在每日維護時標成失敗，之後可以用「重新上傳」補傳。',
      confirmText: '放棄',
    );
    if (!confirmed || !mounted) return;
    await _manager.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // 離開時看過完成畫面了，列表上方不必再顯示。（不放 dispose：那時通知列表會在鎖定的 widget 樹上重建）
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _manager.dismiss();
    },
    child: ValueListenableBuilder<ActiveUpload?>(
      valueListenable: _manager.active,
      builder: (context, upload, _) => AdminScaffold(
        title: '上傳影片',
        body: (context, senior) => upload == null
            ? Center(
                child: Text(
                  '目前沒有上傳中的影片',
                  style: AppTypography.bodyStyle(
                    seniorMode: senior,
                    color: AppColors.inkSoft,
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _UploadStatusCard(
                  upload: upload,
                  background: _background,
                  seniorMode: senior,
                ),
              ),
        bottom: (context, senior) => switch (upload?.state) {
          UploadState.interrupted => AdminActionBar(
            children: [
              OutlinedButton(onPressed: _abandon, child: const Text('放棄')),
              FilledButton(
                onPressed: upload!.sessionExpired ? null : _manager.retry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.creamLight,
                ),
                child: const Text('重試'),
              ),
            ],
          ),
          UploadState.done => AdminActionBar(
            children: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.creamLight,
                ),
                child: const Text('回影片管理'),
              ),
            ],
          ),
          _ => const SizedBox.shrink(),
        },
      ),
    ),
  );
}

class _UploadStatusCard extends StatelessWidget {
  final ActiveUpload upload;

  /// 上傳能在背景繼續。
  final bool background;
  final bool seniorMode;

  const _UploadStatusCard({
    required this.upload,
    required this.background,
    required this.seniorMode,
  });

  @override
  Widget build(BuildContext context) {
    final progress = upload.progress;
    final (statusText, statusColor) = switch (upload.state) {
      UploadState.uploading when progress.retrying => (
        '網路中斷，自動重試中',
        AppColors.dangerDark,
      ),
      UploadState.uploading when progress.preparing => (
        '準備續傳中…',
        AppColors.goldDeep,
      ),
      UploadState.uploading => ('上傳中', AppColors.goldDeep),
      UploadState.interrupted when upload.storageNeeded != null => (
        '手機空間不足',
        AppColors.dangerDark,
      ),
      UploadState.interrupted => ('上傳中斷', AppColors.dangerDark),
      UploadState.done => ('上傳完成', AppColors.moss),
    };
    return AdminCard(
      seniorMode: seniorMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            upload.video.title,
            style: AppTypography.bodyLargeStyle(
              seniorMode: seniorMode,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            statusText,
            key: const ValueKey('admin-upload-status'),
            style: AppTypography.bodyStyle(
              seniorMode: seniorMode,
              color: statusColor,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            key: const ValueKey('admin-upload-progress'),
            value: progress.fraction,
            minHeight: 8,
            color: statusColor,
            backgroundColor: AppColors.creamDeep,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '已傳 ${formatUploadBytes(progress.sent)}／${formatUploadBytes(progress.total)}'
            '（${(progress.fraction * 100).floor()}%）',
            style: AppTypography.bodyStyle(
              seniorMode: seniorMode,
              color: AppColors.ink,
            ),
          ),
          if (upload.state != UploadState.done)
            Text(
              '剩餘 ${formatUploadBytes(progress.remaining)}',
              style: AppTypography.captionStyle(
                seniorMode: seniorMode,
                color: AppColors.inkSoft,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _hint(upload, background: background),
            style: AppTypography.bodyStyle(
              seniorMode: seniorMode,
              color: upload.state == UploadState.interrupted
                  ? AppColors.dangerDark
                  : AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  static String _hint(ActiveUpload upload, {required bool background}) =>
      switch (upload.state) {
        UploadState.uploading when upload.progress.retrying =>
          '網路恢復後會從中斷的地方接著傳；約 10 分鐘內沒有恢復，會停下來讓你按「重試」。',
        UploadState.uploading when upload.progress.preparing =>
          '正在準備從中斷的地方接著傳，檔案較大時需要一點時間，請保持 App 開啟。',
        UploadState.uploading when background =>
          '可以離開這頁，也可以切到別的 App 或鎖螢幕，上傳會在背景繼續；影片管理列表上方會顯示進度。',
        UploadState.uploading =>
          PlatformFeatures.isMobile
              ? '可以離開這頁，影片管理列表上方會顯示進度。上傳完成前請讓 App 保持開啟。'
              : '可以離開這頁，影片管理列表上方會顯示進度。上傳完成前請不要關閉或重新整理這個分頁。',
        UploadState.interrupted when upload.storageNeeded != null =>
          '手機空間不足，需要約 ${formatUploadGigabytes(upload.storageNeeded!)} 才能續傳。'
              '清出空間後按「重試」。',
        UploadState.interrupted =>
          upload.sessionExpired
              ? '上傳連結已失效，請放棄這次上傳，再用「重新上傳」補傳。'
              : '網路中斷或雲端暫時沒有回應，請確認網路後按「重試」，會從中斷的地方接著傳。',
        UploadState.done => '上傳完成，轉檔需要幾分鐘，完成後會自動上架。',
      };
}
