// 頭像裁切：裁切出來的大圖縮到邊長 1024 以內、輸出 PNG；旋轉鈕向右轉 90 度。

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
  test('旋轉：向右轉 90 度，連轉四次回到原方向', () {
    // 有透明度走 PNG（無損），才能比對像素位置。
    final source = img.Image(width: 3, height: 2, numChannels: 4)
      ..setPixelRgba(0, 0, 255, 0, 0, 255);

    final once = img.decodePng(rotateAvatarSource(img.encodePng(source)))!;
    expect((once.width, once.height), (2, 3));
    // 左上角向右轉後到右上角。
    expect(once.getPixel(1, 0).r, 255);

    var bytes = img.encodePng(source);
    for (var i = 0; i < 4; i++) {
      bytes = rotateAvatarSource(bytes);
    }
    final back = img.decodePng(bytes)!;
    expect((back.width, back.height), (3, 2));
    expect(back.getPixel(0, 0).r, 255);
  });

  test('旋轉：先套用 EXIF 方向，轉的是畫面上看到的那張', () {
    // orientation 6：存的是 200×100，畫面上要轉正成 100×200。
    final source = img.Image(width: 200, height: 100)
      ..exif.imageIfd.orientation = 6;

    final out = img.decodeJpg(rotateAvatarSource(img.encodeJpg(source)))!;

    expect((out.width, out.height), (200, 100));
    expect(out.exif.imageIfd.hasOrientation, isFalse);
  });
}
