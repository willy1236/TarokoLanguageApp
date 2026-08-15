import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

class UserService {
  /// 目前登入者的 uid，登入後由 [fetchMe] 快取，供各處（如活動 isHost/isJoined
  /// 判斷）免再打一次 /api/me。登出時應呼叫 [clearCache] 清除。
  static int? currentUid;

  static Future<UserModel> fetchMe() async {
    final data = await ApiClient.get(ApiConfig.me);
    final user = UserModel.fromJson(data);
    currentUid = user.uid;
    return user;
  }

  static void clearCache() => currentUid = null;

  static Future<UserModel> updateMe({required String displayName}) async {
    final data = await ApiClient.patch(ApiConfig.me, {
      'display_name': displayName,
    });
    return UserModel.fromJson(data);
  }
}
