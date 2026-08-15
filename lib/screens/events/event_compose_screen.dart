import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/event_service.dart';

/// 發起活動表單，送出時呼叫 EventService.createEvent（POST /api/events）。
///
/// 後端五個必填：標題 / 活動介紹 / 地點名稱 / 詳細地址 / 開始時間（需未來、1 年內）。
/// 聯絡 email、電話為選填。
/// 權限：僅 organizer / admin 角色可發起，一般帳號會收到 403，表單會顯示錯誤訊息。
///
/// 成功時 Navigator.pop(context, true)，呼叫端（活動列表）據此刷新。
class EventComposeScreen extends StatefulWidget {
  const EventComposeScreen({super.key});

  @override
  State<EventComposeScreen> createState() => _EventComposeScreenState();
}

class _EventComposeScreenState extends State<EventComposeScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _maxParticipants = TextEditingController();

  DateTime? _startsAt;
  DateTime? _registrationDeadline;
  String? _category; // 選填，null = 不分類
  bool _submitting = false;
  String? _error;

  // 常用分類（對應活動列表的篩選標籤）；點一下切換，可不選。
  static const _categories = ['族語', '走讀', '工藝', '線上', '音樂', '其他'];

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _location.dispose();
    _address.dispose();
    _email.dispose();
    _phone.dispose();
    _maxParticipants.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: '選擇活動日期',
    );
    if (date == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _startsAt ?? now.add(const Duration(hours: 1)),
      ),
      helpText: '選擇活動時間',
    );
    if (t == null || !mounted) return;
    setState(() {
      _startsAt = DateTime(date.year, date.month, date.day, t.hour, t.minute);
    });
  }

  Future<void> _pickRegistrationDeadline() async {
    final now = DateTime.now();
    final lastDate = _startsAt ?? now.add(const Duration(days: 365));
    final date = await showDatePicker(
      context: context,
      initialDate: _registrationDeadline ?? now,
      firstDate: now,
      lastDate: lastDate.isAfter(now) ? lastDate : now,
      helpText: '選擇報名截止日期',
    );
    if (date == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_registrationDeadline ?? now),
      helpText: '選擇報名截止時間',
    );
    if (t == null || !mounted) return;
    setState(() {
      _registrationDeadline = DateTime(
        date.year,
        date.month,
        date.day,
        t.hour,
        t.minute,
      );
    });
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _error = null);

    final title = _title.text.trim();
    final desc = _desc.text.trim();
    final location = _location.text.trim();
    final address = _address.text.trim();

    if (title.isEmpty || desc.isEmpty || location.isEmpty || address.isEmpty) {
      setState(() => _error = '請填寫所有必填欄位');
      return;
    }
    if (_startsAt == null) {
      setState(() => _error = '請選擇活動開始時間');
      return;
    }
    if (!_startsAt!.isAfter(DateTime.now())) {
      setState(() => _error = '活動時間需為未來');
      return;
    }
    if (_registrationDeadline != null &&
        _registrationDeadline!.isAfter(_startsAt!)) {
      setState(() => _error = '報名截止時間不能晚於活動開始時間');
      return;
    }

    // 名額選填：留空 = 不限；有填須為正整數
    int? maxPeople;
    final maxText = _maxParticipants.text.trim();
    if (maxText.isNotEmpty) {
      maxPeople = int.tryParse(maxText);
      if (maxPeople == null || maxPeople < 1) {
        setState(() => _error = '名額上限需為正整數，或留空表示不限');
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      await EventService.createEvent(
        title: title,
        description: desc,
        location: location,
        address: address,
        startsAt: _startsAt!,
        registrationDeadline: _registrationDeadline,
        contactEmail: _email.text,
        contactPhone: _phone.text,
        maxParticipants: maxPeople,
        category: _category,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('活動已發起')));
      Navigator.pop(context, true); // 通知列表刷新
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString(); // 後端訊息，例如「需要活動主辦權限（organizer / admin）」
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  _label('標題', required: true),
                  _textField(_title, hint: '例如：青年族語營', maxLength: 100),
                  const SizedBox(height: 18),
                  _label('活動介紹', required: true),
                  _textField(
                    _desc,
                    hint: '介紹活動內容、流程、注意事項…',
                    maxLines: 4,
                    maxLength: 2000,
                  ),
                  const SizedBox(height: 18),
                  _label('地點名稱', required: true),
                  _textField(_location, hint: '例如：秀林部落活動中心', maxLength: 200),
                  const SizedBox(height: 18),
                  _label('詳細地址', required: true),
                  _textField(_address, hint: '例如：花蓮縣秀林鄉…', maxLength: 200),
                  const SizedBox(height: 18),
                  _label('開始時間', required: true),
                  _buildDateField(value: _startsAt, onTap: _pickDateTime),
                  const SizedBox(height: 18),
                  _label('報名截止時間', required: false),
                  _buildDateField(
                    value: _registrationDeadline,
                    onTap: _pickRegistrationDeadline,
                    placeholder: '選擇日期與時間（選填）',
                  ),
                  const SizedBox(height: 18),
                  _label('名額上限', required: false),
                  _textField(
                    _maxParticipants,
                    hint: '留空 = 不限名額',
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                  const SizedBox(height: 18),
                  _label('分類', required: false),
                  _buildCategoryChips(),
                  const SizedBox(height: 18),
                  _label('聯絡 Email', required: false),
                  _textField(
                    _email,
                    hint: '選填',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 18),
                  _label('聯絡電話', required: false),
                  _textField(
                    _phone,
                    hint: '選填',
                    keyboardType: TextInputType.phone,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorBox(_error!),
                  ],
                ],
              ),
            ),
            _buildSubmitBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          ),
          Text(
            '發起活動',
            style: GoogleFonts.notoSerifTc(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, {required bool required}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            text,
            style: GoogleFonts.notoSerifTc(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              letterSpacing: 1.0,
            ),
          ),
          if (required)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                '*',
                style: TextStyle(fontSize: 14, color: AppColors.primary),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                '選填',
                style: TextStyle(fontSize: 11, color: AppColors.fog),
              ),
            ),
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController c, {
    required String hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.creamDeep),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.fog, fontSize: 14),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required DateTime? value,
    required VoidCallback onTap,
    String placeholder = '選擇日期與時間',
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Row(
          children: [
            const Icon(Icons.event, size: 16, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              value == null ? placeholder : _formatDateTime(value),
              style: TextStyle(
                fontSize: 14,
                color: value == null ? AppColors.fog : AppColors.ink,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((c) {
        final selected = _category == c;
        return GestureDetector(
          onTap: () => setState(() => _category = selected ? null : c),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.creamDeep,
              ),
            ),
            child: Text(
              c,
              style: TextStyle(
                fontSize: 13,
                color: selected ? AppColors.creamLight : AppColors.inkSoft,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 16,
            color: AppColors.dangerDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.dangerDark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.creamLight,
        border: Border(top: BorderSide(color: AppColors.creamDeep)),
      ),
      child: GestureDetector(
        onTap: _submitting ? null : _submit,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: _submitting
                ? AppColors.fog.withValues(alpha: 0.4)
                : AppColors.primary,
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
                    '發起活動',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 15,
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
