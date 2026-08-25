import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../services/event_service.dart';
import '../../services/senior_mode_controller.dart';

/// 發送提醒表單，送出時呼叫 POST /api/events/:id/reminders。
///
/// 發起人填「訊息內容」與「發送時間」，送出後由後端排程於指定時間
/// 推播給該活動所有參加者。時間選「立即發送」= 帶現在時間，後端下一輪派送即送出。
class ReminderComposeScreen extends StatefulWidget {
  final int eventId;
  final String eventTitle;

  const ReminderComposeScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<ReminderComposeScreen> createState() => _ReminderComposeScreenState();
}

class _ReminderComposeScreenState extends State<ReminderComposeScreen> {
  final _controller = TextEditingController();
  DateTime? _scheduledAt; // null = 立即發送
  bool _sendNow = true;
  bool _submitting = false;

  static const _maxLen = 500;

  // 常用訊息範本，點一下帶入
  static const _templates = [
    '別忘了明天的活動，記得準時到！',
    '活動時間有更動，請留意最新資訊。',
    '名額即將額滿，還沒報名的把握機會！',
    '請記得攜帶個人餐具，一起做環保。',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: '選擇發送日期',
    );
    if (date == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduledAt ?? now.add(const Duration(hours: 1)),
      ),
      helpText: '選擇發送時間',
    );
    if (t == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        t.hour,
        t.minute,
      );
      _sendNow = false;
    });
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final msg = _controller.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先輸入提醒訊息')));
      return;
    }
    if (!_sendNow && _scheduledAt == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇發送時間')));
      return;
    }
    if (!_sendNow &&
        _scheduledAt != null &&
        _scheduledAt!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('發送時間不能早於現在')));
      return;
    }

    setState(() => _submitting = true);
    try {
      await EventService.createReminder(
        widget.eventId,
        message: msg,
        scheduledAt: _sendNow ? null : _scheduledAt,
      );
      if (!mounted) return;
      final whenText = _sendNow
          ? '立即發送'
          : '排定於 ${_formatDateTime(_scheduledAt!)}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('提醒已建立 — $whenText')));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('建立提醒失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) =>
          _buildScaffold(context, seniorModeController.enabled),
    );
  }

  Widget _buildScaffold(BuildContext context, bool seniorMode) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(seniorMode),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  _buildTargetInfo(seniorMode),
                  const SizedBox(height: 22),
                  _sectionLabel('提醒訊息', seniorMode),
                  const SizedBox(height: 8),
                  _buildMessageField(seniorMode),
                  const SizedBox(height: 10),
                  _buildTemplates(seniorMode),
                  const SizedBox(height: 24),
                  _sectionLabel('發送時間', seniorMode),
                  const SizedBox(height: 8),
                  _buildTimeSelector(seniorMode),
                ],
              ),
            ),
            _buildSendBar(seniorMode),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool seniorMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            iconSize: seniorMode ? 30 : 24,
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '發送提醒',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: seniorMode ? 26 : 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  widget.eventTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: seniorMode ? AppTypography.subtitle : 12,
                    color: AppColors.fog,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetInfo(bool seniorMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.groups_outlined,
            size: seniorMode ? 26 : 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '提醒將推播給此活動的所有參加者',
              style: TextStyle(
                fontSize: seniorMode ? AppTypography.title : 12.5,
                color: AppColors.inkSoft,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, bool seniorMode) {
    return Text(
      text,
      style: GoogleFonts.notoSerifTc(
        fontSize: seniorMode ? AppTypography.subtitle : 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildMessageField(bool seniorMode) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.creamDeep),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: _controller,
            maxLines: 4,
            maxLength: _maxLen,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              fontSize: seniorMode ? AppTypography.title : 14,
              color: AppColors.ink,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: '輸入要提醒參加者的內容…',
              hintStyle: TextStyle(
                color: AppColors.fog,
                fontSize: seniorMode ? AppTypography.title : 14,
              ),
              border: InputBorder.none,
              counterText: '',
            ),
          ),
          Text(
            '${_controller.text.characters.length} / $_maxLen',
            style: TextStyle(
              fontSize: seniorMode ? AppTypography.body : 11,
              color: AppColors.fog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplates(bool seniorMode) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _templates.map((t) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _controller.text = t;
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: t.length),
              );
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: seniorMode ? 12 : 7,
            ),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.creamDeep),
            ),
            child: Text(
              t,
              style: TextStyle(
                fontSize: seniorMode ? AppTypography.subtitle : 11.5,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeSelector(bool seniorMode) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _timeOption(
                label: '立即發送',
                selected: _sendNow,
                seniorMode: seniorMode,
                onTap: () => setState(() {
                  _sendNow = true;
                  _scheduledAt = null;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _timeOption(
                label: '指定時間',
                selected: !_sendNow,
                seniorMode: seniorMode,
                onTap: _pickDateTime,
              ),
            ),
          ],
        ),
        if (!_sendNow && _scheduledAt != null) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickDateTime,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.creamDeep),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event,
                    size: seniorMode ? 24 : 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _formatDateTime(_scheduledAt!),
                      style: TextStyle(
                        fontSize: seniorMode ? AppTypography.title : 14,
                        color: AppColors.ink,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    '更改',
                    style: TextStyle(
                      fontSize: seniorMode ? AppTypography.subtitle : 12,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '※ 系統每分鐘檢查一次，實際送達可能有約 1 分鐘誤差。',
          style: TextStyle(
            fontSize: seniorMode ? AppTypography.body : 11,
            color: AppColors.fog,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _timeOption({
    required String label,
    required bool selected,
    required bool seniorMode,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: seniorMode ? 18 : 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.creamDeep,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: seniorMode ? AppTypography.subtitle : 13.5,
              color: selected ? AppColors.creamLight : AppColors.inkSoft,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSendBar(bool seniorMode) {
    final hasMsg = _controller.text.trim().isNotEmpty;
    final enabled = hasMsg && !_submitting;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.creamLight,
        border: Border(top: BorderSide(color: AppColors.creamDeep)),
      ),
      child: GestureDetector(
        onTap: enabled ? _submit : null,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: seniorMode ? 20 : 15),
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.primary
                : AppColors.fog.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.creamLight,
                    ),
                  )
                : Text(
                    _sendNow ? '立即發送提醒' : '排定發送',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: seniorMode ? AppTypography.title : 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                      letterSpacing: 2.0,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
