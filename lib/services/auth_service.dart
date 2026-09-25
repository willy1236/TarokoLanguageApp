// 認證流程：
//   Google Sign-In／Apple 登入（僅 iOS）→ 拿 Firebase ID Token → POST /api/auth/login 換系統 JWT
//   系統 JWT 存在 flutter_secure_storage，給之後 API 呼叫帶 Authorization header
//
// 規格書對應：API設計/資料交換表_核心.md §2.1 POST /api/auth/login

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'session_token';
  static const _expiresKey = 'session_expires_at';

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static Future<void>? _googleSignInInit;

  static Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInit ??= _googleSignIn.initialize();
  }

  /// 走 Google 登入完整流程，成功回 [LoginResult]（刪除中帳號也算登入成功，
  /// 由呼叫端依 [LoginResult.isPendingDeletion] 分流）。失敗 throw [AuthException]。
  static Future<LoginResult> signInWithGoogle() async {
    // Web：google_sign_in 7 不支援 authenticate()，改由 Firebase 直接開 Google 彈窗。
    if (kIsWeb) {
      final UserCredential userCred;
      try {
        userCred = await _auth.signInWithPopup(GoogleAuthProvider());
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request') {
          throw AuthException('使用者取消登入');
        }
        throw AuthException('Google 登入失敗：${e.message ?? e.code}');
      }
      return _loginWithFirebaseUser(userCred.user);
    }

    await _ensureGoogleSignInInitialized();

    // 1. Google Sign-In SDK 拿 GoogleSignInAccount + idToken
    final GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw AuthException('使用者取消登入');
      }
      throw AuthException('Google 登入失敗：${e.description ?? e.code}');
    }
    return _exchangeAndStore(googleUser);
  }

  /// 走 Apple 登入（目前僅 iOS 原生），流程與回傳同 [signInWithGoogle]。
  /// Firebase 直接叫出系統的 Apple 登入面板，不需另外的套件。
  static Future<LoginResult> signInWithApple() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    final UserCredential userCred;
    try {
      userCred = await _auth.signInWithProvider(provider);
    } on FirebaseAuthException catch (e) {
      // 使用者關掉面板：iOS 回 ASAuthorizationError 1001，code 依版本不同。
      if (e.code == 'canceled' ||
          e.code == 'web-context-canceled' ||
          (e.message?.contains('1001') ?? false)) {
        throw AuthException('使用者取消登入');
      }
      throw AuthException('Apple 登入失敗：${e.message ?? e.code}');
    }
    return _loginWithFirebaseUser(userCred.user);
  }

  /// 靜默登入：重用裝置上先前已授權過本 app 的 Google 帳號，不叫出任何 UI。
  /// 成功回 [LoginResult]；無可用帳號或失敗回 `null`（不 throw），由呼叫端決定備援。
  /// 供整合測試自動登入使用；正式流程仍走 [signInWithGoogle]。
  static Future<LoginResult?> signInSilently() async {
    if (kIsWeb) return null;
    try {
      await _ensureGoogleSignInInitialized();
      final account = await _googleSignIn.attemptLightweightAuthentication();
      if (account == null) return null;
      return await _exchangeAndStore(account);
    } catch (e) {
      debugPrint('AuthService.signInSilently failed: $e');
      return null;
    }
  }

  /// 用 [GoogleSignInAccount] 換 Firebase user，再打後端換系統 JWT 並存入 storage。
  static Future<LoginResult> _exchangeAndStore(
    GoogleSignInAccount googleUser,
  ) async {
    final googleAuth = googleUser.authentication;

    // 用 Google credential 換 Firebase user
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    final userCred = await _auth.signInWithCredential(credential);
    return _loginWithFirebaseUser(userCred.user);
  }

  /// 拿 Firebase ID token 打後端換系統 JWT 並存入 storage。
  static Future<LoginResult> _loginWithFirebaseUser(User? user) async {
    final firebaseToken = await user?.getIdToken();
    if (firebaseToken == null) {
      throw AuthException('取得 Firebase token 失敗');
    }

    // 打後端換系統 JWT。這裡不走 ApiClient：登入端點沒有 JWT 可帶，而
    // ApiClient 的 401 會觸發強制登出導頁，對登入失敗是錯誤的反應。
    // 但離線處理要與 ApiClient 一致，不能讓 SocketException 直接逸出
    // （Web 沒有 socket，離線時丟的是 http.ClientException，只在 Web 攔截；
    // 手機上的 ClientException 維持原樣往外丟）。
    final http.Response resp;
    try {
      resp = await http.post(
        Uri.parse(ApiConfig.baseUrl + ApiConfig.authLogin),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'firebase_token': firebaseToken}),
      );
    } on SocketException {
      throw AuthException('無法連線到伺服器，請檢查網路');
    } on http.ClientException {
      if (!kIsWeb) rethrow;
      throw AuthException('無法連線到伺服器，請檢查網路');
    }

    if (resp.statusCode != 200) {
      final err = _parseError(resp.body);
      throw AuthException(err);
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    // 刪除中帳號也會拿到 token：重新啟用端點要用它呼叫（見帳號刪除串接指南 §4）。
    await _storage.write(key: _tokenKey, value: data['session_token']);
    await _storage.write(key: _expiresKey, value: data['expires_at']);
    return LoginResult.fromJson(data);
  }

  /// 刪除帳號前的 Apple 重新驗證：Apple 規定刪帳號要撤銷 Sign in with Apple
  /// 授權，撤銷需要一次性、數分鐘內過期的 authorization code，只能當場
  /// 叫面板重新取得。非 Apple 登入回 `null`；使用者取消 throw [AuthException]。
  static Future<String?> reauthenticateAppleForRevocation() async {
    final user = _auth.currentUser;
    final isApple =
        user?.providerData.any((p) => p.providerId == 'apple.com') ?? false;
    if (user == null || !isApple) return null;
    try {
      final cred = await user.reauthenticateWithProvider(AppleAuthProvider());
      return cred.additionalUserInfo?.authorizationCode;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'canceled' ||
          e.code == 'web-context-canceled' ||
          (e.message?.contains('1001') ?? false)) {
        throw AuthException('需要重新驗證 Apple 帳號才能刪除');
      }
      throw AuthException('Apple 驗證失敗：${e.message ?? e.code}');
    }
  }

  /// 帳號刪除成功後撤銷第三方登入授權：Apple 用 [appleAuthorizationCode]
  /// 經 Firebase 撤銷，Google 用 disconnect。刪除已完成，撤銷失敗不 throw。
  /// 須在 [signOut] 之前呼叫，否則 Google 已無登入中的帳號可 disconnect。
  static Future<void> revokeProviderAuthorization({
    String? appleAuthorizationCode,
  }) async {
    if (appleAuthorizationCode != null) {
      try {
        await _auth.revokeTokenWithAuthorizationCode(appleAuthorizationCode);
      } catch (e) {
        debugPrint('AuthService: 撤銷 Apple 授權失敗：$e');
      }
    }
    final isGoogle =
        _auth.currentUser?.providerData.any(
          (p) => p.providerId == 'google.com',
        ) ??
        false;
    if (isGoogle && !kIsWeb) {
      try {
        await _ensureGoogleSignInInitialized();
        await _googleSignIn.disconnect();
      } catch (e) {
        debugPrint('AuthService: 撤銷 Google 授權失敗：$e');
      }
    }
  }

  /// 完全登出（Firebase + Google + 清本機 token；不撤銷後端 JWT）
  static Future<void> signOut() async {
    // Web 沒走 google_sign_in（未 initialize），只需登出 Firebase。
    if (!kIsWeb) await _googleSignIn.signOut();
    await _auth.signOut();
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresKey);
  }

  /// 撤銷所有裝置的 JWT（規格書 §2.2 POST /api/auth/logout-all）
  static Future<void> logoutAllDevices() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return;
    // 通知後端撤銷失敗（離線、token 已失效）不該擋住本機登出——否則使用者
    // 卡在已登入狀態且沒有退路。
    try {
      await http.post(
        Uri.parse(ApiConfig.baseUrl + ApiConfig.logoutAll),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      debugPrint('AuthService.logoutAllDevices: 通知後端失敗（仍繼續登出）：$e');
    }
    await signOut();
  }

  static Future<String?> currentToken() => _storage.read(key: _tokenKey);

  /// 系統 JWT 自然過期時，用仍登入中的 Firebase user 重新換一張（後端沒有
  /// refresh 端點，登入端點就是換 token 的唯一途徑）。成功回 true；沒有
  /// Firebase user 或換 token 失敗回 false，不 throw，由呼叫端決定備援。
  static Future<bool> refreshSession() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await _loginWithFirebaseUser(user);
      return true;
    } catch (e) {
      debugPrint('AuthService.refreshSession failed: $e');
      return false;
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return false;
    final expiresAt = await _storage.read(key: _expiresKey);
    if (expiresAt == null) return true;
    final expiry = DateTime.tryParse(expiresAt);
    if (expiry == null) return true;
    if (DateTime.now().isAfter(expiry)) {
      await signOut();
      return false;
    }
    return true;
  }

  static String _parseError(String body) {
    try {
      final j = jsonDecode(body);
      return j['error']?['message'] ?? '登入失敗';
    } catch (e) {
      // 回應內容可能含 token/個資，release build 不印。
      if (kDebugMode) {
        debugPrint('AuthService._parseError 解析失敗 ($e): $body');
      }
      return '登入失敗';
    }
  }
}

/// `POST /api/auth/login` 的回應。active 帳號帶 `user`；非 active 帳號
/// （刪除中／鎖定）改帶 `account_state`、`purge_at`，沒有 `user`。
class LoginResult {
  /// `active`／`pending_deletion`／`locked`。active 帳號的回應沒有此欄位。
  final String accountState;
  final DateTime? purgeAt;
  final Map<String, dynamic>? user;

  const LoginResult({required this.accountState, this.purgeAt, this.user});

  bool get isActive => accountState == 'active';
  bool get isPendingDeletion => accountState == 'pending_deletion';

  /// 鎖定（唯讀）帳號：照常進 App，但回應沒有 `user`，個資要另打 /me。
  bool get isLocked => accountState == 'locked';

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
    accountState: json['account_state'] as String? ?? 'active',
    purgeAt: DateTime.tryParse(json['purge_at'] as String? ?? '')?.toLocal(),
    user: json['user'] as Map<String, dynamic>?,
  );
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
