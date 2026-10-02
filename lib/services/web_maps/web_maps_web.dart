import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// flutter_google_places_sdk_web 用這個 id 判斷 Maps JS 是否已注入；先放好同 id 的
/// script，外掛就不會再注入一份沒帶語言參數的。
const _scriptId = 'flutter_google_places_sdk_web_script_id';
const _callback = '__trukuMapsReady';

Future<void>? _loading;

/// 載入 Maps JS（含 places 程式庫，地圖文字用繁中、地區台灣）；重複呼叫只載一次。
Future<void> loadMapsJs(String apiKey) => _loading ??= _load(apiKey);

Future<void> _load(String apiKey) {
  final done = Completer<void>();
  globalContext[_callback] = (() {
    if (!done.isCompleted) done.complete();
  }).toJS;
  final src = Uri.https('maps.googleapis.com', '/maps/api/js', {
    'key': apiKey,
    'loading': 'async',
    'libraries': 'places',
    'language': 'zh-TW',
    'region': 'TW',
    'callback': _callback,
  }).toString();
  final script = web.HTMLScriptElement()
    ..id = _scriptId
    ..src = src
    ..async = true;
  script.onerror = ((web.Event _) {
    _loading = null; // 讓下次開啟選點畫面可以重試
    script.remove();
    if (!done.isCompleted) done.completeError(StateError('Maps JS 載入失敗'));
  }).toJS;
  web.document.head!.append(script);
  return done.future;
}

@JS('google.maps.importLibrary')
external JSPromise<JSObject> _importLibrary(String name);

/// 座標所在地址（formatted_address）；查不到回 null。需先載入 Maps JS
/// （PlacesService.ensureReady）。
Future<String?> webAddressAt(double lat, double lng) async {
  final lib = await _importLibrary('geocoding').toDart;
  final geocoder = (lib['Geocoder']! as JSFunction)
      .callAsConstructor<JSObject>();
  final location = JSObject()
    ..['lat'] = lat.toJS
    ..['lng'] = lng.toJS;
  final request = JSObject()
    ..['location'] = location
    ..['language'] = 'zh-TW'.toJS;
  final JSObject response;
  try {
    response = await geocoder
        .callMethod<JSPromise<JSObject>>('geocode'.toJS, request)
        .toDart;
  } catch (_) {
    return null; // ZERO_RESULTS 等狀態會以 reject 回來
  }
  final results = response['results'] as JSArray<JSObject>?;
  if (results == null || results.length == 0) return null;
  final address = results[0]['formatted_address'];
  return address.isA<JSString>() ? (address as JSString).toDart : null;
}
