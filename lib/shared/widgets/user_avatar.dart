import 'package:flutter/material.dart';
import '../../models/shop_item.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';

// 使用者頭像渲染邏輯（與個人資料頁一致，見 頭像商店.md §5）：
// 已配戴內建頭像（avatarId）優先，對照商店目錄取得 image_url；否則退回原始
// 大頭貼（avatarUrl）；兩者皆無或載入失敗則顯示預設 Icons.person。
class UserAvatar extends StatelessWidget {
  final String? avatarId;
  final String? avatarUrl;
  final Map<String, ShopItem> itemCatalogById;
  final double size;
  final Color fallbackIconColor;

  const UserAvatar({
    super.key,
    this.avatarId,
    this.avatarUrl,
    this.itemCatalogById = const {},
    required this.size,
    required this.fallbackIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackIcon = Icon(
      Icons.person,
      size: size * 0.65,
      color: fallbackIconColor,
    );

    if (avatarId != null) {
      final imageUrl = itemCatalogById[avatarId]?.imageUrl;
      if (imageUrl != null) {
        return Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallbackIcon,
        );
      }
      return fallbackIcon;
    }

    if (avatarUrl != null) {
      return Image.network(
        avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallbackIcon,
      );
    }

    return fallbackIcon;
  }
}

// 頭像 + 頭像框疊加渲染，全平台（好友列表/聊天/來電/論壇/活動…）共用一份，
// 避免各畫面各寫一套 Stack（見 profile_screen.dart 舊版 _buildAvatar()）。
// 框在外、頭像在中間；無 frameId 時純顯示頭像。
class FramedUserAvatar extends StatelessWidget {
  final String? avatarId;
  final String? avatarUrl;
  final String? frameId;
  final Map<String, ShopItem> itemCatalogById;
  final double size;
  final Color fallbackIconColor;
  final Widget? fallback;

  /// 這個頭像屬於誰。等於目前登入者時改以 UserService 的快取為準並隨之更新：
  /// 貼文、留言、參加者名單的作者欄是「當下的快照」，換頭像後不會自己變。
  /// 傳 null 或別人的 uid 時行為完全不變。
  final int? userUid;

  const FramedUserAvatar({
    super.key,
    this.avatarId,
    this.avatarUrl,
    this.frameId,
    this.itemCatalogById = const {},
    required this.size,
    required this.fallbackIconColor,
    this.fallback,
    this.userUid,
  });

  @override
  Widget build(BuildContext context) {
    if (userUid != null && userUid == UserService.currentUid) {
      return ValueListenableBuilder<UserModel?>(
        valueListenable: UserService.userNotifier,
        builder: (context, me, _) => _build(
          me?.uid == userUid ? me!.avatarId : avatarId,
          me?.uid == userUid ? me!.avatarUrl : avatarUrl,
          me?.uid == userUid ? me!.frameId : frameId,
        ),
      );
    }
    return _build(avatarId, avatarUrl, frameId);
  }

  Widget _build(String? avatarId, String? avatarUrl, String? frameId) {
    final frameImageUrl = frameId != null
        ? itemCatalogById[frameId]?.imageUrl
        : null;
    final avatar = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child:
            fallback != null &&
                avatarId == null &&
                (avatarUrl == null || avatarUrl.isEmpty)
            ? fallback
            : UserAvatar(
                avatarId: avatarId,
                avatarUrl: avatarUrl,
                itemCatalogById: itemCatalogById,
                size: size,
                fallbackIconColor: fallbackIconColor,
              ),
      ),
    );

    if (frameImageUrl == null) return avatar;

    final frameSize = size * 1.2;
    return SizedBox(
      width: frameSize,
      height: frameSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.network(
            frameImageUrl,
            width: frameSize,
            height: frameSize,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          avatar,
        ],
      ),
    );
  }
}
