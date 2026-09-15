// 帳號刪除／重新啟用／狀態查詢／資料匯出。
// 規格：Truku_backend 說明文件/前端交接/帳號刪除串接指南.md、backend/routes/account.ts
//
// 這些端點受每 IP 每分鐘 5 次限流，呼叫端不可自動重試。

import '../core/constants/api.dart';
import '../core/network/api_client.dart';

/// `GET /api/account/status` 與刪除／重新啟用回應共用的帳號狀態。
class AccountStatus {
  /// `active`／`pending_deletion`／`deleted`／`locked`。
  final String status;

  /// 永久刪除時間；active 帳號為 null。
  final DateTime? purgeAt;

  const AccountStatus({required this.status, this.purgeAt});

  bool get isPendingDeletion => status == 'pending_deletion';

  factory AccountStatus.fromJson(Map<String, dynamic> json) => AccountStatus(
    status: json['status'] as String? ?? 'active',
    purgeAt: DateTime.tryParse(json['purge_at'] as String? ?? '')?.toLocal(),
  );
}

class AccountService {
  /// 申請刪除帳號，進入 45 天緩衝。成功後此 token 立即失效，呼叫端須登出。
  static Future<AccountStatus> deleteAccount({String? reason}) async {
    final trimmed = reason?.trim();
    final data = await ApiClient.delete(ApiConfig.account, {
      'confirm': true,
      if (trimmed != null && trimmed.isNotEmpty) 'reason': trimmed,
    });
    return AccountStatus.fromJson(data);
  }

  /// 刪除緩衝期內重新啟用帳號（後端會一併補同意最新版條款）。
  static Future<AccountStatus> reactivate() async {
    final data = await ApiClient.post(ApiConfig.accountReactivate, {
      'confirm': true,
    });
    return AccountStatus.fromJson(data);
  }

  static Future<AccountStatus> fetchStatus() async {
    final data = await ApiClient.get(ApiConfig.accountStatus);
    return AccountStatus.fromJson(data);
  }

  /// 匯出本人所有資料，回傳 JSON 原文（直接存檔，不在 App 內解析）。
  static Future<String> exportData() => ApiClient.getRaw(ApiConfig.accountExport);
}

/// 距離 [purgeAt] 還剩幾天（無條件進位，最少 0）。
int daysUntilPurge(DateTime purgeAt, {DateTime? now}) {
  final diff = purgeAt.difference(now ?? DateTime.now());
  if (diff.isNegative) return 0;
  return (diff.inMinutes / (60 * 24)).ceil();
}
