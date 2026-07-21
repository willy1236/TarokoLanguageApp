import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

class UserService {
  static Future<UserModel> fetchMe() async {
    final data = await ApiClient.get(ApiConfig.me);
    return UserModel.fromJson(data);
  }

  static Future<UserModel> updateMe({required String displayName}) async {
    final data = await ApiClient.patch(ApiConfig.me, {'display_name': displayName});
    return UserModel.fromJson(data);
  }
}
