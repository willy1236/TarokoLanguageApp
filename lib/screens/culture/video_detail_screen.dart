import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../core/platform/platform_features.dart';
import '../../models/video_models.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/video_service.dart';
import '../../shared/widgets/engagement_icon_button.dart';
import '../../shared/widgets/hls_web_player/hls_web_player.dart';

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
  bool _webPlayerFailed = false;
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
      // better_player_plus 只有行動平台實作，其他平台改顯示外開連結。
      if (!PlatformFeatures.supportsHlsPlayer) {
        _video = detail;
        return;
      }
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
      await VideoService.bookmarkVideo(
        widget.videoId,
        add: !video.isBookmarked,
      );
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
                fontSize: AppTypography.size(AppTypography.bodyLarge, seniorMode: seniorMode),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '返回清單',
                style: seniorMode
                    ? const TextStyle(fontSize: AppTypography.bodyLarge)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 不支援內嵌 HLS 播放的平台：提示並提供以瀏覽器開啟串流網址。
  Widget _buildExternalPlayerFallback(VideoDetail video, bool seniorMode) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '此平台暫不支援內嵌播放',
              style: AppTypography.bodyStyle(
                seniorMode: seniorMode,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.open_in_new),
              label: const Text('在新視窗開啟影片'),
              onPressed: () => launchUrl(
                Uri.parse(video.hlsUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 手機走 better_player_plus；Web 走 `<video>` + hls.js，播放失敗再退回外開連結；
  /// 其餘平台（桌面）直接顯示外開連結。
  Widget _buildPlayer(VideoDetail video, bool seniorMode) {
    if (_playerController != null) {
      return BetterPlayer(controller: _playerController!);
    }
    if (PlatformFeatures.supportsWebHlsPlayer && !_webPlayerFailed) {
      return HlsWebPlayer(
        url: video.hlsUrl,
        onError: () => setState(() => _webPlayerFailed = true),
      );
    }
    return _buildExternalPlayerFallback(video, seniorMode);
  }

  Widget _buildContent(VideoDetail video, bool seniorMode) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildPlayer(video, seniorMode),
          ),
          Padding(
            padding: EdgeInsets.all(seniorMode ? AppSpacing.lg : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: AppTypography.serif(
                    fontSize: AppTypography.size(AppTypography.title, seniorMode: seniorMode),
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
                                  fontSize: AppTypography.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              EngagementIconButton(
                                icon: video.isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: video.isLiked
                                    ? AppColors.gold
                                    : AppColors.fog,
                                count: video.likeCount,
                                onTap: _toggleLike,
                                seniorMode: true,
                              ),
                              EngagementIconButton(
                                icon: video.isBookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: video.isBookmarked
                                    ? AppColors.gold
                                    : AppColors.fog,
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
                            style: TextStyle(
                              color: AppColors.fog,
                              fontSize: AppTypography.caption,
                            ),
                          ),
                          const Spacer(),
                          EngagementIconButton(
                            icon: video.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: video.isLiked
                                ? AppColors.gold
                                : AppColors.fog,
                            count: video.likeCount,
                            onTap: _toggleLike,
                            seniorMode: false,
                          ),
                          const SizedBox(width: 8),
                          EngagementIconButton(
                            icon: video.isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: video.isBookmarked
                                ? AppColors.gold
                                : AppColors.fog,
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
                      fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
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
          fontSize: AppTypography.size(AppTypography.micro, seniorMode: seniorMode),
          color: AppColors.gold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
