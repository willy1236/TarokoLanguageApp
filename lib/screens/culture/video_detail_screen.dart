import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/video_models.dart';
import '../../services/video_service.dart';

class VideoDetailScreen extends StatefulWidget {
  final int videoId;
  const VideoDetailScreen({super.key, required this.videoId});

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  late Future<VideoDetail> _future;
  BetterPlayerController? _playerController;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<VideoDetail> _load() async {
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
    return detail;
  }

  @override
  void dispose() {
    _playerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: AppBar(
        backgroundColor: AppColors.midnight,
        foregroundColor: AppColors.cream,
        elevation: 0,
      ),
      body: FutureBuilder<VideoDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            );
          }
          if (snapshot.hasError) {
            return _buildError(snapshot.error);
          }
          final video = snapshot.data!;
          return _buildContent(video);
        },
      ),
    );
  }

  Widget _buildError(Object? error) {
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
            Icon(Icons.error_outline, color: AppColors.fog, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.cream, fontSize: 15),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('返回清單'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(VideoDetail video) {
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.creamLight,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _tag(VideoCategory.label(video.category)),
                    const SizedBox(width: 8),
                    Icon(Icons.visibility, size: 14, color: AppColors.fog),
                    const SizedBox(width: 4),
                    Text(
                      '${video.viewCount}',
                      style: TextStyle(color: AppColors.fog, fontSize: 12),
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
                      fontSize: 14,
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

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: AppColors.gold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
