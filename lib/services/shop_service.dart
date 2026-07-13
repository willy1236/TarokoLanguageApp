import '../core/network/api_client.dart';

class ShopService {
  static Future<int> fetchBalance() async {
    final json = await ApiClient.get('/api/shop/balance');
    return (json['millet'] as num).toInt();
  }

  static Future<int> exchange({
    required String productName,
    required int cost,
  }) async {
    final json = await ApiClient.post('/api/shop/exchange', {
      'product_name': productName,
      'cost': cost,
    });
    return (json['millet'] as num).toInt();
  }
}
