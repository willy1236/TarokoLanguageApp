// 對應 GET /api/ethnic-groups、GET /api/tribes 回傳格式
// 規格參考：Truku_backend 說明文件/API/00_核心與認證.md §2.5

class EthnicGroup {
  final String ethnicGroup;
  final int tribeCount;

  const EthnicGroup({required this.ethnicGroup, required this.tribeCount});

  factory EthnicGroup.fromJson(Map<String, dynamic> json) {
    return EthnicGroup(
      ethnicGroup: json['ethnic_group'] as String,
      tribeCount: json['tribe_count'] as int,
    );
  }
}

class Tribe {
  final int id;
  final String ethnicGroup;
  final String name;
  final String nameTruku;
  final String county;
  final String township;

  const Tribe({
    required this.id,
    required this.ethnicGroup,
    required this.name,
    required this.nameTruku,
    required this.county,
    required this.township,
  });

  factory Tribe.fromJson(Map<String, dynamic> json) {
    return Tribe(
      id: json['id'] as int,
      ethnicGroup: json['ethnic_group'] as String,
      name: json['name'] as String,
      nameTruku: json['name_truku'] as String,
      county: json['county'] as String,
      township: json['township'] as String,
    );
  }
}
