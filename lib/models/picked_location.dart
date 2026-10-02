/// 發起人在地圖上選定的活動位置。[name] 是 Google 地點名稱，只有從搜尋結果
/// 選的才有；拖曳地圖選的只有地址。
class PickedLocation {
  final String? name;
  final String address;
  final double latitude;
  final double longitude;

  const PickedLocation({
    this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}
