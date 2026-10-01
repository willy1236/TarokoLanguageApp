import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/shared/widgets/signed_network_image.dart';

void main() {
  test('快取鍵去掉簽章參數，同一張圖換了新簽章鍵不變', () {
    const a =
        'https://storage.googleapis.com/b/events/12/x.jpg?X-Goog-Date=1&X-Goog-Signature=aa';
    const b =
        'https://storage.googleapis.com/b/events/12/x.jpg?X-Goog-Date=2&X-Goog-Signature=bb';
    expect(signedUrlCacheKey(a), signedUrlCacheKey(b));
    expect(
      signedUrlCacheKey(a),
      'https://storage.googleapis.com/b/events/12/x.jpg',
    );
  });

  test('不同圖片的鍵不同；沒有 query 的網址原樣當鍵', () {
    expect(
      signedUrlCacheKey('https://h/events/12/x.jpg?s=1'),
      isNot(signedUrlCacheKey('https://h/events/12/y.jpg?s=1')),
    );
    expect(signedUrlCacheKey('https://h/a.jpg'), 'https://h/a.jpg');
  });
}
