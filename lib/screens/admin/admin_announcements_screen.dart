// 官方公告：最近 50 則已發布的公告，右上角新增。點一則看內文與圖片。
// 規格：Truku_backend 說明文件/API/收件匣與申訴.md §5。
//
// 圖片是限時網址（約 15 分鐘），不存到本機；過期後下拉重新整理拿新的。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/date_format.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/ephemeral_network_image.dart';
import '../../shared/widgets/truku_empty_state.dart';
import 'admin_announcement_form_screen.dart';
import 'admin_error.dart';
import 'widgets/admin_widgets.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  List<AdminAnnouncement> _items = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final items = await AdminService.fetchAnnouncements();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (handleAdminError(context, e, toast: false)) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final created = await pushAdmin<bool>(
      context,
      const AdminAnnouncementFormScreen(),
    );
    if ((created ?? false) && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: '官方公告',
    actions: [
      IconButton(
        tooltip: '新增公告',
        onPressed: _create,
        icon: const Icon(Icons.add, color: AppColors.primary),
      ),
    ],
    body: (context, senior) {
      if (_loading) return const TrukuLoadingView();
      if (_error != null) {
        return TrukuErrorView(
          error: _error,
          onRetry: _load,
          seniorMode: senior,
        );
      }
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xl),
                child: TrukuEmptyState(
                  icon: Icons.campaign_outlined,
                  message: '還沒有發布過公告',
                  subtitle: '按右上角的＋發布第一則。',
                  seniorMode: senior,
                  scrollable: false,
                ),
              ),
            for (final item in _items)
              AdminCard(
                seniorMode: senior,
                onTap: () =>
                    pushAdmin(context, AdminAnnouncementDetailScreen(item)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTypography.titleStyle(
                        seniorMode: senior,
                        color: AppColors.ink,
                      ),
                    ),
                    if (item.createdAt != null)
                      AdminInfoRow(
                        '發布時間',
                        formatDateTime(item.createdAt!),
                        seniorMode: senior,
                      ),
                    AdminInfoRow(
                      '發布人',
                      item.createdByNickname ?? '—',
                      seniorMode: senior,
                    ),
                    AdminInfoRow(
                      '收件人數',
                      '${item.recipients} 人',
                      seniorMode: senior,
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// 已發布公告的內文與圖片。
class AdminAnnouncementDetailScreen extends StatelessWidget {
  final AdminAnnouncement announcement;

  const AdminAnnouncementDetailScreen(this.announcement, {super.key});

  @override
  Widget build(BuildContext context) {
    final imageUrl = announcement.imageUrl;
    return AdminScaffold(
      title: '公告內容',
      body: (context, senior) => ListView(
        padding: const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, 32),
        children: [
          Text(
            announcement.title,
            style: AppTypography.headlineStyle(
              seniorMode: senior,
              color: AppColors.ink,
            ),
          ),
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            EphemeralNetworkImage(
              url: imageUrl,
              fit: BoxFit.fitWidth,
              failedHint: '圖片載入失敗，請回列表下拉重新整理',
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SelectableText(
            announcement.body,
            style: AppTypography.bodyLargeStyle(
              seniorMode: senior,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
