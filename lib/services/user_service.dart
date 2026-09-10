import 'dart:io';

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
    String? videoNickname,
    bool? isIndigenous,
    String? tribalName,
  }) async {
    final body = <String, dynamic>{
      'display_name': ?displayName,
      'ethnic_group': ?ethnicGroup,
      if (clearTribeId) 'tribe_id': null else 'tribe_id': ?tribeId,
      'video_nickname': ?videoNickname,
      'is_indigenous': ?isIndigenous,
      'tribal_name': ?tribalName,
    };
    final data = await ApiClient.patch(ApiConfig.me, body);
    return UserModel.fromJson(data);
  }

  /// 上傳自訂頭像（multipart，欄位名固定 avatar）。後端會自動裁正方形、轉 WebP
  /// 並清空 avatar_id；回傳完整 user 物件，不需再呼叫一次 fetchMe()。
  static Future<UserModel> uploadAvatar(File file, {String? contentType}) async {
    final data = await ApiClient.postMultipartFile(
      ApiConfig.meAvatar,
      fieldName: 'avatar',
      file: file,
      contentType: contentType,
    );
    return UserModel.fromJson(data);
  }

  /// 首次登入完善資料（issue #43），成功後 profile_completed 轉為 true。
  static Future<UserModel> completeProfile({
    required String displayName,
    required bool isIndigenous,
    String? ethnicGroup,
    int? tribeId,
    String? tribalName,
  }) async {
    final body = <String, dynamic>{
      'display_name': displayName,
      'is_indigenous': isIndigenous,
      'ethnic_group': ?ethnicGroup,
      'tribe_id': ?tribeId,
      'tribal_name': ?tribalName,
    };
    final data = await ApiClient.post(ApiConfig.completeProfile, body);
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
