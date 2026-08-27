// 影音搜尋：關鍵字／時間區間／部落，三者皆選填、可任意組合。
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/tribe_model.dart';
import '../../models/video_models.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/video_service.dart';
import '../../shared/search_range.dart';
import '../../shared/widgets/tribe_picker_sheet.dart';
import 'video_detail_screen.dart';

class VideoSearchScreen extends StatefulWidget {
  const VideoSearchScreen({super.key});

  @override
  State<VideoSearchScreen> createState() => _VideoSearchScreenState();
}

class _VideoSearchScreenState extends State<VideoSearchScreen> {
  final _controller = TextEditingController();
  String? _q;
  String? _range;
  Tribe? _tribe;

  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _total = 0;
  List<VideoSummary> _videos = [];
  bool _searched = false;

  bool get _hasMore => _videos.length < _total;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _q = _controller.text.trim();
      _searched = true;
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final res = await VideoService.searchVideos(
        q: _q,
        range: _range,
        tribeId: _tribe?.id,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _videos = res.videos;
        _total = res.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : '搜尋失敗，請稍後再試';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await VideoService.searchVideos(
        q: _q,
        range: _range,
        tribeId: _tribe?.id,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _videos = [..._videos, ...res.videos];
        _page += 1;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _pickTribe() async {
    final tribe = await showModalBottomSheet<Tribe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TribePickerSheet(),
    );
    if (tribe == null) return;
    setState(() => _tribe = tribe.id == kClearTribeId ? null : tribe);
    _search();
  }

  void _setRange(String? range) {
    setState(() => _range = _range == range ? null : range);
    _search();
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
        elevation: 0,
        foregroundColor: AppColors.creamLight,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: TextStyle(
            color: AppColors.creamLight,
            fontSize: seniorMode ? AppTypography.title : null,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: '搜尋影片',
            hintStyle: TextStyle(
              color: AppColors.fog,
              fontSize: seniorMode ? AppTypography.title : null,
            ),
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _search,
            icon: Icon(
              Icons.search,
              color: AppColors.gold,
              size: seniorMode ? 30 : null,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _filterRow(seniorMode),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _error!,
                style: TextStyle(
                  color: AppColors.fog,
                  fontSize: seniorMode ? AppTypography.title : null,
                ),
              ),
            ),
          if (!_searched && _error == null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                '輸入關鍵字或選擇篩選條件開始搜尋',
                style: GoogleFonts.notoSerifTc(
                  color: AppColors.fog,
                  fontSize: seniorMode ? AppTypography.title : null,
                ),
              ),
            ),
          if (_searched) Expanded(child: _resultList(seniorMode)),
        ],
      ),
    );
  }

  Widget _filterRow(bool seniorMode) {
    return SizedBox(
      height: seniorMode ? 64 : 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final r in SearchRange.values) _rangeChip(r, seniorMode),
          const SizedBox(width: 4),
          _tribeChip(seniorMode),
        ],
      ),
    );
  }

  Widget _rangeChip(String range, bool seniorMode) {
    final selected = _range == range;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
      child: ChoiceChip(
        label: Text(SearchRange.label(range)),
        selected: selected,
        showCheckmark: false,
        backgroundColor: AppColors.midnightSoft,
        selectedColor: AppColors.gold.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          fontSize: seniorMode ? AppTypography.subtitle : 12,
          color: selected ? AppColors.gold : AppColors.fog,
        ),
        side: BorderSide(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.5)
              : AppColors.cream.withValues(alpha: 0.15),
        ),
        onSelected: (_) => _setRange(range),
      ),
    );
  }

  Widget _tribeChip(bool seniorMode) {
    final selected = _tribe != null;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: ActionChip(
        avatar: Icon(
          Icons.place_outlined,
          size: seniorMode ? 22 : 16,
          color: selected ? AppColors.gold : AppColors.fog,
        ),
        label: Text(_tribe?.name ?? '部落'),
        backgroundColor: AppColors.midnightSoft,
        labelStyle: TextStyle(
          fontSize: seniorMode ? AppTypography.subtitle : 12,
          color: selected ? AppColors.gold : AppColors.fog,
        ),
        side: BorderSide(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.5)
              : AppColors.cream.withValues(alpha: 0.15),
        ),
        onPressed: _pickTribe,
      ),
    );
  }

  Widget _resultList(bool seniorMode) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (_videos.isEmpty) {
      return Center(
        child: Text(
          '找不到符合的影片',
          style: TextStyle(
            color: AppColors.fog,
            fontSize: seniorMode ? AppTypography.title : null,
          ),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 200) _loadMore();
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _videos.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i >= _videos.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            );
          }
          final v = _videos[i];
          return _VideoResultTile(video: v, seniorMode: seniorMode);
        },
      ),
    );
  }
}

class _VideoResultTile extends StatelessWidget {
  final VideoSummary video;
  final bool seniorMode;
  const _VideoResultTile({required this.video, required this.seniorMode});

  @override
  Widget build(BuildContext context) {
    final thumbWidth = seniorMode ? 100.0 : 72.0;
    final thumbHeight = seniorMode ? 68.0 : 48.0;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoDetailScreen(videoId: video.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.midnightSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cream.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: thumbWidth,
              height: thumbHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [AppColors.moss, AppColors.mossDeep],
                ),
              ),
              child: video.thumbnailUrl != null
                  ? Image.network(video.thumbnailUrl!, fit: BoxFit.cover)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: seniorMode ? AppTypography.title : 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (!seniorMode)
                    Text(
                      '${VideoCategory.label(video.category)} · ${video.viewCount} 次觀看',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.fog,
                      ),
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
