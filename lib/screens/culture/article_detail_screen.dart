import 'package:flutter/material.dart';
import '../../core/utils/date_format.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/article_models.dart';
import '../../services/account_lock_controller.dart';
import '../../services/admin_service.dart';
import '../../services/article_refresh_notifier.dart';
import '../../services/article_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../admin/admin_article_form_screen.dart';
import '../admin/admin_error.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/engagement_icon_button.dart';
import '../../shared/widgets/app_back_button.dart';
import 'widgets/article_markdown.dart';

class ArticleDetailScreen extends StatefulWidget {
  final int articleId;
  const ArticleDetailScreen({super.key, required this.articleId});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late Future<void> _future;
  ArticleDetail? _article;
  Object? _error;
  bool _likeBusy = false;

  /// 下架送出中：管理員選單停用，連點只送一次。
  bool _archiving = false;
  bool _bookmarkBusy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _load() async {
    try {
      _article = await ArticleService.fetchArticleDetail(widget.articleId);
    } catch (e) {
      _error = e;
    }
    // AppBar 的管理員選單要等文章載入完才決定顯示，FutureBuilder 只會重畫內文。
    if (mounted) setState(() {});
  }

  bool get _isAdmin => UserService.cachedUser?.isAdmin ?? false;

  /// 管理員編輯這篇文章：存好後重新載入詳情，文化頁列表一併重抓。
  Future<void> _adminEdit() async {
    final article = _article;
    if (article == null) return;
    final saved = await pushAdmin<bool>(
      context,
      AdminArticleFormScreen(editing: article),
    );
    if (saved != true || !mounted) return;
    ArticleRefreshNotifier.bump();
    setState(() {
      _error = null;
      _future = _load();
    });
  }

  /// 管理員下架這篇文章。下架後 App 內找不回來，所以給一次「復原」的機會（重新發布）。
  Future<void> _adminArchive() async {
    final article = _article;
    if (article == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '下架「${article.title}」？',
      message: '下架後使用者看不到這篇文章，也無法在 App 內找回。',
      confirmText: '下架',
    );
    if (!confirmed || !mounted || _archiving) return;
    setState(() => _archiving = true);
    try {
      await AdminService.archiveArticle(article.id);
    } catch (e) {
      if (mounted) handleAdminError(context, e);
      return;
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
    ArticleRefreshNotifier.bump();
    showAdminMessage(
      '已下架',
      action: (
        label: '復原',
        onPressed: () async {
          try {
            await AdminService.publishArticle(article.id);
            ArticleRefreshNotifier.bump();
            showAdminMessage('已重新發布');
          } catch (e) {
            showAdminMessage(apiErrorMessage(e));
          }
        },
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  /// 樂觀更新，API 回傳真實計數後校正；失敗則還原。
  Future<void> _toggleLike() async {
    final article = _article;
    if (article == null || _likeBusy) return;
    // 唯讀帳號只擋「按讚」，取消讚後端放行。
    if (!article.isLiked && blockIfReadOnly()) return;
    setState(() {
      _likeBusy = true;
      _article = article.toggledLike();
    });
    try {
      final result = await ArticleService.likeArticle(
        widget.articleId,
        like: !article.isLiked,
      );
      if (!mounted) return;
      setState(() {
        _article = _article!.withLikeResult(
          liked: result.liked,
          likeCount: result.likeCount,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _article = article);
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  Future<void> _toggleBookmark() async {
    final article = _article;
    if (article == null || _bookmarkBusy) return;
    setState(() {
      _bookmarkBusy = true;
      _article = article.toggledBookmark();
    });
    try {
      await ArticleService.bookmarkArticle(
        widget.articleId,
        add: !article.isBookmarked,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _article = article);
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
        actions: [
          if (_isAdmin && _article != null)
            PopupMenuButton<String>(
              enabled: !_archiving,
              onSelected: (value) {
                if (value == 'edit') _adminEdit();
                if (value == 'archive') _adminArchive();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('編輯')),
                PopupMenuItem(value: 'archive', child: Text('下架')),
              ],
            ),
        ],
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
          return _buildContent(_article!, seniorMode);
        },
      ),
    );
  }

  Widget _buildError(Object? error, bool seniorMode) {
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

  Widget _buildContent(ArticleDetail article, bool seniorMode) {
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
            padding: EdgeInsets.all(seniorMode ? AppSpacing.lg : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
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
                          _tag(ArticleCategory.label(article.category), true),
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
                                '${article.viewCount}',
                                style: TextStyle(
                                  color: AppColors.fog,
                                  fontSize: AppTypography.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                          if (article.publishedAt != null)
                            Text(
                              formatDate(article.publishedAt!),
                              style: TextStyle(
                                color: AppColors.fog,
                                fontSize: AppTypography.bodyLarge,
                              ),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              EngagementIconButton(
                                icon: article.isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: article.isLiked
                                    ? AppColors.gold
                                    : AppColors.fog,
                                count: article.likeCount,
                                onTap: _toggleLike,
                                seniorMode: true,
                              ),
                              EngagementIconButton(
                                icon: article.isBookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: article.isBookmarked
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
                          _tag(ArticleCategory.label(article.category), false),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.visibility,
                            size: 14,
                            color: AppColors.fog,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${article.viewCount}',
                            style: TextStyle(
                              color: AppColors.fog,
                              fontSize: AppTypography.caption,
                            ),
                          ),
                          if (article.publishedAt != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              formatDate(article.publishedAt!),
                              style: TextStyle(
                                color: AppColors.fog,
                                fontSize: AppTypography.caption,
                              ),
                            ),
                          ],
                          const Spacer(),
                          EngagementIconButton(
                            icon: article.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: article.isLiked
                                ? AppColors.gold
                                : AppColors.fog,
                            count: article.likeCount,
                            onTap: _toggleLike,
                            seniorMode: false,
                          ),
                          const SizedBox(width: 8),
                          EngagementIconButton(
                            icon: article.isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: article.isBookmarked
                                ? AppColors.gold
                                : AppColors.fog,
                            onTap: _toggleBookmark,
                            seniorMode: false,
                          ),
                        ],
                      ),
                const SizedBox(height: 20),
                ArticleMarkdown(
                  data: article.contentMd,
                  seniorMode: seniorMode,
                ),
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
