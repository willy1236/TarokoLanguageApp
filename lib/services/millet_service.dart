import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/millet_transaction.dart';

class MilletService {
  static Future<MilletTransactionListResult> fetchTransactions({
    int? before,
    int limit = 20,
  }) async {
    final beforeStr = before?.toString();
    final json = await ApiClient.get(
      ApiConfig.milletTransactions,
      query: {'before': ?beforeStr, 'limit': '$limit'},
    );
    return MilletTransactionListResult.fromJson(json);
  }
}
