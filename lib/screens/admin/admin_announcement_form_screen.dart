// 發官方公告：標題、內文、選填一張圖片、是否同時推播。
// 會發給所有使用者，送出前二次確認；成功後顯示寫入人數與推播成功數。
// 規格：Truku_backend 說明文件/API/收件匣與申訴.md §5.1。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../services/admin_service.dart';
import '../../shared/utils/upload_image.dart';
import '../../shared/utils/utf16_length_limit.dart';
import '../../shared/widgets/confirm_dialog.dart';
import 'admin_error.dart';
import 'widgets/admin_widgets.dart';

const _titleMax = 100;
const _bodyMax = 5000;
const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

/// 送出後結果不明：請求可能已到後端並寫入。後端要等全體推播送完才回應，
/// 這段時間公告已經 commit。斷線（NETWORK_ERROR、非 ApiException 的連線錯誤）、
/// 閘道錯誤 502／503 與逾時 504（Cloud Run 在推播途中掛掉或逾時）時不能讓管理員
/// 直接重送，否則全體會收到兩則收不回的公告。
bool _outcomeUnknown(Object error) =>
    error is! ApiException ||
    error.code == 'NETWORK_ERROR' ||
    const {502, 503, 504}.contains(error.statusCode);

class AdminAnnouncementFormScreen extends StatefulWidget {
  const AdminAnnouncementFormScreen({super.key});

  @override
  State<AdminAnnouncementFormScreen> createState() =>
      _AdminAnnouncementFormScreenState();
}

class _AdminAnnouncementFormScreenState
    extends State<AdminAnnouncementFormScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();

  /// 壓縮後的 JPEG；沒選圖為 null。
  Uint8List? _image;
  bool _push = true;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting &&
      _title.text.trim().isNotEmpty &&
      _body.text.trim().isNotEmpty;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final ext = picked.name.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(ext)) {
      showAdminMessage('僅接受 JPEG／PNG／WebP 圖片');
      return;
    }
    final compressed = await compressImageForUpload(picked);
    if (!mounted) return;
    if (compressed == null) {
      showAdminMessage('無法處理這張圖片，請換一張');
      return;
    }
    if (compressed.length > AdminService.announcementImageMaxBytes) {
      showAdminMessage('圖片壓縮後仍超過 5 MB，請換一張較小的圖');
      return;
    }
    setState(() => _image = compressed);
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (!withinUtf16Limit(context, title, _titleMax, label: '標題') ||
        !withinUtf16Limit(context, body, _bodyMax, label: '內文')) {
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: '發布公告？',
      message:
          '這則公告會發給所有使用者，發布後無法收回。\n'
          '${_push ? '同時會推播通知所有人。' : '只進收件匣，不推播。'}',
      confirmText: '發布',
    );
    if (!confirmed || !mounted) return;
    setState(() => _submitting = true);
    try {
      final result = await AdminService.createAnnouncement(
        title: title,
        body: body,
        imageBytes: _image,
        push: _push,
      );
      if (!mounted) return;
      await showAdminInfoDialog(
        context,
        title: '已發布',
        message:
            '已寫入 ${result.announcement.recipients} 人的收件匣。\n'
            '${_push ? '推播成功 ${result.pushed} 則。' : '沒有推播。'}',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      if (_outcomeUnknown(e)) {
        // 不解鎖：帶回列表重抓，讓管理員先確認是否已發出。
        await showAdminInfoDialog(
          context,
          title: '無法確認是否已發布',
          message: '公告可能已經發出，請回列表確認。',
        );
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      setState(() => _submitting = false);
      handleAdminError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // 送出中擋系統返回、手勢與返回鈕（maybePop）：離開後就看不到發布結果。
    // 成功或結果不明時由 _submit 直接 pop，不受影響。
    canPop: !_submitting,
    child: _form(context),
  );

  Widget _form(BuildContext context) => AdminScaffold(
    title: '新增公告',
    body: (context, senior) => ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        TextField(
          controller: _title,
          inputFormatters: const [
            Utf16LengthLimitingTextInputFormatter(_titleMax),
          ],
          buildCounter: utf16CounterBuilder(_title, _titleMax),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: '標題'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _body,
          minLines: 6,
          maxLines: 14,
          inputFormatters: const [
            Utf16LengthLimitingTextInputFormatter(_bodyMax),
          ],
          buildCounter: utf16CounterBuilder(_body, _bodyMax),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: '內文',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_image != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(_image!, height: 180, fit: BoxFit.cover),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() => _image = null),
              child: const Text('移除圖片'),
            ),
          ),
        ] else
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pickImage,
            icon: const Icon(Icons.image_outlined),
            label: const Text('加一張圖片（選填）'),
          ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _push,
          onChanged: _submitting ? null : (v) => setState(() => _push = v),
          title: Text(
            '同時推播',
            style: AppTypography.bodyLargeStyle(
              seniorMode: senior,
              color: AppColors.ink,
            ),
          ),
          subtitle: Text(
            '關閉時只進收件匣。',
            style: AppTypography.captionStyle(
              seniorMode: senior,
              color: AppColors.fog,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text('發布'),
        ),
      ],
    ),
  );
}
