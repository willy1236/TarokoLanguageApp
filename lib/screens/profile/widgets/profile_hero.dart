// 個人頁頂部：頭像（含配戴外框）、名稱、族群／部落資訊。

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/shop_item.dart';
import '../../../models/user_model.dart';
import '../../../shared/widgets/truku_painters.dart';
import '../../../shared/widgets/user_avatar.dart';
import 'profile_rows.dart';

class ProfileHero extends StatelessWidget {
  /// null 代表尚未載入完成。
  final UserModel? user;
  final Map<String, ShopItem> itemCatalogById;
  final bool seniorMode;
  final VoidCallback onAvatarTap;
  final VoidCallback onTribalNameTap;

  /// 上方已有其他元件（如合併分頁的膠囊切換）時傳 false，頂部不再預留狀態列空間。
  final bool reserveStatusBar;

  /// 合併分頁的膠囊切換：放在深色底內的最上方，讓深底一路延伸到狀態列。
  final Widget? topToggle;

  const ProfileHero({
    super.key,
    required this.user,
    required this.itemCatalogById,
    required this.seniorMode,
    required this.onAvatarTap,
    required this.onTribalNameTap,
    this.reserveStatusBar = true,
    this.topToggle,
  });

  @override
  Widget build(BuildContext context) =>
      _buildHero(context, seniorMode: seniorMode);

  double _contentTopPadding() {
    if (topToggle != null) return 16;
    return reserveStatusBar ? 76 : 28;
  }

  Widget _buildHero(BuildContext context, {required bool seniorMode}) {
    final tribeLine = user?.isIndigenous == true
        ? (user?.tribeName ?? '尚未設定')
        : null;
    return Container(
      decoration: const BoxDecoration(color: AppColors.midnight),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: CustomPaint(
                painter: TrukuWeavePainter(
                  color: AppColors.gold,
                  opacity: 1.0,
                  scale: 0.8,
                ),
              ),
            ),
          ),
          Column(
            children: [
              if (topToggle != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 12,
                    20,
                    0,
                  ),
                  child: topToggle,
                ),
              _buildProfileRow(seniorMode: seniorMode, tribeLine: tribeLine),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow({
    required bool seniorMode,
    required String? tribeLine,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, _contentTopPadding(), 20, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 名稱是頂端主角：放大到 display28（精簡模式同步 +2），
                // 長名稱最多兩行後截斷；頭像固定寬，名稱在 Expanded 內不會推擠它。
                Text(
                  user?.displayName ?? 'Apyang Imiq',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTypography.headlineStyle(
                        seniorMode: seniorMode,
                        color: AppColors.creamLight,
                      ).copyWith(
                        fontSize: AppTypography.size(
                          AppTypography.display28,
                          seniorMode: seniorMode,
                        ),
                      ),
                ),
                const SizedBox(height: 2),
                _buildTribalName(seniorMode: seniorMode),
                const SizedBox(height: 4),
                if (tribeLine != null)
                  Text(
                    tribeLine,
                    style: AppTypography.titleStyle(
                      seniorMode: seniorMode,
                      color: AppColors.creamLight.withValues(alpha: 0.75),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 族語名只開放原住民（與完善資料頁一致）：有填顯示族語斜體，
  /// 未填顯示淡色引導字，點了開編輯；非原住民整行不顯示。
  Widget _buildTribalName({required bool seniorMode}) {
    if (user?.isIndigenous != true) return const SizedBox.shrink();
    final name = user!.tribalName;
    final hasName = name != null && name.isNotEmpty;
    return GestureDetector(
      onTap: onTribalNameTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        hasName ? name : '+ 新增族語名',
        style: hasName
            ? AppTypography.latin(fontStyle: FontStyle.italic).copyWith(
                fontSize: AppTypography.size(
                  AppTypography.subtitle,
                  seniorMode: seniorMode,
                ),
                color: AppColors.gold,
              )
            : AppTypography.bodyStyle(
                seniorMode: seniorMode,
                color: AppColors.creamLight.withValues(alpha: 0.5),
              ),
      ),
    );
  }

  Widget _buildAvatar() {
    // 頭像框疊加在頭像外圍：見共用元件 FramedUserAvatar（lib/shared/widgets/user_avatar.dart）。
    // 整顆頭像都可點，鉛筆只是提示；只綁鉛筆時實機很難點中。
    return GestureDetector(
      onTap: onAvatarTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: user?.frameId == null
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 2),
                    )
                  : null,
              child: FramedUserAvatar(
                avatarId: user?.avatarId,
                avatarUrl: user?.avatarUrl,
                frameId: user?.frameId,
                itemCatalogById: itemCatalogById,
                size: 80,
                fallbackIconColor: AppColors.gold.withValues(alpha: 0.7),
              ),
            ),
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: CustomPaint(painter: ProfileEditIconPainter()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
