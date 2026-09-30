// 處置詳情：自己被處置的內容、理由、狀態與處罰，以及申訴。
// 規格：Truku_backend 說明文件/API/收件匣與申訴.md §3。
//
// 入口：收件匣的審核通知、審核推播。被鎖（唯讀）帳號也能開這頁、提出申訴，
// 所以這裡不走唯讀提示。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_format.dart';
import '../../models/moderation_case_models.dart';
import '../../services/moderation_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/utils/utf16_length_limit.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/async_state_view.dart';
import '../forum/forum_theme.dart';

const _appealMin = 10;
const _appealMax = 1000;

String _profileFieldLabel(String key) => switch (key) {
  'video_nickname' => '暱稱',
  'self_intro' => '自我介紹',
  'avatar_url' || 'avatar_id' || 'avatar' => '頭像',
  _ => key,
};

class ModerationCaseScreen extends StatefulWidget {
  final int caseId;

  const ModerationCaseScreen({super.key, required this.caseId});

  static String routeNameFor(int caseId) => 'moderation/case/$caseId';

  /// 所有呼叫端都走這個工廠，settings.name 才會一致（推播導頁靠它判斷是否已開著）。
  static Route<void> route(int caseId) => MaterialPageRoute<void>(
    settings: RouteSettings(name: routeNameFor(caseId)),
    builder: (_) => ModerationCaseScreen(caseId: caseId),
  );

  /// 開著的詳情頁的重載函式，以所在的 route 為 key。
  static final Map<Route<dynamic>, VoidCallback> _live = {};

  /// 點審核通知時人已在 [route] 這份詳情頁：就地重載（例如申訴結果出來了）。
  static void refreshRoute(Route<dynamic> route) => _live[route]?.call();

  @override
  State<ModerationCaseScreen> createState() => _ModerationCaseScreenState();
}

class _ModerationCaseScreenState extends State<ModerationCaseScreen> {
  final _reason = TextEditingController();
  MyModerationCase? _case;
  bool _loading = true;
  String? _error;

  /// 申訴表單是否展開。
  bool _appealing = false;
  bool _submitting = false;

