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
  static const String quizSubmit = '/api/quiz/submit';

  static const String listeningStart = '/api/listening/start';
  static const String listeningSubmit = '/api/listening/submit';

  static const String health = '/api/health';

  // 頭像商店（issue #12，頭像／頭像框合併目錄，見 頭像商店.md v2.0）
  static const String meEndpoint = me;
  static const String shopItems = '/api/shop/items';
  static String itemPurchaseEndpoint(String itemId) =>
      '/api/shop/items/$itemId/purchase';
}
