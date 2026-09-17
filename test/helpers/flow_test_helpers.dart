// 跨畫面（導航流程）測試的共用樣板。
//
// 既有 test/widgets/ 的做法是把單一畫面直接掛成 `home:`，所以路由行為
// （列表→詳情→返回、啟動導流、橫幅跨路由）完全測不到。這裡提供一個
// 「等價於 lib/main.dart 的 App 殼」，但避開 main() 裡的 Firebase / FCM 原生依賴。
//
// HTTP 假回應、channel stub 等仍然沿用 widget_test_helpers.dart，不要在這裡重寫。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart'
    show navigatorKey, scaffoldMessengerKey, MainContainer;
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/screens/account/account_pending_screen.dart';
import 'package:flutter_application_1/screens/auth/complete_profile_screen.dart';
import 'package:flutter_application_1/screens/auth/login_screen.dart';
import 'package:flutter_application_1/screens/backpack/backpack_screen.dart';
import 'package:flutter_application_1/screens/shop/shop_screen.dart';
import 'package:flutter_application_1/screens/splash/splash_screen.dart';
import 'package:flutter_application_1/screens/terms/terms_consent_screen.dart';
import 'package:flutter_application_1/services/account_lock_controller.dart';
import 'package:flutter_application_1/services/notification_summary_service.dart';
import 'package:flutter_application_1/services/user_service.dart';

/// 唯讀橫幅的文字。與 main.dart 的 _ReadOnlyBannerFrame 同一份字串。
const String readOnlyBannerText = '帳號目前為唯讀狀態';

/// 組一個等價於 `KariTrukuApp` 的測試用 App。
///
/// 與 lib/main.dart 的差異（都是刻意的）：
///   - 不呼叫 main()，所以沒有 Firebase.initializeApp / FcmService.init
///   - 不掛 GoogleFonts textTheme，避免測試期間去抓字型
///   - [overrides] 可以把任一具名路由換成假畫面，測導流時不必真的 render 目的頁
///
/// navigatorKey / scaffoldMessengerKey 用的是 main.dart 的同一把全域 key，
/// 因為 showReadOnlyToast() 直接透過它送 SnackBar（account_lock_controller.dart:36）。
Widget buildTestApp({
  String initialRoute = '/splash',
  Map<String, WidgetBuilder> overrides = const {},
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    scaffoldMessengerKey: scaffoldMessengerKey,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.surfaceVariant,
        surface: AppColors.surface,
      ),
    ),
    builder: (context, child) => TestReadOnlyBannerFrame(child: child!),
    initialRoute: initialRoute,
    routes: {
      '/splash': (_) => const SplashScreen(),
      '/login': (_) => const LoginScreen(),
      '/complete-profile': (_) => const CompleteProfileScreen(),
      '/terms-consent': (_) => const TermsConsentScreen(),
      '/account-pending': (context) => AccountPendingScreen(
            purgeAt: ModalRoute.of(context)?.settings.arguments as DateTime?,
          ),
      '/home': (_) => const MainContainer(),
      '/shop': (_) => const ShopScreen(),
      '/backpack': (_) => const BackpackScreen(),
      ...overrides,
    },
  );
}

/// main.dart:200-251 `_ReadOnlyBannerFrame` 的鏡像（原件是私有類別，測試 import 不到）。
///
/// 只保留測試會斷言的行為：未鎖定時原樣穿透、鎖定時在最上方加一條含
/// [readOnlyBannerText] 的橫幅。**改了 main.dart 那邊記得同步這裡。**
class TestReadOnlyBannerFrame extends StatelessWidget {
  final Widget child;

  const TestReadOnlyBannerFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: accountLockController,
      child: child,
      builder: (context, child) {
        if (!accountLockController.locked) return child!;
        return Column(
          children: [
            Material(
              color: AppColors.ink,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: AppColors.gold),
                    SizedBox(width: 8),
                    Expanded(child: Text(readOnlyBannerText)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child!,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 只驗「導到哪一頁」時用的假目的地。用 [label] 當斷言目標。
Widget fakeRoute(String label) => Scaffold(body: Center(child: Text(label)));

/// pumpAndSettle 在這個 App 會 timeout：清單尾端掛著永不停的
/// CircularProgressIndicator，frame 永遠不會靜止。改用固定次數的 pump。
Future<void> pumpFrames(
  WidgetTester tester, {
  int times = 5,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(step);
  }
}

/// 全域單例會跨測試汙染，setUp 與 tearDown 都要呼叫。
/// accountLockController 是沒有重設 API 的全域單例（account_lock_controller.dart:26）。
void resetGlobals() {
  accountLockController.setLocked(false);
  UserService.clearCache();
  NotificationSummaryService.clear();
}

/// 測試預設畫布是 800x600（橫的），App 是手機直式版面，直接用會 overflow。
/// 跨畫面測試常要同時 render 整個殼（含 IndexedStack 裡的所有分頁），
/// 一定要先換成手機尺寸。
///
/// 預設寬度 414 = iPhone 14/15 的邏輯寬度，是主流機型裡最窄的一個。
/// **不要為了讓測試變綠而把這個值調寬**：測試字型（Ahem）每個字都是方塊、比實際
/// 字型更寬，414 下不 overflow 是比實機嚴格的條件，反過來若這裡 overflow，代表
/// 版面在實機上很可能真的會出問題。歷史紀錄見 PR #73：當時為了避開 ModeCard 的
/// overflow 把預設調成 480，等於把唯一的自動化警報拆掉，該 bug 已在後續修正。
void usePhoneSurface(
  WidgetTester tester, {
  Size size = const Size(414, 1000),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
