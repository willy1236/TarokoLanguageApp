// 認證流程：
//   Google Sign-In → 拿 Firebase ID Token → POST /api/auth/login 換系統 JWT
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

  /// 走 Google 登入完整流程，成功回 user JSON。
  /// 失敗 throw [AuthException]。
  static Future<Map<String, dynamic>> signInWithGoogle() async {
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

  /// 靜默登入：重用裝置上先前已授權過本 app 的 Google 帳號，不叫出任何 UI。
  /// 成功回 user JSON；無可用帳號或失敗回 `null`（不 throw），由呼叫端決定備援。
  /// 供整合測試自動登入使用；正式流程仍走 [signInWithGoogle]。
  static Future<Map<String, dynamic>?> signInSilently() async {
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
  static Future<Map<String, dynamic>> _exchangeAndStore(
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
  static Future<Map<String, dynamic>> _loginWithFirebaseUser(User? user) async {
    final firebaseToken = await user?.getIdToken();
    if (firebaseToken == null) {
      throw AuthException('取得 Firebase token 失敗');
    }

    // 打後端換系統 JWT。這裡不走 ApiClient：登入端點沒有 JWT 可帶，而
    // ApiClient 的 401 會觸發強制登出導頁，對登入失敗是錯誤的反應。
    // 但離線處理要與 ApiClient 一致，不能讓 SocketException 直接逸出
    // （Web 沒有 socket，離線時丟的是 http.ClientException，一併攔截）。
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
      throw AuthException('無法連線到伺服器，請檢查網路');
    }

    if (resp.statusCode != 200) {
      final err = _parseError(resp.body);
      throw AuthException(err);
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    await _storage.write(key: _tokenKey, value: data['session_token']);
    await _storage.write(key: _expiresKey, value: data['expires_at']);
    return data['user'] as Map<String, dynamic>;
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

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
