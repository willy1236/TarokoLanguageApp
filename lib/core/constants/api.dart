/// Backend API 設定
class ApiConfig {
  static const String baseUrl =
      'https://truku-api-230831538559.asia-east1.run.app';

  // 端點（與 backend/routes 對應）
  static const String authLogin = '/api/auth/login';
  static const String me = '/api/me';
  static const String logoutAll = '/api/auth/logout-all';

  static const String levels = '/api/levels';
  static const String quizStart = '/api/quiz/start';
  static const String quizAnswer = '/api/quiz/answer';
  static const String quizSubmit = '/api/quiz/submit';

  static const String listeningStart = '/api/listening/start';
  static const String listeningSubmit = '/api/listening/submit';

  static const String historyList = '/api/history';

  // 小米幣明細（issue #25）
  static const String milletTransactions = '/api/millet/transactions';

  static const String health = '/api/health';

  static const String articles = '/api/articles';
  static String articleDetail(int id) => '/api/articles/$id';

  // 頭像商店（issue #12，頭像／頭像框合併目錄，見 頭像商店.md v2.0）
  static const String meEndpoint = me;
  static const String shopItems = '/api/shop/items';
  static String itemPurchaseEndpoint(String itemId) =>
      '/api/shop/items/$itemId/purchase';

  static const String videos = '/api/videos';
  static String videoDetail(int id) => '/api/videos/$id';

  // 活動 + 提醒 + 裝置推播（見 Truku_backend backend/routes/events.ts）
  static const String events = '/api/events';
  static const String eventsMine = '/api/events/mine';
  static String eventDetail(int id) => '/api/events/$id';
  static String eventJoin(int id) => '/api/events/$id/join';
  static String eventCancel(int id) => '/api/events/$id/cancel';
  static String eventReminders(int id) => '/api/events/$id/reminders';
  static String reminderDetail(int id) => '/api/reminders/$id';
  static const String devices = '/api/devices';

  // 每日簽到（issue #24，見 每日簽到.md）
  static const String checkinStatus = '/api/checkin/status';
  static const String checkinAction = '/api/checkin';
}
