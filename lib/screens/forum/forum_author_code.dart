import '../../models/forum_models.dart';
import '../../services/user_service.dart';

extension ForumAuthorCode on ForumAuthor {
  /// 暱稱旁要附的好友碼；自己的貼文、留言不附。
  String? get othersFriendCode =>
      UserService.isMe(friendCode) ? null : friendCode;
}
