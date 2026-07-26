// 頭像商店 API 呼叫（issue #12、#32 遷移至共用 ApiClient）
//
// 端點（見 Truku_backend 說明文件/API/頭像商店.md v2.0）：
//   - GET /api/shop/items（可選 ?type=avatar|frame）：頭像／頭像框合併目錄
//   - POST /api/shop/items/{id}/purchase：頭像與頭像框走同一支，後端依 type 自動判斷
//   - PATCH /api/me 帶 avatar_id／frame_id：切換配戴，各自獨立
//
// 統一走共用 ApiClient：帶 JWT、統一 {error:{code,message}} 解析、401 自動登出、
// 離線（SocketException）轉成 NETWORK_ERROR。業務錯誤（ITEM_NOT_FOUND／
// INSUFFICIENT_BALANCE／ALREADY_OWNED 等）與離線／401 皆以 [ApiException] 表示。

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/shop_item.dart';
import '../models/user_model.dart';

class ShopService {
  /// 呼叫 GET /api/shop/items，取得後端算好的頭像／頭像框合併目錄
  /// （含 image_url／is_owned）。可選 [type]（'avatar'|'frame'）過濾，不帶則兩種都回。
  static Future<List<ShopItem>> fetchShopItems({String? type}) async {
    final json = await ApiClient.get(
      ApiConfig.shopItems,
      query: type != null ? {'type': type} : null,
    );
    final list = json['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => ShopItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 呼叫既有 GET /api/me，解析為 [UserModel]。
  static Future<UserModel> fetchMe() async {
    final json = await ApiClient.get(ApiConfig.meEndpoint);
    return UserModel.fromJson(json);
  }

  /// 呼叫 POST /api/shop/items/{id}/purchase。頭像與頭像框走同一支端點，
  /// 後端依 item_catalog.type 自動判斷，呼叫端不需分開處理。
  static Future<UserModel> purchaseItem(String itemId) async {
    final json =
        await ApiClient.post(ApiConfig.itemPurchaseEndpoint(itemId));
    return UserModel.fromJson(json);
  }

  /// 呼叫 PATCH /api/me 帶 avatar_id，切換配戴中的內建頭像。
  static Future<UserModel> equipAvatar(String avatarId) async {
    final updated = await _patchMe({'avatar_id': avatarId});

    // PATCH /api/me 若靜默忽略未知欄位並回傳 200，回傳的 avatar_id 會跟請求不一致，
    // 不可視為成功，否則會誤導使用者「已配戴」但其實沒有持久化。
    if (updated.avatarId != avatarId) {
      throw _updateNotApplied();
    }
    return updated;
  }

  /// 呼叫 PATCH /api/me 帶 avatar_id: null，恢復顯示預設（登入帳號）頭貼。
  static Future<UserModel> clearAvatar() async {
    final updated = await _patchMe({'avatar_id': null});

    if (updated.avatarId != null) {
      throw _updateNotApplied();
    }
    return updated;
  }

  /// 呼叫 PATCH /api/me 帶 frame_id，切換配戴中的頭像框；與 avatar_id 各自獨立。
  static Future<UserModel> equipFrame(String frameId) async {
    final updated = await _patchMe({'frame_id': frameId});

    if (updated.frameId != frameId) {
      throw _updateNotApplied();
    }
    return updated;
  }

  /// 呼叫 PATCH /api/me 帶 frame_id: null，恢復不配戴頭像框。
  static Future<UserModel> clearFrame() async {
    final updated = await _patchMe({'frame_id': null});

    if (updated.frameId != null) {
      throw _updateNotApplied();
    }
    return updated;
  }

  static Future<UserModel> _patchMe(Map<String, dynamic> body) async {
    final json = await ApiClient.patch(ApiConfig.meEndpoint, body);
    return UserModel.fromJson(json);
  }

  /// 後端回 200 但未真正持久化（回傳值與請求不符）時拋出的防呆錯誤。
  static ApiException _updateNotApplied() => ApiException(
        statusCode: 200,
        code: 'UPDATE_NOT_APPLIED',
        message: '更新未生效，請稍後再試',
      );
}
