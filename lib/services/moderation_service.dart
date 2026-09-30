// 當事人查看處置詳情、提出申訴。
// 規格：Truku_backend 說明文件/API/收件匣與申訴.md §3。
//
// 這兩支只驗登入、不擋唯讀：被鎖帳號也能看自己為什麼被處置、提出申訴。

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/moderation_case_models.dart';

class ModerationService {
  /// 找不到（不是自己的案件、或私訊／通話案件還在待審）回 404 CASE_NOT_FOUND。
  static Future<MyModerationCase> fetchCase(int id) async {
    final data = await ApiClient.get(ApiConfig.myModerationCase(id));
    return MyModerationCase.fromJson(data);
  }

  /// 每案只能申訴一次。[reason] 去空白後 10～1000 字（長度由畫面先擋）。
  /// 已申訴過回 409 APPEAL_EXISTS，逾期或案件已撤銷回 409 APPEAL_CLOSED。
  static Future<MyAppeal> appeal(int id, String reason) async {
    final data = await ApiClient.post(ApiConfig.myModerationCaseAppeal(id), {
      'reason': reason.trim(),
    });
    return MyAppeal.fromJson(data['appeal'] as Map<String, dynamic>);
  }
}
