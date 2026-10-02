// 非 Web 平台不會呼叫：手機的地圖語言跟著 App 語系，反向地理編碼用系統內建。

Future<void> loadMapsJs(String apiKey) =>
    throw UnsupportedError('loadMapsJs 只在 Web 使用');

Future<String?> webAddressAt(double lat, double lng) =>
    throw UnsupportedError('webAddressAt 只在 Web 使用');
