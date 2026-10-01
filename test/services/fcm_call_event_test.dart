// 通話事件同時從推播與即時連線送出（Truku_backend API/即時連線.md「通話事件」，
// 內容相同、id 一律字串）：先到的處理、後到的略過。

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/friend_model.dart';
import 'package:flutter_application_1/services/fcm_service.dart';

import '../helpers/widget_test_helpers.dart';

RemoteMessage _push(Map<String, String> data) => RemoteMessage(data: data);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    FcmService.resetHandledCallEvents();
  });

  tearDown(() {
    FcmService.onFriendCallEnded = null;
    FcmService.onVideoSessionEnded = null;
    FcmService.onFriendCallIncoming = null;
    FcmService.onFriendCallAccepted = null;
    FcmService.onFriendCallDeclined = null;
    FcmService.onFriendCallCancelled = null;
  });

  test('即時連線先到、推播後到：好友通話結束只處理一次', () {
    final ended = <int>[];
    FcmService.onFriendCallEnded = ended.add;
    const data = {'type': 'friend_call_ended', 'call_id': '12'};

    FcmService.handleSocketCallEvent(data);
    FcmService.handleForegroundMessage(_push(data));
    FcmService.handleOpenedMessage(_push(data));

    expect(ended, [12]);
  });

  test('推播先到、即時連線後到：配對結束只處理一次；不同 session 各自處理', () {
    final ended = <int?>[];
    FcmService.onVideoSessionEnded = ended.add;

    FcmService.handleForegroundMessage(
      _push({'type': 'video_session_ended', 'session_id': '34'}),
    );
    FcmService.handleSocketCallEvent({
      'type': 'video_session_ended',
      'session_id': '34',
    });
    FcmService.handleSocketCallEvent({
      'type': 'video_session_ended',
      'session_id': '35',
    });

    expect(ended, [34, 35]);
  });

  test('即時連線沒有畫面接手時不記下，隨後的推播照常處理', () {
    const data = {'type': 'video_session_ended', 'session_id': '34'};
    FcmService.handleSocketCallEvent(data);

    final ended = <int?>[];
    FcmService.onVideoSessionEnded = ended.add;
    FcmService.handleForegroundMessage(_push(data));

    expect(ended, [34]);
  });

  test('即時連線開過來電畫面，之後點同一通的通知不再開一次', () async {
    installMockClient({
      '/api/friends/calls/incoming': {
        'incoming': [
          {
            'call_id': 7,
            'caller_nickname': '小明',
            'caller_friend_code': 'BBBB2345',
            'created_at': '2026-10-01T00:00:00Z',
          },
        ],
      },
    });
    final opened = <IncomingCall>[];
    FcmService.onFriendCallIncoming = opened.add;
    const data = {
      'type': 'friend_call_incoming',
      'call_id': '7',
      'caller_friend_code': 'BBBB2345',
    };

    FcmService.handleSocketCallEvent(data);
    await pumpEventQueue();
    FcmService.handleOpenedMessage(_push(data));
    FcmService.handleForegroundMessage(_push(data));
    await pumpEventQueue();

    expect(opened.map((c) => c.callId), [7]);
  });

  test('撥出中收到接聽、拒接、取消交給對應回呼', () {
    final accepted = <int>[];
    final declined = <int>[];
    final cancelled = <int>[];
    FcmService.onFriendCallAccepted = accepted.add;
    FcmService.onFriendCallDeclined = declined.add;
    FcmService.onFriendCallCancelled = cancelled.add;

    FcmService.handleSocketCallEvent({
      'type': 'friend_call_accepted',
      'call_id': '1',
      'session_id': '9',
    });
    FcmService.handleForegroundMessage(
      _push({'type': 'friend_call_declined', 'call_id': '2'}),
    );
    FcmService.handleSocketCallEvent({
      'type': 'friend_call_cancelled',
      'call_id': '3',
    });

    expect(accepted, [1]);
    expect(declined, [2]);
    expect(cancelled, [3]);
  });
}
