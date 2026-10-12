// 通話結束後的去向（要不要問檢舉）與檢舉端點的選擇。
// 畫面本身綁 Agora 與推播，UI 流程靠實機驗證；這裡只驗純判斷。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/community/video_call_screen.dart';

void main() {
  group('decideAfterCall', () {
    AfterCallAction decide({
      bool blockedPeer = false,
      bool blockInFlight = false,
      bool joined = true,
      bool readOnly = false,
      bool reportedInCall = false,
    }) => decideAfterCall(
      blockedPeer: blockedPeer,
      blockInFlight: blockInFlight,
      joined: joined,
      readOnly: readOnly,
      reportedInCall: reportedInCall,
    );

    test('接通過、非唯讀、沒封鎖、沒檢舉過 → 問檢舉', () {
      expect(decide(), AfterCallAction.offerReport);
    });

    test('沒接通 → 不問', () {
      expect(decide(joined: false), AfterCallAction.leave);
    });

    test('唯讀帳號 → 不問', () {
      expect(decide(readOnly: true), AfterCallAction.leave);
    });

    test('通話中已檢舉 → 不問，直接回首頁', () {
      expect(decide(reportedInCall: true), AfterCallAction.leave);
    });

    test('剛封鎖對方 → 回首頁並提示已封鎖，優先於其他條件', () {
      expect(
        decide(blockedPeer: true, reportedInCall: true),
        AfterCallAction.leaveBlocked,
      );
    });

    test('封鎖請求還在途中 → 不問，直接回首頁', () {
      expect(decide(blockInFlight: true), AfterCallAction.leaveWhileBlocking);
    });
  });

  group('callReportSubmitter', () {
    late List<String> calls;

    Future<void> Function(String) submitter(int? directedCallId) =>
        callReportSubmitter(
          sessionId: 7,
          directedCallId: directedCallId,
          reportCall: (id, reason) async => calls.add('call:$id:$reason'),
          reportSession: (id, reason) async => calls.add('session:$id:$reason'),
        );

    setUp(() => calls = []);

    test('隨機配對 → 檢舉 session', () async {
      await submitter(null)('騷擾');
      expect(calls, ['session:7:騷擾']);
    });

    test('好友通話 → 檢舉 call，不打 session 端點', () async {
      await submitter(99)('騷擾');
      expect(calls, ['call:99:騷擾']);
    });
  });
}
