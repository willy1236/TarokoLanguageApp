// 編輯影片：改標題、說明、分類、部落（後台影片 T-07）。不能換影片檔。
// 規格：Truku_backend 說明文件/API/內部管理.md §6.2 PATCH /api/admin/videos/:id。
//
// 只送有改動的欄位（AdminVideoMeta.patchFrom）；沒有改動不送出，因為後端會回 400。
// 結果用 [AdminVideoEditResult] 交回列表：已更新就地換掉那一列，不存在就重抓。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../models/admin_models.dart';
import '../../models/admin_video_meta.dart';
import '../../models/content_category.dart';
import '../../services/admin_service.dart';
import '../../services/category_service.dart';
import 'admin_error.dart';
import 'widgets/admin_video_meta_fields.dart';
import 'widgets/admin_widgets.dart';

/// 編輯頁 pop 回列表的結果；直接返回時是 null。
sealed class AdminVideoEditResult {
  const AdminVideoEditResult();
}

/// 已儲存，[video] 是後端回的新資料。
final class AdminVideoUpdated extends AdminVideoEditResult {
  final AdminVideo video;
  const AdminVideoUpdated(this.video);
}

/// 影片已不存在（404 VIDEO_NOT_FOUND），列表要重抓。
final class AdminVideoGone extends AdminVideoEditResult {
  const AdminVideoGone();
}

class AdminVideoEditScreen extends StatefulWidget {
  final AdminVideo video;

  const AdminVideoEditScreen({super.key, required this.video});

  @override
  State<AdminVideoEditScreen> createState() => _AdminVideoEditScreenState();
}

class _AdminVideoEditScreenState extends State<AdminVideoEditScreen> {
  final _meta = AdminVideoMetaController();
  late final AdminVideoMeta _original = AdminVideoMeta(
    title: widget.video.title,
    description: widget.video.description,
    category: widget.video.category,
    tribeId: widget.video.tribeId,
  );
  bool _busy = false;

  @override
  void dispose() {
    _meta.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_meta.validate()) return;
    final fields = _meta.value.patchFrom(_original);
    if (fields.isEmpty) {
      showAdminMessage('沒有變更');
      return;
    }
    // 分類沒改就沒送，後端不會新增分類。
    final isNewCategory = _meta.isNewCategory && fields.containsKey('category');
    setState(() => _busy = true);
    try {
      final updated = await AdminService.updateVideo(widget.video.id, fields);
      if (isNewCategory) _refreshVideoCategories();
      showAdminMessage('已儲存');
      if (mounted) Navigator.of(context).pop(AdminVideoUpdated(updated));
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.code == 'VIDEO_NOT_FOUND') {
        showAdminMessage('這支影片已不存在');
        Navigator.of(context).pop(const AdminVideoGone());
        return;
      }
      setState(() => _busy = false);
      handleAdminError(context, e);
    }
  }

  /// 後端已把新分類加進影音分類表：刷新快取，列表與影音頁才拿得到名稱。失敗不影響儲存結果。
  void _refreshVideoCategories() {
    CategoryService.fetch(CategoryModule.videos, refresh: true).then<void>(
      (_) {},
      onError: (Object e) => debugPrint('AdminVideoEditScreen: 影音分類快取刷新失敗：$e'),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AdminScaffold(
      title: '編輯影片',
      body: (context, senior) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AdminVideoMetaFields(
          initial: _original,
          controller: _meta,
          seniorMode: senior,
        ),
      ),
      bottom: (context, senior) => AdminActionBar(
        children: [
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.creamLight,
            ),
            child: Text(_busy ? '儲存中…' : '儲存'),
          ),
        ],
      ),
    ),
  );
}
