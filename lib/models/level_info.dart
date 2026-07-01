// 對應 GET /api/levels 回傳的單一 level 統計
// SELECT level, COUNT(*) FROM words WHERE audio_url IS NOT NULL GROUP BY level

class LevelInfo {
  final String level;
  final int wordCount;

  const LevelInfo({required this.level, required this.wordCount});

  factory LevelInfo.fromJson(Map<String, dynamic> json) {
    return LevelInfo(
      level: (json['code'] ?? json['label'] ?? json['level']) as String,
      wordCount: (json['available_words'] ?? json['word_count'] ?? json['count']) as int,
    );
  }
}
