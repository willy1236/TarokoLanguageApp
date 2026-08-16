import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';
import '../models/tribe_model.dart';

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

  static Future<UserModel> updateMe({
    String? displayName,
    String? ethnicGroup,
    int? tribeId,
    bool clearTribeId = false,
  }) async {
    final body = <String, dynamic>{
      if (displayName != null) 'display_name': displayName,
      if (ethnicGroup != null) 'ethnic_group': ethnicGroup,
      if (clearTribeId)
        'tribe_id': null
      else if (tribeId != null)
        'tribe_id': tribeId,
    };
    final data = await ApiClient.patch(ApiConfig.me, body);
    return UserModel.fromJson(data);
  }

  static Future<List<EthnicGroup>> fetchEthnicGroups() async {
    final data = await ApiClient.get(ApiConfig.ethnicGroups);
    return ApiClient.unwrapList(
      data,
      'ethnic_groups',
    ).map((e) => EthnicGroup.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<Tribe>> fetchTribes({String? ethnicGroup}) async {
    final data = await ApiClient.get(
      ApiConfig.tribes,
      query: ethnicGroup == null ? null : {'ethnic_group': ethnicGroup},
    );
    return ApiClient.unwrapList(
      data,
      'tribes',
    ).map((e) => Tribe.fromJson(e as Map<String, dynamic>)).toList();
  }
}
