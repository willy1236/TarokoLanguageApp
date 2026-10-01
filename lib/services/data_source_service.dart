// 資料來源與授權 service。
// 對應 Truku_backend GET /api/data-sources；端點不需登入，ApiClient 有 token
// 就帶，後端會忽略，所以不另開不帶 token 的路徑。

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/data_source_models.dart';

class DataSourceService {
  /// 每次呼叫都重打：http 套件不做快取，回應量很小，不另做快取。
  static Future<DataSources> fetch() async {
    final json = await ApiClient.get(ApiConfig.dataSources);
    return DataSources.fromJson(json);
  }
}
