// 下載我的資料（個資法查詢/複製權）：GET /api/account/export 拿到 JSON 後交給
// 系統分享選單存檔。個人頁與強制同意畫面共用——沒同意最新版條款也能匯出。

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../services/account_service.dart';
import '../share_text_file.dart';

bool _exporting = false;

/// 匯出期間再點不會重複送出：此端點限流每分鐘 5 次，也不自動重試。
Future<void> exportMyData(BuildContext context) async {
  if (_exporting) return;
  _exporting = true;
  final messenger = ScaffoldMessenger.of(context);
  void showError(String message) => messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));

  messenger.showSnackBar(const SnackBar(content: Text('正在準備你的資料…')));
  try {
    final json = await AccountService.exportData();
    if (!context.mounted) return;
    await shareTextFile(
      content: json,
      filename: 'truku-account-data.json',
      mimeType: 'application/json',
      subject: '我的語見太魯閣資料',
    );
  } on ApiException catch (e) {
    showError(e.message);
  } catch (e) {
    debugPrint('exportMyData: 匯出資料失敗：$e');
    showError('下載失敗，請稍後再試');
  } finally {
    _exporting = false;
  }
}
