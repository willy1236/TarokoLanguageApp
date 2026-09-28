import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/millet_transaction.dart';
import '../models/page_info.dart';

class MilletService {
  static Future<MilletTransactionListResult> fetchTransactions({
    String? cursor,
    int limit = 20,
  }) async {
    final json = await ApiClient.get(
      ApiConfig.milletTransactions,
      query: PageInfo.query(cursor: cursor, limit: limit),
    );
    return MilletTransactionListResult.fromJson(json);
  }
}
