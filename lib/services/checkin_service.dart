// 每日簽到 API 呼叫（issue #24）
//
// 端點（見 Truku_backend 說明文件/API/每日簽到.md）：
//   - GET /api/checkin/status：簽到按鈕初始狀態
//   - POST /api/checkin：執行簽到，成功 millet +50；重複呼叫回 409 ALREADY_CHECKED_IN
//
// 兩支端點回應只有 checked_in_today／checkin_streak／millet 三欄，不是完整 user
// 物件，因此不直接餵給 UserModel.fromJson（會缺 uid/email/created_at 而炸掉），
// 改回傳 [CheckinStatus]，由呼叫端用 UserModel.copyWith 合併回現有使用者資料。
//
// 錯誤分流原則沿用 lib/services/shop_service.dart：body 能解析出 error.code
// → 路由已存在，是真正的業務錯誤 → 拋 [CheckinApiException]（帶 code，例如
// ALREADY_CHECKED_IN）；解析不到（純文字/HTML/連線失敗）→ 路由還不存在 →
// 拋 [CheckinFeatureUnavailableException]。

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants/api.dart';
import 'auth_service.dart';

/// 簽到狀態，對應 checkin/status、checkin 端點的回應。
class CheckinStatus {
  final bool checkedInToday;
  final int checkinStreak;
  final int millet;

  const CheckinStatus({
    required this.checkedInToday,
    required this.checkinStreak,
    required this.millet,
  });

  factory CheckinStatus.fromJson(Map<String, dynamic> json) {
    return CheckinStatus(
      checkedInToday: json['checked_in_today'] as bool? ?? false,
      checkinStreak: json['checkin_streak'] as int? ?? 0,
      millet: json['millet'] as int? ?? 0,
    );
  }
}

class CheckinService {
  /// 呼叫 GET /api/checkin/status，取得簽到按鈕初始狀態。
  static Future<CheckinStatus> fetchStatus() async {
    final token = await AuthService.currentToken();
    late final http.Response resp;
    try {
      resp = await http.get(
        Uri.parse(ApiConfig.baseUrl + ApiConfig.checkinStatus),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } on SocketException {
      throw CheckinFeatureUnavailableException('每日簽到功能尚未開放');
    }

    _throwIfError(resp, unavailableMessage: '每日簽到功能尚未開放');

    return CheckinStatus.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// 呼叫 POST /api/checkin，執行簽到。
  static Future<CheckinStatus> checkin() async {
    final token = await AuthService.currentToken();
    late final http.Response resp;
    try {
      resp = await http.post(
        Uri.parse(ApiConfig.baseUrl + ApiConfig.checkinAction),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } on SocketException {
      throw CheckinFeatureUnavailableException('每日簽到功能尚未開放');
    }

    _throwIfError(resp, unavailableMessage: '每日簽到功能尚未開放');

    return CheckinStatus.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// 非 200 時分流拋出：body 能解析出 error.code → [CheckinApiException]（真正的業務錯誤）；
  /// 否則（純文字/HTML，代表路由還不存在）→ [CheckinFeatureUnavailableException]。
  static void _throwIfError(
    http.Response resp, {
    required String unavailableMessage,
  }) {
    if (resp.statusCode == 200) return;
    final apiError = _tryParseApiError(resp.body);
    if (apiError != null) throw apiError;
    throw CheckinFeatureUnavailableException(unavailableMessage);
  }

  static CheckinApiException? _tryParseApiError(String body) {
    try {
      final j = jsonDecode(body);
      final error = j['error'] as Map<String, dynamic>?;
      final code = error?['code'] as String?;
      if (code == null) return null;
      return CheckinApiException(code, error?['message'] as String? ?? '請求失敗');
    } catch (_) {
      return null;
    }
  }
}

/// 呼叫尚未存在的每日簽到端點（404）或連線失敗時拋出，
/// 讓呼叫端可以辨識並顯示「功能尚未開放」而非一般錯誤訊息。
class CheckinFeatureUnavailableException implements Exception {
  final String message;
  CheckinFeatureUnavailableException(this.message);
  @override
  String toString() => message;
}

/// 後端路由已存在、回傳正式 {error:{code,message}} 格式的業務錯誤時拋出
/// （見 每日簽到.md：ALREADY_CHECKED_IN），呼叫端可依 [code] 判斷後續行為。
class CheckinApiException implements Exception {
  final String code;
  final String message;
  CheckinApiException(this.code, this.message);
  @override
  String toString() => message;
}
