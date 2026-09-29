// 影片播放器外框：高度跟影片比例，直式影片受最大高度限制。
// 真正的 HLS 播放（比例偵測、全螢幕方向）需要實機，這裡只驗版面計算。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/culture/video_detail_screen.dart';

import '../helpers/flow_test_helpers.dart';

const _key = Key('player');

Widget _frame(double ratio, {double maxHeight = 550}) => MaterialApp(
  home: Scaffold(
    body: Column(
      children: [
        VideoPlayerFrame(
          aspectRatio: ratio,
          maxHeight: maxHeight,
          child: const SizedBox.expand(key: _key),
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('橫式 16:9：寬度撐滿、高度 9/16，與原本相同', (tester) async {
    usePhoneSurface(tester, size: const Size(400, 900));
    await tester.pumpWidget(_frame(16 / 9));

    expect(tester.getSize(find.byKey(_key)), const Size(400, 225));
  });

  testWidgets('直式 9:16 未超過上限：高度跟著影片比例', (tester) async {
    usePhoneSurface(tester, size: const Size(400, 900));
    await tester.pumpWidget(_frame(9 / 16, maxHeight: 800));

    final size = tester.getSize(find.byKey(_key));
    expect(size.height, closeTo(400 / (9 / 16), 0.01));
    expect(size.width, 400);
  });

  testWidgets('直式 9:16 超過上限：高度封頂、寬度縮小並置中', (tester) async {
    usePhoneSurface(tester, size: const Size(400, 900));
    await tester.pumpWidget(_frame(9 / 16, maxHeight: 495));

    final size = tester.getSize(find.byKey(_key));
    expect(size.height, 495);
    expect(size.width, closeTo(495 * 9 / 16, 0.01));
    expect(tester.getCenter(find.byKey(_key)).dx, 200);
    // 外框本身仍撐滿寬度，黑邊由外框上色。
    expect(tester.getSize(find.byType(VideoPlayerFrame)).width, 400);
  });

  testWidgets('超寬影片（21:9）：不超過上限，高度更矮', (tester) async {
    usePhoneSurface(tester, size: const Size(400, 900));
    await tester.pumpWidget(_frame(21 / 9));

    expect(
      tester.getSize(find.byKey(_key)).height,
      closeTo(400 * 9 / 21, 0.01),
    );
  });

  group('validRatio', () {
    test('正常比例原樣回傳', () {
      expect(VideoPlayerFrame.validRatio(0.5625), 0.5625);
    });

    test('null、0、負數、NaN、無限大視為不可用', () {
      for (final bad in [null, 0.0, -1.0, double.nan, double.infinity]) {
        expect(VideoPlayerFrame.validRatio(bad), isNull);
      }
    });
  });
}
