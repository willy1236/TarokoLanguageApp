import 'package:permission_handler/permission_handler.dart';

enum CallPermissionResult { granted, denied, permanentlyDenied }

/// 相機＋麥克風權限。已授權直接回 granted；否則請求一次，永久拒絕要另外
/// 回報，畫面才能引導使用者去系統設定（否則重試永遠無效）。
Future<CallPermissionResult> requestCallPermissions() async {
  final camera = await Permission.camera.status;
  final mic = await Permission.microphone.status;
  if (camera.isGranted && mic.isGranted) return CallPermissionResult.granted;

  final results = await [Permission.camera, Permission.microphone].request();
  final cam = results[Permission.camera] ?? camera;
  final micResult = results[Permission.microphone] ?? mic;
  if (cam.isGranted && micResult.isGranted) {
    return CallPermissionResult.granted;
  }
  return cam.isPermanentlyDenied || micResult.isPermanentlyDenied
      ? CallPermissionResult.permanentlyDenied
      : CallPermissionResult.denied;
}
