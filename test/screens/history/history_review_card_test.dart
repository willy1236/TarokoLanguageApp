// ReviewCard 的發音按鈕：題目列與詳解列網址相同時只留一顆，不同時兩顆，
// 都沒有音檔時一顆都不畫。

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/history/history_review_card.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => stubCommonChannels(audio: true));

  Future<void> pumpCard(
    WidgetTester tester, {
    String? promptAudioUrl,
    String? detailAudioUrl,
  }) async {
    // 不 dispose：測試環境的 audioplayers channel 是假的，dispose 會等不到回應而卡住。
    final player = AudioPlayer();
    await tester.pumpWidget(
      wrap(
        SingleChildScrollView(
          child: ReviewCard(
            order: 1,
            promptText: 'embiyax su hug?',
            promptAudioUrl: promptAudioUrl,
            isCorrect: true,
            yourAnswerText: '你好嗎？',
            correctAnswerText: '你好嗎？',
            detailTitle: 'embiyax su hug?',
            detailSubtitle: '你好嗎？',
            explanation: null,
            detailAudioUrl: detailAudioUrl,
            player: player,
            sessionId: 's',
            questionId: 'q',
            questionType: 'quiz',
          ),
        ),
      ),
    );
  }

  final playIcons = find.byWidgetPredicate(
    (w) =>
        w is Icon && (w.icon == Icons.volume_up || w.icon == Icons.play_arrow),
  );

  testWidgets('兩個網址相同時只有題目旁一顆，標籤為「發音」', (tester) async {
    await pumpCard(
      tester,
      promptAudioUrl: 'https://example.com/a.mp3',
      detailAudioUrl: 'https://example.com/a.mp3',
    );

    expect(playIcons, findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(find.text('發音'), findsOneWidget);
    expect(find.text('原題發音'), findsNothing);
    expect(find.text('標準發音'), findsNothing);
  });

  testWidgets('兩個網址不同時兩顆，標籤維持原題／標準發音', (tester) async {
    await pumpCard(
      tester,
      promptAudioUrl: 'https://example.com/sentence.mp3',
      detailAudioUrl: 'https://example.com/word.mp3',
    );

    expect(playIcons, findsNWidgets(2));
    expect(find.text('原題發音'), findsOneWidget);
    expect(find.text('標準發音'), findsOneWidget);
  });

  testWidgets('都沒有音檔時不畫發音按鈕', (tester) async {
    await pumpCard(tester);

    expect(playIcons, findsNothing);
    expect(find.text('發音'), findsNothing);
  });
}