  Route<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && _route == null) {
      _route = route;
      ModerationCaseScreen._live[route] = _load;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    final route = _route;
    if (route != null) ModerationCaseScreen._live.remove(route);
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ModerationService.fetchCase(widget.caseId);
      if (!mounted) return;
      setState(() {
        _case = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException && e.code == 'CASE_NOT_FOUND'
            ? '找不到這筆處置紀錄'
            : apiErrorMessage(e, fallback: '載入失敗，請稍後再試');
        _loading = false;
      });
    }
  }

  bool get _reasonValid => _reason.text.trim().length >= _appealMin;

  Future<void> _submitAppeal() async {
    final current = _case;
    final reason = _reason.text.trim();
    if (current == null || _submitting || !_reasonValid) return;
    if (!withinUtf16Limit(context, reason, _appealMax, label: '申訴理由')) return;
    setState(() => _submitting = true);
    try {
      final appeal = await ModerationService.appeal(current.id, reason);
      if (!mounted) return;
      setState(() {
        _case = current.withAppeal(appeal);
        _appealing = false;
        _submitting = false;
      });
      _toast('申訴已送出');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(apiErrorMessage(e, fallback: '送出失敗，請稍後再試'));
      // 已申訴過、已逾期或已撤銷：畫面上的狀態過時了，重抓。
      if (e is ApiException && e.statusCode == 409) _load();
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: seniorModeController,
    builder: (context, _) => Theme(
      data: forumTheme(context),
      child: _buildScaffold(seniorModeController.enabled),
    ),
  );

  Widget _buildScaffold(bool seniorMode) => Scaffold(
    backgroundColor: AppColors.creamLight,
    appBar: AppBar(
      leading: const AppBackButton(),
      backgroundColor: AppColors.creamLight,
      elevation: 0,
      foregroundColor: AppColors.ink,
      title: Text(
        '處置詳情',
        style: AppTypography.titleStyle(
          seniorMode: seniorMode,
          color: AppColors.ink,
        ),
      ),
    ),
    body: SafeArea(child: _buildBody(seniorMode)),
  );

  Widget _buildBody(bool seniorMode) {
    if (_loading) return const TrukuLoadingView();
    final current = _case;
    if (_error != null || current == null) {
      return TrukuErrorView(
        message: _error ?? '載入失敗，請稍後再試',
        onRetry: _load,
        seniorMode: seniorMode,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        _section(seniorMode, '處置狀態', [
          _row(seniorMode, '對象', moderationTargetLabel(current.targetType)),
          _row(seniorMode, '狀態', moderationCaseStatusLabel(current.status)),
          if (current.openedAt != null)
            _row(seniorMode, '處置時間', formatDateTime(current.openedAt!)),
          _row(seniorMode, '理由', current.reason.isEmpty ? '—' : current.reason),
        ]),
        if (!current.preview.isEmpty)
          _section(seniorMode, '被處置的內容', _previewRows(current, seniorMode)),
        if (current.penalty != null)
          _section(
            seniorMode,
            '處罰',
            _penaltyRows(current.penalty!, seniorMode),
          ),
        _appealSection(current, seniorMode),
      ],
    );
  }

  List<Widget> _previewRows(MyModerationCase c, bool seniorMode) {
    final preview = c.preview;
    return [
      if (preview.title != null) _quote(seniorMode, preview.title!),
      if (preview.body != null && preview.body!.isNotEmpty)
        _quote(seniorMode, preview.body!),
      if (preview.time != null)
        _row(
          seniorMode,
          c.targetType == 'call' ? '通話時間' : '傳送時間',
          formatDateTime(preview.time!),
        ),
      if (preview.profileBefore.isNotEmpty) ...[
        Text(
          '被重設前的內容',
          style: AppTypography.captionStyle(
            seniorMode: seniorMode,
            color: AppColors.fog,
          ),
        ),
        for (final entry in preview.profileBefore.entries)
          _row(
            seniorMode,
            _profileFieldLabel(entry.key),
            // 頭像是圖片網址，列出來沒有意義，只說明被重設了。
            _profileFieldLabel(entry.key) == '頭像'
                ? '已重設為預設頭像'
                : '${entry.value ?? '（空）'}',
          ),
      ],
    ];
  }

  List<Widget> _penaltyRows(MyPenalty p, bool seniorMode) => [
    if (p.strikeNumber != null)
      _row(seniorMode, '違規次數', '第 ${p.strikeNumber} 次違規'),
    if (p.muteUntil != null)
      _row(
        seniorMode,
        '禁言',
        p.muteLifted
            ? '已解除（原訂到 ${formatDateTime(p.muteUntil!)}）'
            : '到 ${formatDateTime(p.muteUntil!)}',
      ),
    _row(seniorMode, '停權', p.locked ? '帳號已停權' : '沒有停權'),
  ];

  Widget _appealSection(MyModerationCase c, bool seniorMode) {
    final appeal = c.appeal;
    if (appeal != null) {
      return _section(seniorMode, '申訴', [
        _row(seniorMode, '狀態', appealStatusLabel(appeal.status)),
        if (appeal.createdAt != null)
          _row(seniorMode, '送出時間', formatDateTime(appeal.createdAt!)),
        _row(seniorMode, '申訴理由', appeal.reason),
        if (appeal.reply != null && appeal.reply!.isNotEmpty)
          _row(seniorMode, '管理員回覆', appeal.reply!),
      ]);
    }
    if (!c.canAppeal) return const SizedBox.shrink();
    final deadline = c.appealDeadline;
    return _section(seniorMode, '申訴', [
      if (deadline != null) _row(seniorMode, '申訴期限', formatDateTime(deadline)),
      const SizedBox(height: 4),
      if (!_appealing)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _appealing = true),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(
              '對處置有疑問？提出申訴',
              style: AppTypography.bodyLargeStyle(
                seniorMode: seniorMode,
                color: AppColors.primary,
              ),
            ),
          ),
        )
      else ...[
        Text(
          '每個處置只能申訴一次，請說明你認為處置有誤的原因（$_appealMin～$_appealMax 字）。',
          style: AppTypography.bodyStyle(
            seniorMode: seniorMode,
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _reason,
          maxLines: 5,
          minLines: 3,
          enabled: !_submitting,
          inputFormatters: const [
            Utf16LengthLimitingTextInputFormatter(_appealMax),
          ],
          buildCounter: utf16CounterBuilder(_reason, _appealMax),
          onChanged: (_) => setState(() {}),
          style: AppTypography.bodyLargeStyle(
            seniorMode: seniorMode,
            color: AppColors.ink,
          ),
          decoration: const InputDecoration(
            hintText: '申訴理由',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() => _appealing = false),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: _submitting || !_reasonValid ? null : _submitAppeal,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.creamLight,
                ),
                child: const Text('送出申訴'),
              ),
            ),
          ],
        ),
      ],
    ]);
  }

  Widget _section(bool seniorMode, String title, List<Widget> children) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: AppSpacing.sm),
        padding: EdgeInsets.all(seniorMode ? AppSpacing.md : 14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.subtitleStyle(
                seniorMode: seniorMode,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      );

  Widget _row(bool seniorMode, String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label：',
            style: AppTypography.bodyStyle(
              seniorMode: seniorMode,
              color: AppColors.fog,
            ),
          ),
          TextSpan(
            text: value,
            style: AppTypography.bodyStyle(
              seniorMode: seniorMode,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _quote(bool seniorMode, String text) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.creamLight,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Text(
      text,
      style: AppTypography.bodyLargeStyle(
        seniorMode: seniorMode,
        color: AppColors.inkSoft,
      ),
    ),
  );
}
