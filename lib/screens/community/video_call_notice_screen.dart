// 視訊配對前的須知頁。首次配對時顯示一次（見 hasSeenVideoCallNotice /
// markVideoCallNoticeSeen），內容為靜態行為規範，不走後端 API，
// 與 terms_consent_screen.dart 的服務條款流程分開。

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

const _prefsKey = 'video_call_notice_seen';

Future<bool> hasSeenVideoCallNotice() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_prefsKey) ?? false;
}

Future<void> markVideoCallNoticeSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_prefsKey, true);
}

class VideoCallNoticeScreen extends StatelessWidget {
  const VideoCallNoticeScreen({super.key});

  static const _rules = [
    '請以尊重、友善的態度與對方交流，不進行任何形式的騷擾或不當言論。',
    '請勿透過視訊通話散布色情、暴力或其他違反法規的內容。',
    '通話內容僅供雙方即時交流，請勿錄影、截圖或外流他人畫面。',
    '若遇到不當行為，可隨時結束通話，並於事後檢舉對方。',
  ];

  static const _privacyRules = [
    '本 App 使用 Agora 處理視訊通話的即時資料傳輸。',
    '未整合 Agora 的錄影功能，通話過程不會被錄製。',
    'App 本身不保留、不儲存任何通話內容。',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(
          '視訊配對須知',
          style: AppTypography.subtitleStyle(seniorMode: true, color: AppColors.ink),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '開始配對前，請先閱讀以下規範',
                      style: AppTypography.titleStyle(seniorMode: true, color: AppColors.ink),
                    ),
                    const SizedBox(height: 16),
                    for (final rule in _rules) ...[
                      _buildRule(rule),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '隱私政策',
                      style: AppTypography.titleStyle(seniorMode: true, color: AppColors.ink),
                    ),
                    const SizedBox(height: 16),
                    for (final rule in _privacyRules) ...[
                      _buildRule(rule),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            _buildAgreeBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRule(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: AppTypography.bodyLargeStyle(seniorMode: true, color: AppColors.ink),
        ),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyLargeStyle(
              seniorMode: true,
              color: AppColors.ink.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAgreeBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.cream,
        border: Border(top: BorderSide(color: AppColors.creamDeep)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              '我已了解並同意',
              style: AppTypography.subtitleStyle(seniorMode: true, color: AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}
