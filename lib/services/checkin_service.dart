// 每日簽到 API 呼叫（issue #24、#32 遷移至共用 ApiClient）
//
// 端點（見 Truku_backend 說明文件/API/每日簽到.md）：
//   - GET /api/checkin/status：簽到按鈕初始狀態
//   - POST /api/checkin：執行簽到，成功 millet +50；重複呼叫回 409 ALREADY_CHECKED_IN
//
// 兩支端點回應是簽到相關的少數欄位（checked_in_today／checkin_streak／millet／
// weekly_checkin_count／週獎勵旗標），不是完整 user 物件，因此不直接餵給
// UserModel.fromJson（會缺 uid/email/created_at 而炸掉），改回傳 [CheckinStatus]，
// 由呼叫端用 UserModel.copyWith 合併回現有使用者資料。
//
// 統一走共用 ApiClient：業務錯誤（如 409 ALREADY_CHECKED_IN）以 [ApiException]
// 表示，呼叫端可依 [ApiException.code] 判斷後續行為。

import '../core/constants/api.dart';
import '../core/network/api_client.dart';

/// 簽到狀態，對應 checkin/status、checkin 端點的回應。
class CheckinStatus {
  final bool checkedInToday;
  final int checkinStreak;
  final int millet;

  /// 本週已簽到天數（0–7，週一起算）。後端已處理跨週歸零。
  final int weeklyCheckinCount;

  /// 本週是否已集滿 7 天並拿到 +50 週全勤獎。
  final bool weeklyBonusEarned;

  const CheckinStatus({
    required this.checkedInToday,
    required this.checkinStreak,
    required this.millet,
    this.weeklyCheckinCount = 0,
    this.weeklyBonusEarned = false,
  });

  factory CheckinStatus.fromJson(Map<String, dynamic> json) {
    return CheckinStatus(
      checkedInToday: json['checked_in_today'] as bool? ?? false,
      checkinStreak: json['checkin_streak'] as int? ?? 0,
      millet: json['millet'] as int? ?? 0,
      weeklyCheckinCount: json['weekly_checkin_count'] as int? ?? 0,
      // 命名不對稱：status 回 weekly_bonus_earned、checkin 回 weekly_bonus_awarded。
      weeklyBonusEarned:
          json['weekly_bonus_earned'] as bool? ??
          json['weekly_bonus_awarded'] as bool? ??
          false,
    );
  }
}

class CheckinService {
  /// 呼叫 GET /api/checkin/status，取得簽到按鈕初始狀態。
  static Future<CheckinStatus> fetchStatus() async {
    final json = await ApiClient.get(ApiConfig.checkinStatus);
    return CheckinStatus.fromJson(json);
  }

  /// 呼叫 POST /api/checkin，執行簽到。
  static Future<CheckinStatus> checkin() async {
    final json = await ApiClient.post(ApiConfig.checkinAction);
    return CheckinStatus.fromJson(json);
  }
}
