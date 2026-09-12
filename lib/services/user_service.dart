import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';
import '../models/tribe_model.dart';

class UserService {
  /// 目前登入者的 uid，登入後由 [fetchMe] 快取，供各處（如活動 isHost/isJoined
  /// 判斷）免再打一次 /api/me。登出時應呼叫 [clearCache] 清除。
  static int? currentUid;

  /// 目前登入者的完整資料快取，由 [fetchMe] 與各個會回傳完整 user 的寫入 API
  /// 更新。非即時（不會隨後端變動自動更新）；需要保證最新值時傳 forceRefresh: true。
  static UserModel? get cachedUser => userNotifier.value;

  /// [cachedUser] 的可監聽版本：任何寫入（改資料、換頭像、購買、登出）都會通知，
  /// 讓只在啟動時抓過一次資料的畫面（如首頁頂部）能同步刷新。
  static final ValueNotifier<UserModel?> userNotifier = ValueNotifier(null);

  /// session 世代：每次 [clearCache]（登出）遞增。使用者在 fetchMe() 進行中
  /// 登出時，晚 resolve 的舊回應不能把前一個帳號寫回快取——否則下一位登入者
  /// 會在論壇/活動頁看到錯誤的「這是我的貼文／我是主辦人」判斷。
  static int _sessionGen = 0;

  static Future<UserModel> fetchMe({bool forceRefresh = false}) async {
    if (!forceRefresh && cachedUser != null) return cachedUser!;
    final gen = _sessionGen;
    final data = await ApiClient.get(ApiConfig.me);
    final user = UserModel.fromJson(data);
    // 回應期間已登出：把結果回傳給呼叫端，但不污染快取。
    if (gen != _sessionGen) return user;
    _setCached(user);
    return user;
  }

  static void clearCache() {
    _sessionGen++;
    _setCached(null);
  }

  /// 給其他 service（商店購買／配戴、簽到）把回傳的最新 user 寫回快取。
  /// 只接受目前登入者的資料：請求進行中登出或換帳號時，晚到的舊回應直接丟掉。
  static void cacheUser(UserModel user) {
    if (currentUid == null || user.uid != currentUid) return;
    _setCached(user);
  }

  static void _setCached(UserModel? user) {
    currentUid = user?.uid;
    userNotifier.value = user;
  }

  static Future<UserModel> updateMe({
    String? displayName,
    String? ethnicGroup,
    int? tribeId,
    bool clearTribeId = false,
    String? videoNickname,
    bool? isIndigenous,
    String? tribalName,
    String? selfIntro,
  }) async {
    final body = <String, dynamic>{
      'display_name': ?displayName,
      'ethnic_group': ?ethnicGroup,
      if (clearTribeId) 'tribe_id': null else 'tribe_id': ?tribeId,
      'video_nickname': ?videoNickname,
      'is_indigenous': ?isIndigenous,
      'tribal_name': ?tribalName,
      'self_intro': ?selfIntro,
    };
    final gen = _sessionGen;
    final data = await ApiClient.patch(ApiConfig.me, body);
    final user = UserModel.fromJson(data);
    if (gen == _sessionGen) _setCached(user);
    return user;
  }

  /// 上傳自訂頭像（multipart，欄位名固定 avatar）。後端會自動裁正方形、轉 WebP
  /// 並清空 avatar_id；回傳完整 user 物件，不需再呼叫一次 fetchMe()。
  static Future<UserModel> uploadAvatar(File file, {String? contentType}) async {
    final gen = _sessionGen;
    final data = await ApiClient.postMultipartFile(
      ApiConfig.meAvatar,
      fieldName: 'avatar',
      file: file,
      contentType: contentType,
    );
    final user = UserModel.fromJson(data);
    if (gen == _sessionGen) _setCached(user);
    return user;
  }

  /// [uploadAvatar] 的 Web 版：Web 沒有本機檔案可讀，改傳 bytes。
  static Future<UserModel> uploadAvatarBytes(
    List<int> bytes, {
    required String filename,
    String? contentType,
  }) async {
    final gen = _sessionGen;
    final data = await ApiClient.postMultipartBytes(
      ApiConfig.meAvatar,
      fieldName: 'avatar',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
    final user = UserModel.fromJson(data);
    if (gen == _sessionGen) _setCached(user);
    return user;
  }

  /// 首次登入完善資料（issue #43），成功後 profile_completed 轉為 true。
  static Future<UserModel> completeProfile({
    required String displayName,
    required bool isIndigenous,
    required String videoNickname,
    String? ethnicGroup,
    int? tribeId,
    String? tribalName,
    String? selfIntro,
  }) async {
    final body = <String, dynamic>{
      'display_name': displayName,
      'is_indigenous': isIndigenous,
      'video_nickname': videoNickname,
      'ethnic_group': ?ethnicGroup,
      'tribe_id': ?tribeId,
      'tribal_name': ?tribalName,
      'self_intro': ?selfIntro,
    };
    final gen = _sessionGen;
    final data = await ApiClient.post(ApiConfig.completeProfile, body);
    final user = UserModel.fromJson(data);
    if (gen == _sessionGen) _setCached(user);
    return user;
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
