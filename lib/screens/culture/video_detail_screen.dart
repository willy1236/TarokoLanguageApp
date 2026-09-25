import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../core/platform/platform_features.dart';
import '../../models/video_models.dart';
import '../../services/account_lock_controller.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/video_service.dart';
import '../../shared/widgets/engagement_icon_button.dart';
import '../../shared/widgets/hls_web_player/hls_web_player.dart';
import '../../shared/widgets/app_back_button.dart';

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

  /// YouTube 影片且可嵌入時的官方播放器；依 YouTube 條款不可遮蓋其標誌或廣告。
  YoutubePlayerController? _youtubeController;
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
      if (detail.isYoutube) {
        // 擁有者關閉嵌入或平台沒有播放器實作時不建 controller，改外開 watch_url。
        final youtube = detail.youtube;
        if (youtube != null &&
            youtube.embeddable &&
            PlatformFeatures.supportsYoutubeEmbed) {
          _youtubeController = YoutubePlayerController.fromVideoId(
            videoId: youtube.videoId,
            autoPlay: true,
            params: const YoutubePlayerParams(showFullscreenButton: true),
          );
        }
        _video = detail;
        return;
      }
      // better_player_plus 只有行動平台實作，其他平台改顯示外開連結。
      final hlsUrl = detail.hlsUrl;
      if (!PlatformFeatures.supportsHlsPlayer || hlsUrl == null) {
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
          hlsUrl,
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
    _youtubeController?.close();
    super.dispose();
  }

  /// 樂觀更新，API 回傳真實計數後校正；失敗則還原。
  Future<void> _toggleLike() async {
    final video = _video;
    if (video == null || _likeBusy) return;
    // 唯讀帳號只擋「按讚」，取消讚後端放行。
    if (!video.isLiked && blockIfReadOnly()) return;
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
        leading: const AppBackButton(onDark: true),
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
                fontSize: AppTypography.size(
                  AppTypography.bodyLarge,
                  seniorMode: seniorMode,
                ),
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

  /// 無法內嵌播放時：提示並提供外開連結（HLS 串流網址或 YouTube watch_url）。
  Widget _buildExternalPlayerFallback({
    required String message,
    required String buttonLabel,
    required String? url,
    required bool seniorMode,
  }) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyStyle(
                seniorMode: seniorMode,
                color: Colors.white,
              ),
            ),
            if (url != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.open_in_new),
                label: Text(buttonLabel),
                onPressed: () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// YouTube：可嵌入且平台支援時用官方播放器，否則外開 watch_url（系統瀏覽器
  /// 或 YouTube App）。
  /// HLS：手機走 better_player_plus；Web 走 `<video>` + hls.js，播放失敗再退回
  /// 外開連結；其餘平台（桌面）直接顯示外開連結。
  Widget _buildPlayer(VideoDetail video, bool seniorMode) {
    if (video.isYoutube) {
      final controller = _youtubeController;
      if (controller != null) return YoutubePlayer(controller: controller);
      final embeddable = video.youtube?.embeddable ?? false;
      return _buildExternalPlayerFallback(
        message: embeddable ? '此平台暫不支援內嵌播放' : '影片擁有者未開放在 App 內播放',
        buttonLabel: '在 YouTube 開啟',
        url: video.youtube?.watchUrl,
        seniorMode: seniorMode,
      );
    }
    if (_playerController != null) {
      return BetterPlayer(controller: _playerController!);
    }
    final hlsUrl = video.hlsUrl;
    if (hlsUrl != null &&
        PlatformFeatures.supportsWebHlsPlayer &&
        !_webPlayerFailed) {
      return HlsWebPlayer(
        url: hlsUrl,
        onError: () => setState(() => _webPlayerFailed = true),
      );
    }
    return _buildExternalPlayerFallback(
      message: hlsUrl == null ? '影片暫時無法播放' : '此平台暫不支援內嵌播放',
      buttonLabel: '在新視窗開啟影片',
      url: hlsUrl,
      seniorMode: seniorMode,
    );
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
                    fontSize: AppTypography.size(
                      AppTypography.title,
                      seniorMode: seniorMode,
                    ),
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
                      fontSize: AppTypography.size(
                        AppTypography.body,
                        seniorMode: seniorMode,
                      ),
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
          fontSize: AppTypography.size(
            AppTypography.micro,
            seniorMode: seniorMode,
          ),
          color: AppColors.gold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
