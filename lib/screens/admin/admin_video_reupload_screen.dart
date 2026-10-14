// 重新上傳：轉檔失敗（或上傳沒完成被標成失敗）的自家影片重選檔案上傳（後台影片 T-09）。
// 規格：Truku_backend 說明文件/API/內部管理.md §6.2 POST /api/admin/videos/:id/retry。
//
// 上方是這支影片的標題與失敗原因，下方是跟上傳頁共用的選檔區塊（手機從相簿／從檔案、
// 準備檔案中、Wi-Fi 提醒）。標題、分類等不能在這裡改，要改用「編輯」。
// 送出後影片改回「處理中」，交給 App 層級的 VideoUploadManager 上傳（未完成清單由它寫入），
// 這頁換成進度頁。一次只傳一支，選檔與送出前都檢查。
// 結果用 [AdminVideoReuploadResult] 交回列表：送出成功就地換掉那一列，狀態已改變或影片不存在就重抓。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import '../../services/video_upload/video_upload_manager.dart';
import 'admin_error.dart';
import 'admin_video_upload_progress_screen.dart';
import 'widgets/admin_video_file_field.dart';
import 'widgets/admin_widgets.dart';

/// 重新上傳頁回列表的結果；直接返回時是 null。
sealed class AdminVideoReuploadResult {
  const AdminVideoReuploadResult();
}

/// 已開始重新上傳，[video] 是後端回的新資料（處理中）。
final class AdminVideoReuploaded extends AdminVideoReuploadResult {
  final AdminVideo video;
  const AdminVideoReuploaded(this.video);
}

/// 影片狀態已改變（409 VIDEO_NOT_FAILED）、已不存在（404 VIDEO_NOT_FOUND），
/// 或後端已改成處理中但這裡沒能開始上傳（送出期間別支先開始了），列表要重抓。
final class AdminVideoReuploadStale extends AdminVideoReuploadResult {
  const AdminVideoReuploadStale();
}

class AdminVideoReuploadScreen extends StatefulWidget {
  final AdminVideo video;

  const AdminVideoReuploadScreen({super.key, required this.video});

  @override
  State<AdminVideoReuploadScreen> createState() =>
      _AdminVideoReuploadScreenState();
}

class _AdminVideoReuploadScreenState extends State<AdminVideoReuploadScreen> {
  /// 選好、還沒送出的影片檔；選了但沒送出就離開時由它刪掉暫存複本。
  final _file = AdminVideoFileController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _file.addListener(_onFileChanged);
  }

  void _onFileChanged() => setState(() {});

  @override
  void dispose() {
    _file.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final picked = _file.picked;
    if (picked == null || _busy) return;
    // 後端一收到就把影片改成處理中，之後才發現有別支在傳就沒人上傳了，所以先擋。
    if (blockedByActiveUpload(context)) return;
    setState(() => _busy = true);
    try {
      final r = await AdminService.retryVideo(widget.video.id, picked.info);
      VideoUploadManager.instance.start(
        r.video,
        r.session,
        picked.source,
        fileName: picked.info.name,
      );
      // 交給上傳服務了，離開這頁時不能刪。
      _file.handOver();
      if (mounted) {
        await replaceWithAdmin<void, AdminVideoReuploadResult>(
          context,
          const AdminVideoUploadProgressScreen(),
          result: AdminVideoReuploaded(r.video),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e is UploadBusy) {
        // 後端已把影片改成處理中（只是這裡沒能開始傳）：回列表重抓，不再顯示成失敗。
        blockedByActiveUpload(context);
        Navigator.of(context).pop(const AdminVideoReuploadStale());
        return;
      }
      final stale = _staleMessage(e);
      if (stale != null) {
        showAdminMessage(stale);
        Navigator.of(context).pop(const AdminVideoReuploadStale());
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

  /// 這支影片已不能重新上傳時給管理員看的提示；其他錯誤回 null。
  static String? _staleMessage(Object e) {
    if (e is! ApiException) return null;
    return switch (e.code) {
      'VIDEO_NOT_FAILED' => '這支影片的狀態已改變，列表已重新整理',
      'VIDEO_NOT_FOUND' => '這支影片已不存在',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AdminScaffold(
      title: '重新上傳',
      body: (context, senior) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _videoCard(senior),
            const SizedBox(height: AppSpacing.md),
            AdminVideoFileField(
              controller: _file,
              enabled: !_busy,
              seniorMode: senior,
            ),
          ],
        ),
      ),
      bottom: (context, senior) => AdminActionBar(
        children: [
          FilledButton(
            onPressed: _busy || _file.preparing || _file.picked == null
                ? null
                : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.creamLight,
            ),
            child: Text(_busy ? '建立中…' : '重新上傳'),
          ),
        ],
      ),
    ),
  );

  /// 要重新上傳的影片：標題、失敗原因，提醒資訊沿用。
  Widget _videoCard(bool senior) {
    final failReason = widget.video.failReason;
    return AdminCard(
      seniorMode: senior,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyLargeStyle(
              seniorMode: senior,
              color: AppColors.ink,
            ),
          ),
          if (failReason != null && failReason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                '失敗原因：$failReason',
                style: AppTypography.captionStyle(
                  seniorMode: senior,
                  color: AppColors.dangerDark,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '選一支新的影片檔，標題、說明、分類、部落沿用原本的；要修改請用「編輯」。',
            style: AppTypography.bodyStyle(
              seniorMode: senior,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
