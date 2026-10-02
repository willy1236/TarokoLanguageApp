// 地圖選點：Google 與系統地理編碼回的地址整理成發起人看得懂的樣子。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/services/places_service.dart';

void main() {
  group('cleanAddress', () {
    test('去掉開頭的郵遞區號與台灣', () {
      expect(PlacesService.cleanAddress('972台灣花蓮縣秀林鄉富世村12號'), '花蓮縣秀林鄉富世村12號');
      expect(PlacesService.cleanAddress('臺灣 972 花蓮縣秀林鄉富世村'), '花蓮縣秀林鄉富世村');
      expect(PlacesService.cleanAddress(' 花蓮縣秀林鄉 '), '花蓮縣秀林鄉');
    });
  });

  group('formatPlacemark', () {
    test('依縣市、鄉鎮、村里、路、門牌接起來', () {
      expect(
        PlacesService.formatPlacemark(
          administrativeArea: '花蓮縣',
          locality: '秀林鄉',
          subLocality: '富世村',
          thoroughfare: '富世路',
          subThoroughfare: '12號',
        ),
        '花蓮縣秀林鄉富世村富世路12號',
      );
    });

    test('相鄰重複的層級只留一個', () {
      expect(
        PlacesService.formatPlacemark(
          administrativeArea: '花蓮縣',
          subAdministrativeArea: '花蓮縣',
          locality: '秀林鄉',
        ),
        '花蓮縣秀林鄉',
      );
    });

    test('分項都沒有時退回整串地址；也沒有就是 null', () {
      expect(PlacesService.formatPlacemark(street: '972台灣花蓮縣秀林鄉'), '花蓮縣秀林鄉');
      expect(PlacesService.formatPlacemark(street: ' '), isNull);
    });
  });
}
