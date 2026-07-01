import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

class UserService {
  static Future<UserModel> fetchMe() async {
    final data = await ApiClient.get(ApiConfig.me);
    return UserModel.fromJson(data);
  }
}
