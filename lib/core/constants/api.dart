/// Backend API 設定
class ApiConfig {
  static const String baseUrl =
      'https://truku-api-230831538559.asia-east1.run.app';

  // 端點（與 backend/routes 對應）
  static const String authLogin = '/api/auth/login';
  static const String me = '/api/me';
  static const String meAvatar = '/api/me/avatar';
  static const String completeProfile = '/api/me/complete-profile';
  static const String logoutAll = '/api/auth/logout-all';

  static const String levels = '/api/levels';
  static const String quizStart = '/api/quiz/start';
  static const String quizAnswer = '/api/quiz/answer';
  static const String quizSubmit = '/api/quiz/submit';

  // 分級測驗（見 Truku_backend docs/superpowers/specs/2026-08-17-quiz-listening-placement-design.md）
  static const String quizPlacementStart = '/api/quiz/placement/start';
  static const String quizPlacementAnswer = '/api/quiz/placement/answer';
  static const String quizPlacementSubmit = '/api/quiz/placement/submit';

  static const String listeningStart = '/api/listening/start';
  static const String listeningAnswer = '/api/listening/answer';
  static const String listeningSubmit = '/api/listening/submit';

  static const String listeningPlacementStart = '/api/listening/placement/start';
  static const String listeningPlacementAnswer = '/api/listening/placement/answer';
  static const String listeningPlacementSubmit = '/api/listening/placement/submit';

  static const String historyList = '/api/history';

  // 回報答案錯誤（issue #20）
  static const String historyReport = '/api/history/report';

  // 小米幣明細（issue #25）
  static const String milletTransactions = '/api/millet/transactions';

  static const String health = '/api/health';

  static const String articles = '/api/articles';
  static String articleDetail(int id) => '/api/articles/$id';
  static String articleLike(int id) => '/api/articles/$id/like';
  static String articleBookmark(int id) => '/api/articles/$id/bookmark';
  static const String articleBookmarks = '/api/articles/bookmarks';
  static const String articleLikes = '/api/articles/likes';
  static const String articleSearch = '/api/articles/search';

  // 頭像商店（issue #12，頭像／頭像框合併目錄，見 頭像商店.md v2.0）
  static const String shopItems = '/api/shop/items';
  static String itemPurchaseEndpoint(String itemId) =>
      '/api/shop/items/$itemId/purchase';

  static const String videos = '/api/videos';
  static String videoDetail(int id) => '/api/videos/$id';
  static String videoLike(int id) => '/api/videos/$id/like';
  static String videoBookmark(int id) => '/api/videos/$id/bookmark';
  static const String videoBookmarks = '/api/videos/bookmarks';
  static const String videoLikes = '/api/videos/likes';
  static const String videoSearch = '/api/videos/search';

  // 活動 + 提醒 + 裝置推播（見 Truku_backend backend/routes/events.ts）
  static const String events = '/api/events';
  static const String eventsMine = '/api/events/mine';
  static String eventDetail(int id) => '/api/events/$id';
  static String eventJoin(int id) => '/api/events/$id/join';
  static String eventCancel(int id) => '/api/events/$id/cancel';
  static String eventReminders(int id) => '/api/events/$id/reminders';
  static String reminderDetail(int id) => '/api/reminders/$id';
  static String eventLike(int id) => '/api/events/$id/like';
  static String eventBookmark(int id) => '/api/events/$id/bookmark';
  static const String eventLikes = '/api/events/likes';
  static const String eventBookmarks = '/api/events/bookmarks';
  static const String eventSearch = '/api/events/search';
  static const String devices = '/api/devices';

  // 每日簽到（issue #24，見 每日簽到.md）
  static const String checkinStatus = '/api/checkin/status';
  static const String checkinAction = '/api/checkin';

  // 論壇 v2（見 Truku_backend backend/routes/forum.ts）
  static const String forumBoards = '/api/forum/boards';
  static String forumBoardPosts(String slug) => '/api/forum/boards/$slug/posts';
  static const String forumPosts = '/api/forum/posts';
  static String forumPost(int id) => '/api/forum/posts/$id';
  static String forumPostComments(int id) => '/api/forum/posts/$id/comments';
  static String forumComment(int id) => '/api/forum/comments/$id';
  static String forumPostLike(int id) => '/api/forum/posts/$id/like';
  static String forumCommentLike(int id) => '/api/forum/comments/$id/like';
  static const String forumSearch = '/api/forum/search';
  static const String forumTags = '/api/forum/tags';
  static const String forumReports = '/api/forum/reports';
  static const String forumNotifications = '/api/forum/notifications';
  static const String forumNotificationsRead = '/api/forum/notifications/read';
  // 書籤端點由後端另行補上，前端依規格 §9 的約定先行實作。
  static String forumPostBookmark(int id) => '/api/forum/posts/$id/bookmark';
  static const String forumBookmarks = '/api/forum/bookmarks';
  static const String forumPostLikes = '/api/forum/posts/likes';
  static const String forumCommentLikes = '/api/forum/comments/likes';

  // 族群/部落（issue #5）
  static const String ethnicGroups = '/api/ethnic-groups';
  static const String tribes = '/api/tribes';

  // 同意條款（見 Truku_backend backend/routes/terms.ts）
  static const String terms = '/api/terms';
  static const String termsConsent = '/api/terms/consent';
}
