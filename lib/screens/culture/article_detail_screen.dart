import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/article_models.dart';
import '../../services/article_service.dart';

class ArticleDetailScreen extends StatefulWidget {
  final int articleId;
  const ArticleDetailScreen({super.key, required this.articleId});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late Future<ArticleDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = ArticleService.fetchArticleDetail(widget.articleId);
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
      body: FutureBuilder<ArticleDetail>(
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
          final article = snapshot.data!;
          return _buildContent(article);
        },
      ),
    );
  }

  Widget _buildError(Object? error) {
    String message = '發生錯誤，請稍後再試';
    if (error is ApiException) {
      switch (error.code) {
        case 'ARTICLE_NOT_FOUND':
          message = '找不到這篇文章';
          break;
        case 'ARTICLE_ARCHIVED':
          message = '這篇文章已下架';
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

  Widget _buildContent(ArticleDetail article) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.coverImageUrl != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                article.coverImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
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
                    _tag(ArticleCategory.label(article.category)),
                    const SizedBox(width: 8),
                    Icon(Icons.visibility, size: 14, color: AppColors.fog),
                    const SizedBox(width: 4),
                    Text(
                      '${article.viewCount}',
                      style: TextStyle(color: AppColors.fog, fontSize: 12),
                    ),
                    if (article.publishedAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(article.publishedAt!),
                        style: TextStyle(color: AppColors.fog, fontSize: 12),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                MarkdownBody(
                  data: article.contentMd,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      color: AppColors.mist,
                      fontSize: 14,
                      height: 1.6,
                    ),
                    h1: TextStyle(
                      color: AppColors.creamLight,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    h2: TextStyle(
                      color: AppColors.creamLight,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    h3: TextStyle(
                      color: AppColors.creamLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    strong: TextStyle(
                      color: AppColors.creamLight,
                      fontWeight: FontWeight.w600,
                    ),
                    a: TextStyle(color: AppColors.gold),
                    blockquote: TextStyle(color: AppColors.fog),
                    blockquoteDecoration: BoxDecoration(
                      color: AppColors.midnightSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
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

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
