// 「我按讚的影片」／「我收藏的影片」清單內容。不含 Scaffold/AppBar，
// 供獨立畫面或 TabBarView 嵌入使用。page/page_size 分頁（非 forum 的 cursor 分頁）。

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/video_models.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/video_service.dart';
import '../../shared/widgets/truku_empty_state.dart';
import 'video_detail_screen.dart';

enum VideoListMode { liked, bookmarked }

class VideoLikedBookmarkedList extends StatefulWidget {
  final VideoListMode mode;
  const VideoLikedBookmarkedList({super.key, required this.mode});

  @override
  State<VideoLikedBookmarkedList> createState() =>
      _VideoLikedBookmarkedListState();
}

class _VideoLikedBookmarkedListState extends State<VideoLikedBookmarkedList> {
  static const _pageSize = 20;

  final _videos = <VideoSummary>[];
  final _scrollController = ScrollController();
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _videos.length >= _total) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<VideoListResponse> _fetch(int page) {
    return widget.mode == VideoListMode.liked
        ? VideoService.fetchLikedVideos(page: page, pageSize: _pageSize)
        : VideoService.fetchVideoBookmarks(page: page, pageSize: _pageSize);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _fetch(1);
      if (!mounted) return;
      setState(() {
        _videos
          ..clear()
          ..addAll(res.videos);
        _page = 1;
        _total = res.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final res = await _fetch(_page + 1);
      if (!mounted) return;
      setState(() {
        _videos.addAll(res.videos);
        _page += 1;
        _total = res.total;
      });
    } catch (_) {
      // 翻頁失敗保持原清單，使用者可再滑動觸發重試。
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => _buildBody(seniorModeController.enabled),
    );
  }

  Widget _buildBody(bool seniorMode) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (_error != null) {
      return _buildError(_error, seniorMode);
    }
    if (_videos.isEmpty) {
      return _buildEmpty(seniorMode);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _videos.length + (_videos.length < _total ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _videos.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold,
                  ),
                ),
              ),
            );
          }
          return _VideoListItem(
            video: _videos[index],
            seniorMode: seniorMode,
          );
        },
      ),
    );
  }

  Widget _buildEmpty(bool seniorMode) {
    final message = widget.mode == VideoListMode.liked
        ? '還沒有按讚任何影片'
        : '還沒有收藏任何影片';
    return TrukuEmptyState(
      icon: Icons.video_library_outlined,
      message: message,
      subtitle: '下拉重新整理，看看有沒有新影片。',
      seniorMode: seniorMode,
    );
  }

  Widget _buildError(Object? error, bool seniorMode) {
    final message = error is ApiException ? error.message : '發生錯誤，請稍後再試';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.fog,
              size: seniorMode ? 56 : 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: AppColors.cream,
                fontSize: seniorMode ? AppTypography.title : 14,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _load,
              style: seniorMode
                  ? OutlinedButton.styleFrom(
                      minimumSize: const Size(140, 52),
                      textStyle: const TextStyle(
                        fontSize: AppTypography.subtitle,
                      ),
                    )
                  : null,
              child: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoListItem extends StatelessWidget {
  final VideoSummary video;
  final bool seniorMode;
  const _VideoListItem({required this.video, required this.seniorMode});

  @override
  Widget build(BuildContext context) {
    final thumbWidth = seniorMode ? 128.0 : 96.0;
    final thumbHeight = seniorMode ? 80.0 : 60.0;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoDetailScreen(videoId: video.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.midnightSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: thumbWidth,
                height: thumbHeight,
                child: video.thumbnailUrl != null
                    ? Image.network(
                        video.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppColors.midnight,
                          child: const Icon(
                            Icons.play_circle_outline,
                            color: AppColors.fog,
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.midnight,
                        child: const Icon(
                          Icons.play_circle_outline,
                          color: AppColors.fog,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.creamLight,
                      fontSize: seniorMode ? AppTypography.title : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        video.isLiked ? Icons.favorite : Icons.favorite_border,
                        size: seniorMode ? 22 : 14,
                        color: video.isLiked ? AppColors.gold : AppColors.fog,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${video.likeCount}',
                        style: TextStyle(
                          color: AppColors.fog,
                          fontSize: seniorMode ? AppTypography.subtitle : 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.visibility,
                        size: seniorMode ? 22 : 14,
                        color: AppColors.fog,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${video.viewCount}',
                        style: TextStyle(
                          color: AppColors.fog,
                          fontSize: seniorMode ? AppTypography.subtitle : 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
