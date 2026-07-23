import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/history_models.dart';
import '../../services/history_service.dart';
import '../learn/lesson_card_screen.dart';
import 'listening_history_detail_screen.dart';
import 'quiz_history_detail_screen.dart';

const _pageSize = 20;

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _scrollController = ScrollController();
  String? _typeFilter;
  int _page = 1;
  int _total = 0;
  bool _loadingMore = false;
  bool _initialLoading = true;
  Object? _error;
  final List<HistoryRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _records.length >= _total) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    try {
      final result = await HistoryService.fetchHistory(
        type: _typeFilter,
        page: 1,
        pageSize: _pageSize,
      );
      setState(() {
        _records
          ..clear()
          ..addAll(result.records);
        _total = result.total;
        _page = 1;
        _initialLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    setState(() => _loadingMore = true);
    try {
      final result = await HistoryService.fetchHistory(
        type: _typeFilter,
        page: _page + 1,
        pageSize: _pageSize,
      );
      setState(() {
        _records.addAll(result.records);
        _total = result.total;
        _page += 1;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() => _loadingMore = false);
    }
  }

  void _setFilter(String? type) {
    if (_typeFilter == type) return;
    setState(() => _typeFilter = type);
    _loadFirstPage();
  }

  void _onTapRecord(HistoryRecord record) {
    if (record.isCompleted) {
      if (record.isListening) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ListeningHistoryDetailScreen(
              sessionId: record.sessionId,
              level: record.level,
              modeLabel: record.modeLabel,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuizHistoryDetailScreen(
              sessionId: record.sessionId,
              level: record.level,
            ),
          ),
        );
      }
      return;
    }

    // 進行中
    if (record.isListening) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('尚未支援'),
          content: const Text('聽力測驗尚未支援於 App 內續接，請留意後續更新。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('了解'),
            ),
          ],
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LessonCardScreen(level: record.level)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: Text(
          '測驗紀錄',
          style: GoogleFonts.notoSerifTc(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final options = [
      (label: '全部', value: null),
      (label: '單字學習', value: 'quiz'),
      (label: '聽力測驗', value: 'listening'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          for (final option in options) ...[
            _FilterChip(
              label: option.label,
              selected: _typeFilter == option.value,
              onTap: () => _setFilter(option.value),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      final isUnauthorized = _error is ApiException && (_error as ApiException).isUnauthorized;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isUnauthorized ? '請先登入' : '載入失敗，請稍後再試',
                style: GoogleFonts.notoSerifTc(fontSize: 15, color: AppColors.ink),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFirstPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.creamLight,
                ),
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }
    if (_records.isEmpty) {
      return Center(
        child: Text(
          '目前沒有測驗紀錄',
          style: GoogleFonts.notoSansTc(fontSize: 14, color: AppColors.fog),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _records.length + 1,
        itemBuilder: (context, index) {
          if (index == _records.length) {
            if (!_loadingMore) return const SizedBox.shrink();
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          final record = _records[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _HistoryRow(record: record, onTap: () => _onTapRecord(record)),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.cream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.creamDeep),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.creamLight : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final HistoryRecord record;
  final VoidCallback onTap;

  const _HistoryRow({required this.record, required this.onTap});

  String _scoreLabel() {
    if (record.isCompleted) {
      return '${record.score ?? 0} / ${record.totalQuestions}';
    }
    return '已答 ${record.answeredCount}/${record.totalQuestions}';
  }

  String _timeLabel() {
    final raw = record.completedAt ?? record.lastActiveAt;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = record.isCompleted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.creamDeep),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _badge(record.typeLabel, AppColors.primary),
                      if (record.modeLabel != null) ...[
                        const SizedBox(width: 6),
                        _badge(record.modeLabel!, AppColors.moss),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    record.level,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record.statusLabel} · ${_timeLabel()}',
                    style: const TextStyle(fontSize: 11, color: AppColors.fog),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _scoreLabel(),
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isCompleted ? AppColors.primary : AppColors.fog,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, color: AppColors.fog, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
