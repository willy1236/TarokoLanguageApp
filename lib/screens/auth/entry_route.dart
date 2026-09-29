// 登入後的起始路由，冷啟動、登入、同意條款、帳號重新啟用四處共用，
// 各處只負責查資料，先後順序集中在這裡。

import '../../models/user_model.dart';

/// 依序檢查：未完成基本資料 → 補填出生日期 → 未同意條款 → 首頁。
/// [user] 為 null 代表查不到（離線等），不擋既有使用者。
String entryRouteFor(UserModel? user, {required bool allConsented}) {
  if (user != null && !user.profileCompleted) return '/complete-profile';
  if (user != null && user.needsBirthDate) return '/birth-date';
  if (!allConsented) return '/terms-consent';
  return '/home';
}
