// 同意條款（服務條款/隱私權政策）service。
// 對應 Truku_backend backend/routes/terms.ts。

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/terms_models.dart';

class TermsService {
  /// 查目前最新條款內容 + 我的同意狀態。
  static Future<TermsStatus> fetchStatus() async {
    final json = await ApiClient.get(ApiConfig.terms);
    return TermsStatus.fromJson(json);
  }

  /// 同意目前存在的每一種 doc_type 的最新版本。
  static Future<TermsStatus> consent() async {
    final json = await ApiClient.post(ApiConfig.termsConsent);
    return TermsStatus.fromJson(json);
  }
}
