// 認證流程：
//   Google Sign-In → 拿 Firebase ID Token → POST /api/auth/login 換系統 JWT
//   系統 JWT 存在 flutter_secure_storage，給之後 API 呼叫帶 Authorization header
//
// 規格書對應：API設計/資料交換表_核心.md §2.1 POST /api/auth/login

import 'dart:convert';
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
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// 走 Google 登入完整流程，成功回 user JSON。
  /// 失敗 throw [AuthException]。
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    // 1. Google Sign-In SDK 拿 GoogleSignInAccount + idToken
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw AuthException('使用者取消登入');
    }
    final googleAuth = await googleUser.authentication;

    // 2. 用 Google credential 換 Firebase user
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCred = await _auth.signInWithCredential(credential);
    final firebaseToken = await userCred.user?.getIdToken();
    if (firebaseToken == null) {
      throw AuthException('取得 Firebase token 失敗');
    }

    // 3. 打後端換系統 JWT
    final resp = await http.post(
      Uri.parse(ApiConfig.baseUrl + ApiConfig.authLogin),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'firebase_token': firebaseToken}),
    );

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
    await _googleSignIn.signOut();
    await _auth.signOut();
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresKey);
  }

  /// 撤銷所有裝置的 JWT（規格書 §2.2 POST /api/auth/logout-all）
  static Future<void> logoutAllDevices() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return;
    await http.post(
      Uri.parse(ApiConfig.baseUrl + ApiConfig.logoutAll),
      headers: {'Authorization': 'Bearer $token'},
    );
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
    } catch (_) {
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
