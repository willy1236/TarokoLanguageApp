// 選檔後的格式與大小檢查（後端只收 mp4／mov、≤2GB）。挑選器本身要實機驗證。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/video_upload.dart';
import 'package:flutter_application_1/services/video_upload/video_file_picker.dart';

void main() {
  test('mp4／mov（不分大小寫）且 ≤2GB 可以上傳', () {
    expect(videoFileError('a.mp4', 1), isNull);
    expect(videoFileError('IMG_0001.MOV', adminVideoMaxBytes), isNull);
  });

  test('其他格式擋下', () {
    expect(videoFileError('a.webm', 100), '只能上傳 mp4、mov 影片檔');
    expect(videoFileError('a.3gp', 100), '只能上傳 mp4、mov 影片檔');
    expect(videoFileError('沒有副檔名', 100), '只能上傳 mp4、mov 影片檔');
  });

  test('超過 2GB 在送出前擋下', () {
    expect(
      videoFileError('a.mp4', adminVideoMaxBytes + 1),
      '影片檔最大 2GB，請壓縮或剪短後再上傳',
    );
  });

  test('空檔擋下', () {
    expect(videoFileError('a.mov', 0), '這個檔案是空的，請重新選擇');
  });
}
