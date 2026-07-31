import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/constants/api.dart';
import '../core/network/api_client.dart';

class NotificationService {
  static bool _started = false;
  static Future<void> registerDevice() async {
    if (_started) return;
    _started = true;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      Future<void> save(String? token) async {
        if (token != null && token.isNotEmpty)
          await ApiClient.post(ApiConfig.devices, {
            'fcm_token': token,
            'platform': Platform.isIOS ? 'ios' : 'android',
          });
      }

      await save(await messaging.getToken());
      messaging.onTokenRefresh.listen(save);
    } catch (_) {
      _started = false;
    }
  }
}
