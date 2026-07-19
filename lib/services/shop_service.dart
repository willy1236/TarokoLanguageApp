// 頭像商店 API 呼叫（issue #12）
//
// 端點（見 Truku_backend 說明文件/API/頭像商店.md v2.0）：
//   - GET /api/shop/items（可選 ?type=avatar|frame）：頭像／頭像框合併目錄
//   - POST /api/shop/items/{id}/purchase：頭像與頭像框走同一支，後端依 type 自動判斷
//   - PATCH /api/me 帶 avatar_id／frame_id：切換配戴，各自獨立
//
// 錯誤分流原則：路由真的不存在時，Express 預設 404 回的是純文字（如
// "Cannot GET /api/shop/items"），不是 app 的 JSON 錯誤格式 {error:{code,message}}；
// 路由存在但業務邏輯拒絕時，才會回傳帶 code 的正式錯誤（ITEM_NOT_FOUND／
// INVALID_TYPE／INSUFFICIENT_BALANCE／ALREADY_OWNED／UNLOCK_CONDITION_NOT_MET／
// AVATAR_NOT_OWNED／FRAME_NOT_OWNED）。因此用「body 能否解析出 error.code」來分流：
//   - 解析得到 code → 路由已存在，是真正的業務錯誤 → 拋 [ShopApiException]（帶 code）
//   - 解析不到（純文字/HTML/連線失敗）→ 路由還不存在 → 拋 [ShopFeatureUnavailableException]
// 讓呼叫端可以分別處理「功能尚未開放」與「這次操作真的被拒絕」兩種情境。
//
// HTTP 呼叫模式沿用 lib/services/auth_service.dart：
//   - 用 package:http 的 http.get/post/patch
//   - Authorization header 帶 Bearer token（token 由 AuthService.currentToken() 取得）
//   - jsonDecode(resp.body) 解析回應

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants/api.dart';
import '../models/shop_item.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class ShopService {
  /// 呼叫 GET /api/shop/items，取得後端算好的頭像／頭像框合併目錄
  /// （含 image_url／is_owned）。可選 [type]（'avatar'|'frame'）過濾，不帶則兩種都回。
  static Future<List<ShopItem>> fetchShopItems({String? type}) async {
    final token = await AuthService.currentToken();
    final uri = Uri.parse(ApiConfig.baseUrl + ApiConfig.shopItems).replace(
      queryParameters: type != null ? {'type': type} : null,
    );
    late final http.Response resp;
    try {
      resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } on SocketException {
      throw ShopFeatureUnavailableException('頭像商店功能尚未開放');
    }

    _throwIfError(resp, unavailableMessage: '頭像商店功能尚未開放');

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = data['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => ShopItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 呼叫既有 GET /api/me，解析為 [UserModel]。
  static Future<UserModel> fetchMe() async {
    final token = await AuthService.currentToken();
    late final http.Response resp;
    try {
      resp = await http.get(
        Uri.parse(ApiConfig.baseUrl + ApiConfig.meEndpoint),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } on SocketException {
      throw ShopFeatureUnavailableException('無法連線到伺服器');
    }

    _throwIfError(resp, unavailableMessage: '無法取得使用者資料');

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  /// 呼叫 POST /api/shop/items/{id}/purchase。頭像與頭像框走同一支端點，
  /// 後端依 item_catalog.type 自動判斷，呼叫端不需分開處理。
  static Future<UserModel> purchaseItem(String itemId) async {
    final token = await AuthService.currentToken();
    late final http.Response resp;
    try {
      resp = await http.post(
        Uri.parse(ApiConfig.baseUrl + ApiConfig.itemPurchaseEndpoint(itemId)),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } on SocketException {
      throw ShopFeatureUnavailableException('頭像商店功能尚未開放');
    }

    _throwIfError(resp, unavailableMessage: '頭像商店功能尚未開放');

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  /// 呼叫 PATCH /api/me 帶 avatar_id，切換配戴中的內建頭像。
  static Future<UserModel> equipAvatar(String avatarId) async {
    final updated = await _patchMe({'avatar_id': avatarId});

    // PATCH /api/me 若靜默忽略未知欄位並回傳 200，回傳的 avatar_id 會跟請求不一致，
    // 不可視為成功，否則會誤導使用者「已配戴」但其實沒有持久化。
    if (updated.avatarId != avatarId) {
      throw ShopFeatureUnavailableException('更換頭像功能尚未開放');
    }
    return updated;
  }

  /// 呼叫 PATCH /api/me 帶 frame_id，切換配戴中的頭像框；與 avatar_id 各自獨立。
  static Future<UserModel> equipFrame(String frameId) async {
    final updated = await _patchMe({'frame_id': frameId});

    if (updated.frameId != frameId) {
      throw ShopFeatureUnavailableException('更換頭像框功能尚未開放');
    }
    return updated;
  }

  static Future<UserModel> _patchMe(Map<String, dynamic> body) async {
    final token = await AuthService.currentToken();
    late final http.Response resp;
    try {
      resp = await http.patch(
        Uri.parse(ApiConfig.baseUrl + ApiConfig.meEndpoint),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
    } on SocketException {
      throw ShopFeatureUnavailableException('更換功能尚未開放');
    }

    _throwIfError(resp, unavailableMessage: '更換功能尚未開放');

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  /// 非 200 時分流拋出：body 能解析出 error.code → [ShopApiException]（真正的業務錯誤）；
  /// 否則（純文字/HTML，代表路由還不存在）→ [ShopFeatureUnavailableException]。
  static void _throwIfError(
    http.Response resp, {
    required String unavailableMessage,
  }) {
    if (resp.statusCode == 200) return;
    final apiError = _tryParseApiError(resp.body);
    if (apiError != null) throw apiError;
    throw ShopFeatureUnavailableException(unavailableMessage);
  }

  static ShopApiException? _tryParseApiError(String body) {
    try {
      final j = jsonDecode(body);
      final error = j['error'] as Map<String, dynamic>?;
      final code = error?['code'] as String?;
      if (code == null) return null;
      return ShopApiException(code, error?['message'] as String? ?? '請求失敗');
    } catch (_) {
      return null;
    }
  }
}

/// 呼叫尚未存在的頭像商店端點（404）或連線失敗時拋出，
/// 讓呼叫端可以辨識並顯示「功能尚未開放」而非一般錯誤訊息。
class ShopFeatureUnavailableException implements Exception {
  final String message;
  ShopFeatureUnavailableException(this.message);
  @override
  String toString() => message;
}

/// 後端路由已存在、回傳正式 {error:{code,message}} 格式的業務錯誤時拋出（見
/// 頭像商店.md：ITEM_NOT_FOUND／INVALID_TYPE／INSUFFICIENT_BALANCE／ALREADY_OWNED／
/// UNLOCK_CONDITION_NOT_MET／AVATAR_NOT_OWNED／FRAME_NOT_OWNED 等），
/// 呼叫端可依 [code] 判斷後續行為，不應與「功能尚未開放」混為一談。
class ShopApiException implements Exception {
  final String code;
  final String message;
  ShopApiException(this.code, this.message);
  @override
  String toString() => message;
}
