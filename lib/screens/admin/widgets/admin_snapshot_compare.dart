// 「檢舉當時」與「目前」的內容對照，檢舉詳情與違規案件詳情共用。
//
// 被檢舉的人可能在審核前把內容改掉；後端在檢舉送出時存了一份（貼文、活動、
// 個人檔案），管理員依當時的內容判斷。頭像複本是限時網址，不存到本機，
// 過期後下拉重新整理拿新的。

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/admin_models.dart';
import '../../../models/shop_item.dart';
import '../../../services/shop_service.dart';
import '../../../shared/widgets/ephemeral_network_image.dart';
import '../../../shared/widgets/user_avatar.dart';
import 'admin_widgets.dart';

const _avatarSize = 72.0;

/// 「⚠️ 檢舉後已修改」標籤：佇列與詳情都用。
class AdminChangedBadge extends StatelessWidget {
  final bool seniorMode;

  const AdminChangedBadge({super.key, this.seniorMode = false});

  @override
  Widget build(BuildContext context) => AdminBadge(
    '⚠️ 檢舉後已修改',
    color: AppColors.dangerDark,
    seniorMode: seniorMode,
  );
}

class AdminSnapshotCompare extends StatelessWidget {
  /// 檢舉當時的內容。
  final AdminReportSnapshot snapshot;

  /// post／event／profile：決定要列哪些欄位。
  final String targetType;

  /// 目前的內容，由呼叫端用原本的預覽元件呈現。
  final Widget current;
  final bool seniorMode;

  const AdminSnapshotCompare({
    super.key,
    required this.snapshot,
    required this.targetType,
    required this.current,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('檢舉當時（請依這份判斷）'),
      ..._snapshotRows(),
      const SizedBox(height: 8),
      _heading('目前'),
      current,
    ],
  );

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: AppTypography.subtitleStyle(
        seniorMode: seniorMode,
        color: AppColors.ink,
      ),
    ),
  );

  String _orNone(String? value) =>
      value == null || value.isEmpty ? '（無）' : value;

  List<Widget> _snapshotRows() => switch (targetType) {
    'event' => [
      AdminQuote(_orNone(snapshot.title), seniorMode: seniorMode),
      AdminQuote(_orNone(snapshot.description), seniorMode: seniorMode),
      AdminInfoRow('地點', _orNone(snapshot.location), seniorMode: seniorMode),
      AdminInfoRow('地址', _orNone(snapshot.address), seniorMode: seniorMode),
    ],
    'profile' => [
      AdminInfoRow('暱稱', _orNone(snapshot.nickname), seniorMode: seniorMode),
      AdminInfoRow('自我介紹', _orNone(snapshot.selfIntro), seniorMode: seniorMode),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: _SnapshotAvatar(snapshot: snapshot, seniorMode: seniorMode),
      ),
    ],
    _ => [
      AdminQuote(_orNone(snapshot.title), seniorMode: seniorMode),
      AdminQuote(_orNone(snapshot.body), seniorMode: seniorMode),
    ],
  };
}

/// 檢舉當時的頭像：有複本就顯示複本（自訂頭像），否則依 avatar_id／avatar_url
/// 顯示商店頭像或 Google 大頭貼，都沒有就是預設頭像。
class _SnapshotAvatar extends StatefulWidget {
  final AdminReportSnapshot snapshot;
  final bool seniorMode;

  const _SnapshotAvatar({required this.snapshot, required this.seniorMode});

  @override
  State<_SnapshotAvatar> createState() => _SnapshotAvatarState();
}

class _SnapshotAvatarState extends State<_SnapshotAvatar> {
  Map<String, ShopItem> _catalog = const {};

  @override
  void initState() {
    super.initState();
    // 只有商店頭像才需要目錄把 avatar_id 換成圖。
    if (widget.snapshot.avatarEvidenceUrl == null &&
        widget.snapshot.avatarId != null) {
      _loadCatalog();
    }
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await ShopService.fetchItemCatalogCached();
      if (mounted) setState(() => _catalog = catalog);
    } catch (e) {
      debugPrint('AdminSnapshotCompare: 取得商店目錄失敗，頭像顯示預設圖示：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final evidence = s.avatarEvidenceUrl;
    final String caption;
    final Widget image;
    if (evidence != null && evidence.isNotEmpty) {
      caption = '頭像（當時的自訂頭像複本）';
      image = EphemeralNetworkImage(
        url: evidence,
        width: _avatarSize,
        height: _avatarSize,
        failedHint: '已過期',
      );
    } else {
      caption = s.avatarId != null
          ? '頭像（商店頭像）'
          : s.avatarUrl != null
          ? '頭像（Google 大頭貼）'
          : '頭像（預設）';
      image = ClipOval(
        child: Container(
          width: _avatarSize,
          height: _avatarSize,
          color: AppColors.creamDeep,
          alignment: Alignment.center,
          child: UserAvatar(
            avatarId: s.avatarId,
            avatarUrl: s.avatarUrl,
            itemCatalogById: _catalog,
            size: _avatarSize,
            fallbackIconColor: AppColors.fog,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: AppTypography.bodyStyle(
            seniorMode: widget.seniorMode,
            color: AppColors.fog,
          ),
        ),
        const SizedBox(height: 4),
        image,
        if (evidence != null && evidence.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '圖片約 15 分鐘後過期，看不到時下拉重新整理。',
              style: AppTypography.captionStyle(
                seniorMode: widget.seniorMode,
                color: AppColors.fog,
              ),
            ),
          ),
      ],
    );
  }
}
