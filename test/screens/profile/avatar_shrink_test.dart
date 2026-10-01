// 頭像裁切後縮圖：相機原圖裁切出來的大圖縮到邊長 1024 以內、輸出 PNG。

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_application_1/screens/profile/avatar_crop_screen.dart';

void main() {
  test('大於 1024 的裁切結果縮到 1024，輸出 PNG', () {
    final big = img.encodeJpg(img.Image(width: 3000, height: 3000));

    final out = img.decodePng(shrinkAvatar(big))!;

    expect(out.width, avatarMaxSide);
    expect(out.height, avatarMaxSide);
  });

  test('已小於 1024 不放大，只轉成 PNG', () {
    final small = img.encodeJpg(img.Image(width: 600, height: 600));

    final out = img.decodePng(shrinkAvatar(small))!;

    expect(out.width, 600);
  });

  test('去掉 EXIF 方向標記，避免已轉正的像素被再轉一次', () {
    final source = img.Image(width: 1200, height: 1200)
      ..exif.imageIfd.orientation = 6;

    final out = img.decodePng(shrinkAvatar(img.encodeJpg(source)))!;

    expect(out.exif.imageIfd.hasOrientation, isFalse);
  });
}
