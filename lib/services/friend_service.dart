// 好友/聊天/通話服務。Stage 2 先加公開個人檔案查詢，好友關係/封鎖/通話/聊天
// 端點在後續階段（Stage 3/5/6）陸續擴充於此檔案。

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/public_profile_model.dart';

class FriendService {
  static Future<PublicProfile> getPublicProfile(String friendCode) async {
    final data = await ApiClient.get(ApiConfig.publicProfile(friendCode));
    return PublicProfile.fromJson(data);
  }
}
