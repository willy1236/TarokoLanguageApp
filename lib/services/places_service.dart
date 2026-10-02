// 活動地圖選點用的地點搜尋與反向地理編碼。畫面只拿到整理好的結果，
// 日後換供應商只改這一層。
//
// - 搜尋與地點詳情：flutter_google_places_sdk（Places API (New)）。手機走原生 Places SDK，
//   金鑰的 Android 套件名＋SHA-1、iOS bundle id 限制由 SDK 自動帶上；Web 走 Maps JS 的
//   places 程式庫（Maps JS 由 web_maps 載入，地圖也靠它）。
// - 反向地理編碼：手機用系統內建的地理編碼（geocoding，免金鑰）；Web 沒有實作，改用
//   Maps JS 的 Geocoder（Geocoding 的 REST 端點不接受限網址的金鑰）。

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places;
import 'package:geocoding/geocoding.dart' as geo;

import '../core/constants/maps_config.dart';
import '../models/picked_location.dart';
import 'web_maps/web_maps.dart';

/// 搜尋框的一筆建議。
class PlaceSuggestion {
  final String placeId;
  final String title;
  final String subtitle;

  const PlaceSuggestion({
    required this.placeId,
    required this.title,
    required this.subtitle,
  });
}

class PlacesService {
  PlacesService._();

  static const _locale = Locale('zh', 'TW');

  static places.FlutterGooglePlacesSdk? _sdk;
  static places.FlutterGooglePlacesSdk get _places =>
      _sdk ??= places.FlutterGooglePlacesSdk(
        MapsConfig.apiKey,
        locale: _locale,
        useNewApi: true,
      );

  /// 初始化 Places。Web 會在這一步載入 Maps JS，顯示地圖前要先等它完成。
  static Future<void> ensureReady() async {
    if (kIsWeb) await loadMapsJs(MapsConfig.apiKey);
    await _places.isInitialized();
  }

  /// 依輸入文字找地點，以 [near] 附近的結果優先。[newSession] 為 true 時開始新的
  /// 計費 session：一次選點從第一次搜尋到選定結果（[details]）算同一個 session。
  static Future<List<PlaceSuggestion>> search(
    String query, {
    required bool newSession,
    ({double lat, double lng})? near,
  }) async {
    final text = query.trim();
    if (text.isEmpty) return const [];
    final res = await _places.findAutocompletePredictions(
      text,
      countries: const ['TW'],
      newSessionToken: newSession,
      locationBias: near == null
          ? null
          : places.LatLngBounds(
              southwest: places.LatLng(
                lat: near.lat - 0.3,
                lng: near.lng - 0.3,
              ),
              northeast: places.LatLng(
                lat: near.lat + 0.3,
                lng: near.lng + 0.3,
              ),
            ),
    );
    return [
      for (final p in res.predictions)
        PlaceSuggestion(
          placeId: p.placeId,
          title: p.primaryText,
          subtitle: p.secondaryText,
        ),
    ];
  }

  /// 搜尋結果的名稱、地址與座標；查不到座標回 null。
  static Future<PickedLocation?> details(String placeId) async {
    final res = await _places.fetchPlace(
      placeId,
      fields: const [
        places.PlaceField.Name,
        places.PlaceField.Address,
        places.PlaceField.Location,
      ],
    );
    final place = res.place;
    final latLng = place?.latLng;
    if (place == null || latLng == null) return null;
    final name = place.name?.trim();
    return PickedLocation(
      name: name == null || name.isEmpty ? null : name,
      address: cleanAddress(place.address ?? name ?? ''),
      latitude: latLng.lat,
      longitude: latLng.lng,
    );
  }

  /// 座標所在的地址；查不到回 null（呼叫端顯示座標或請使用者手打）。
  static Future<String?> addressAt(double lat, double lng) async {
    if (kIsWeb) {
      final address = await webAddressAt(lat, lng);
      return address == null ? null : cleanAddress(address);
    }
    final marks = await geo.Geocoding().placemarkFromCoordinates(
      lat,
      lng,
      locale: _locale,
    );
    if (marks.isEmpty) return null;
    return formatPlacemark(
      administrativeArea: marks.first.administrativeArea,
      subAdministrativeArea: marks.first.subAdministrativeArea,
      locality: marks.first.locality,
      subLocality: marks.first.subLocality,
      thoroughfare: marks.first.thoroughfare,
      subThoroughfare: marks.first.subThoroughfare,
      street: marks.first.street,
    );
  }

  /// 去掉 Google 地址開頭的郵遞區號與「台灣」，發起人看到的跟手打的一樣。
  @visibleForTesting
  static String cleanAddress(String address) => address
      .trim()
      .replaceFirst(RegExp(r'^\d{3,6}\s*'), '')
      .replaceFirst(RegExp(r'^(台灣|臺灣)\s*'), '')
      .replaceFirst(RegExp(r'^\d{3,6}\s*'), '')
      .trim();

  /// 系統地理編碼的結果組成地址：依縣市、鄉鎮、村里、路、門牌接起來，
  /// 相鄰重複的層級只留一個（有些平台縣市與鄉鎮會給一樣的值）；
  /// 都沒有時退回系統給的整串 [street]。
  @visibleForTesting
  static String? formatPlacemark({
    String? administrativeArea,
    String? subAdministrativeArea,
    String? locality,
    String? subLocality,
    String? thoroughfare,
    String? subThoroughfare,
    String? street,
  }) {
    final parts = <String>[];
    for (final part in [
      administrativeArea,
      subAdministrativeArea,
      locality,
      subLocality,
      thoroughfare,
      subThoroughfare,
    ]) {
      final p = part?.trim() ?? '';
      if (p.isNotEmpty && (parts.isEmpty || parts.last != p)) parts.add(p);
    }
    if (parts.isNotEmpty) return parts.join();
    final s = street?.trim() ?? '';
    return s.isEmpty ? null : cleanAddress(s);
  }
}
