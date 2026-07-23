import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/history_models.dart';
import '../../services/history_service.dart';
import 'history_review_card.dart';

class QuizHistoryDetailScreen extends StatefulWidget {
  final String sessionId;
  final String level;

  const QuizHistoryDetailScreen({
    super.key,
    required this.sessionId,
    required this.level,
  });

  @override
  State<QuizHistoryDetailScreen> createState() => _QuizHistoryDetailScreenState();
}

class _QuizHistoryDetailScreenState extends State<QuizHistoryDetailScreen> {
  final _player = AudioPlayer();
  late Future<QuizHistoryDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = HistoryService.fetchQuizDetail(widget.sessionId);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<QuizHistoryDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (snapshot.hasError) {
              return _buildError(snapshot.error);
            }
            return _buildContent(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildContent(QuizHistoryDetail detail) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Stack(
          children: [
            ScoreHeader(
              title: '${widget.level} · 單字學習測驗',
              score: detail.score,
              total: detail.total,
            ),
            Positioned(
              left: 8,
              top: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: AppColors.creamLight),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            children: [
              for (final item in detail.results)
                ReviewCard(
                  order: item.order,
                  promptText: item.prompt,
                  promptAudioUrl: item.wordDetail.audioUrl,
                  isCorrect: item.isCorrect,
                  yourAnswerText: item.yourAnswer.text,
                  correctAnswerText: item.correctAnswer.text,
                  detailTitle: '${item.wordDetail.truku} · ${item.wordDetail.zh}',
                  detailSubtitle: item.wordDetail.en,
                  explanation: item.wordDetail.explanation,
                  detailAudioUrl: item.wordDetail.audioUrl,
                  player: _player,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError(Object? error) {
    final isSessionNotFound = error is ApiException && error.isSessionNotFound;
    final isSessionNotCompleted = error is ApiException && error.isSessionNotCompleted;
    final message = isSessionNotFound
        ? '找不到此測驗紀錄'
        : isSessionNotCompleted
            ? '此測驗仍進行中，請至測驗紀錄續接'
            : (error is ApiException ? error.message : '載入失敗，請稍後再試');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSerifTc(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.creamLight,
              ),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}
