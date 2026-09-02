import '../models/article_models.dart';
import '../models/event_model.dart';
import '../models/forum_models.dart';
import '../models/video_models.dart';

/// 本機展示內容只在 API 無資料或暫時無法讀取時使用，避免空白畫面影響展示。
/// 正式資料一旦可取得，畫面仍會優先顯示 API 回傳內容。
abstract final class DemoContent {
  static const _demoIdFloor = -1000;

  static bool isDemoId(int id) => id <= _demoIdFloor;

  static const boards = [
    ForumBoard(id: -1001, slug: 'culture', name: '文化', description: '部落文化與記憶'),
    ForumBoard(id: -1002, slug: 'learning', name: '學習', description: '族語學習交流'),
    ForumBoard(id: -1003, slug: 'events', name: '活動', description: '走讀與聚會'),
  ];

  static final events = [
    EventSummary(
      id: -1010,
      title: '布洛灣文化走讀',
      startsAt: DateTime(2026, 9, 12, 9),
      location: '布洛灣臺地',
      maxParticipants: 25,
      category: '走讀',
      status: 'active',
      participantCount: 18,
      registrationOpen: true,
    ),
    EventSummary(
      id: -1011,
      title: '太魯閣語家庭練習夜',
      startsAt: DateTime(2026, 9, 20, 19),
      location: '富世社區活動中心',
      maxParticipants: 20,
      category: '族語',
      status: 'active',
      participantCount: 14,
      registrationOpen: true,
    ),
    EventSummary(
      id: -1012,
      title: '部落歌謠分享會',
      startsAt: DateTime(2026, 10, 3, 18, 30),
      location: '秀林鄉文化廣場',
      maxParticipants: 45,
      category: '音樂',
      status: 'active',
      participantCount: 32,
      registrationOpen: true,
    ),
  ];

  static final _posts = [
    ForumPost(
      id: -1020,
      board: boards[0],
      title: '布洛灣的名字，原來有這樣的意思',
      body: '剛讀到資料才知道，布洛灣在太魯閣語裡有「追蹤獵物的地方」的意思。下次去走步道時，想帶著這個故事一起看。',
      likeCount: 37,
      commentCount: 8,
      isPinned: false,
      isLiked: false,
      isBookmarked: false,
      images: const [],
      tags: const [ForumTag(name: '文化筆記', slug: 'culture-notes')],
      createdAt: DateTime(2026, 9, 2, 18, 0),
      updatedAt: DateTime(2026, 9, 2, 18, 0),
      author: const ForumAuthor(uid: -1020, displayName: 'Lawa'),
    ),
    ForumPost(
      id: -1021,
      board: boards[1],
      title: '今晚用三句話介紹自己的部落',
      body: '今晚的族語練習，我們用三句話介紹自己的部落。大家平常都怎麼跟家裡的長輩開話題呢？',
      likeCount: 21,
      commentCount: 14,
      isPinned: false,
      isLiked: false,
      isBookmarked: false,
      images: const [],
      tags: const [ForumTag(name: '族語練習', slug: 'language-practice')],
      createdAt: DateTime(2026, 9, 2, 16, 0),
      updatedAt: DateTime(2026, 9, 2, 16, 0),
      author: const ForumAuthor(uid: -1021, displayName: 'Sayun'),
    ),
    ForumPost(
      id: -1022,
      board: boards[2],
      title: '走讀後記：山裡的路也連著彼此',
      body: '上週走讀聽到耆老說，以前山裡的路不只是往返的路，也連著部落、獵場和彼此的照應。想把這段話記下來。',
      likeCount: 45,
      commentCount: 11,
      isPinned: false,
      isLiked: false,
      isBookmarked: false,
      images: const [],
      tags: const [ForumTag(name: '走讀', slug: 'walking-tour')],
      createdAt: DateTime(2026, 9, 1, 19, 0),
      updatedAt: DateTime(2026, 9, 1, 19, 0),
      author: const ForumAuthor(uid: -1022, displayName: 'Bakan'),
    ),
  ];

  static ForumPostPage forumPage({String? boardSlug}) => ForumPostPage(
    pinned: const [],
    posts: _posts
        .where((post) => boardSlug == null || post.board.slug == boardSlug)
        .toList(),
    nextCursor: null,
  );

  static final _videos = [
    VideoSummary(
      id: -1030,
      title: '布洛灣臺地：追蹤獵物的地方',
      description: '從地名認識太魯閣族的生活記憶。',
      category: VideoCategory.cultural,
      durationSec: 522,
      viewCount: 1248,
      weeklyViewCount: 186,
      publishedAt: DateTime(2026, 8, 28),
    ),
    VideoSummary(
      id: -1031,
      title: '山徑百年：從部落獵徑走進立霧溪',
      description: '山徑不只是道路，也承載部落彼此照應的記憶。',
      category: VideoCategory.tribalIntro,
      durationSec: 738,
      viewCount: 936,
      weeklyViewCount: 142,
      publishedAt: DateTime(2026, 8, 24),
    ),
    VideoSummary(
      id: -1032,
      title: '苧麻到麻布：太魯閣族的織作記憶',
      description: '從植物纖維看見日常工藝。',
      category: VideoCategory.education,
      durationSec: 575,
      viewCount: 782,
      weeklyViewCount: 98,
      publishedAt: DateTime(2026, 8, 19),
    ),
  ];

  static VideoListResponse videos({String? category, String sort = 'latest'}) {
    final items = _videos
        .where((video) => category == null || video.category == category)
        .toList();
    return VideoListResponse(
      total: items.length,
      page: 1,
      pageSize: 20,
      sort: sort,
      videos: items,
    );
  }

  static final _articles = [
    ArticleSummary(
      id: -1040,
      title: '從立霧溪認識太魯閣族的遷徙與聚落',
      summary: '順著立霧溪流域，整理地景、聚落與生活記憶的關係。',
      category: ArticleCategory.cultural,
      viewCount: 1248,
      weeklyViewCount: 186,
      publishedAt: DateTime(2026, 8, 30),
    ),
    ArticleSummary(
      id: -1041,
      title: '布洛灣：追蹤獵物的地方',
      summary: '地名背後保留著人與山林互動的線索。',
      category: ArticleCategory.tribalIntro,
      viewCount: 936,
      weeklyViewCount: 142,
      publishedAt: DateTime(2026, 8, 26),
    ),
    ArticleSummary(
      id: -1042,
      title: '山徑不只是道路：部落獵徑的記憶',
      summary: '從舊路徑回看部落、獵場與彼此的照應。',
      category: ArticleCategory.cultural,
      viewCount: 782,
      weeklyViewCount: 98,
      publishedAt: DateTime(2026, 8, 21),
    ),
  ];

  static ArticleListResponse articles({
    String? category,
    String sort = 'latest',
  }) {
    final items = _articles
        .where((article) => category == null || article.category == category)
        .toList();
    return ArticleListResponse(
      total: items.length,
      page: 1,
      pageSize: 20,
      sort: sort,
      articles: items,
    );
  }
}
