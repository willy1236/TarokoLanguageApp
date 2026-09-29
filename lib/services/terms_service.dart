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

  /// 只查單份條款。該類型尚未發布時後端回 404 TERMS_NOT_FOUND。
  static Future<TermsDocumentStatus> fetchDocument(String docType) async {
    final json = await ApiClient.get(ApiConfig.termsDoc(docType));
    return TermsDocumentStatus.fromJson(json);
  }

  /// 只同意 [doc]（使用者畫面上看到的版本）。後端若已發布更新版本，
  /// 丟 409 TERMS_VERSION_OUTDATED，`body` 附合併版形狀的最新狀態，可用 [TermsStatus.fromJson] 重新顯示。
  static Future<TermsDocumentStatus> consentDocument(TermsDocument doc) async {
    final json = await ApiClient.post(ApiConfig.termsDocConsent(doc.docType), {
      'version': doc.version,
    });
    return TermsDocumentStatus.fromJson(json);
  }
}
