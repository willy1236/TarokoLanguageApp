import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/video_models.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/video_service.dart';

class VideoDetailScreen extends StatefulWidget {
  final int videoId;
  const VideoDetailScreen({super.key, required this.videoId});

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  late Future<void> _future;
  VideoDetail? _video;
  Object? _error;
  BetterPlayerController? _playerController;
  bool _likeBusy = false;
  bool _bookmarkBusy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _load() async {
    try {
      final detail = await VideoService.fetchVideoDetail(widget.videoId);
      _playerController = BetterPlayerController(
        const BetterPlayerConfiguration(
          aspectRatio: 16 / 9,
          autoPlay: true,
          fit: BoxFit.contain,
        ),
        betterPlayerDataSource: BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          detail.hlsUrl,
          videoFormat: BetterPlayerVideoFormat.hls,
        ),
      );
      _video = detail;
    } catch (e) {
      _error = e;
    }
  }

  @override
  void dispose() {
    _playerController?.dispose();
    super.dispose();
  }

  /// 樂觀更新，API 回傳真實計數後校正；失敗則還原。
  Future<void> _toggleLike() async {
    final video = _video;
    if (video == null || _likeBusy) return;
    setState(() {
      _likeBusy = true;
      _video = video.toggledLike();
    });
    try {
      final result = await VideoService.likeVideo(
        widget.videoId,
        like: !video.isLiked,
      );
      if (!mounted) return;
      setState(() {
        _video = _video!.withLikeResult(
          liked: result.liked,
          likeCount: result.likeCount,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _video = video);
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  Future<void> _toggleBookmark() async {
    final video = _video;
    if (video == null || _bookmarkBusy) return;
    setState(() {
      _bookmarkBusy = true;
      _video = video.toggledBookmark();
    });
    try {
      await VideoService.bookmarkVideo(widget.videoId, add: !video.isBookmarked);
    } catch (_) {
      if (!mounted) return;
      setState(() => _video = video);
    } finally {
      if (mounted) setState(() => _bookmarkBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => _buildScaffold(seniorModeController.enabled),
    );
  }

  Widget _buildScaffold(bool seniorMode) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: AppBar(
        backgroundColor: AppColors.midnight,
        foregroundColor: AppColors.cream,
        elevation: 0,
      ),
      body: FutureBuilder<void>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            );
          }
          if (_error != null) {
            return _buildError(_error, seniorMode);
          }
          return _buildContent(_video!, seniorMode);
        },
      ),
    );
  }

  Widget _buildError(Object? error, bool seniorMode) {
    String message = '發生錯誤，請稍後再試';
    if (error is ApiException) {
      switch (error.code) {
        case 'VIDEO_NOT_READY':
          message = '影片還在轉檔中，請稍後再試';
          break;
        case 'VIDEO_ARCHIVED':
          message = '這部影片已下架';
          break;
        case 'VIDEO_NOT_FOUND':
          message = '找不到這部影片';
          break;
        default:
          message = error.message;
      }
    }
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
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.cream,
                fontSize: seniorMode ? AppTypography.title : 15,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '返回清單',
                style: seniorMode
                    ? const TextStyle(fontSize: AppTypography.subtitle)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(VideoDetail video, bool seniorMode) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _playerController != null
                ? BetterPlayer(controller: _playerController!)
                : const SizedBox.shrink(),
          ),
          Padding(
            padding: EdgeInsets.all(seniorMode ? AppSpacing.lg : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: seniorMode ? 26 : 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.creamLight,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                seniorMode
                    ? Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _tag(VideoCategory.label(video.category), true),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility,
                                size: 22,
                                color: AppColors.fog,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${video.viewCount}',
                                style: TextStyle(
                                  color: AppColors.fog,
                                  fontSize: AppTypography.subtitle,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _engagementButton(
                                icon: video.isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                active: video.isLiked,
                                count: video.likeCount,
                                onTap: _toggleLike,
                                seniorMode: true,
                              ),
                              _engagementButton(
                                icon: video.isBookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                active: video.isBookmarked,
                                onTap: _toggleBookmark,
                                seniorMode: true,
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          _tag(VideoCategory.label(video.category), false),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.visibility,
                            size: 14,
                            color: AppColors.fog,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${video.viewCount}',
                            style: TextStyle(color: AppColors.fog, fontSize: 12),
                          ),
                          const Spacer(),
                          _engagementButton(
                            icon: video.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            active: video.isLiked,
                            count: video.likeCount,
                            onTap: _toggleLike,
                            seniorMode: false,
                          ),
                          const SizedBox(width: 8),
                          _engagementButton(
                            icon: video.isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            active: video.isBookmarked,
                            onTap: _toggleBookmark,
                            seniorMode: false,
                          ),
                        ],
                      ),
                if (video.description != null &&
                    video.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    video.description!,
                    style: TextStyle(
                      color: AppColors.mist,
                      fontSize: seniorMode ? AppTypography.title : 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, bool seniorMode) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: seniorMode ? 5 : 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: seniorMode ? AppTypography.body : 10,
          color: AppColors.gold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _engagementButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    required bool seniorMode,
    int? count,
  }) {
    final color = active ? AppColors.gold : AppColors.fog;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: seniorMode ? 12 : 6,
          vertical: seniorMode ? 8 : 4,
        ),
        child: Row(
          children: [
            Icon(icon, size: seniorMode ? 30 : 18, color: color),
            if (count != null) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: seniorMode ? AppTypography.subtitle : 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
