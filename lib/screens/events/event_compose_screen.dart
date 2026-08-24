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
  final _locationFocus = FocusNode();

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
    _locationFocus.dispose();
    super.dispose();
  }

  void _adjustMaxParticipants(int delta) {
    final current = int.tryParse(_maxParticipants.text.trim()) ?? 0;
    final next = current + delta;
    setState(() {
      _maxParticipants.text = next <= 0 ? '' : next.toString();
    });
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
    // 預設帶入「活動開始前兩小時」（對應後端預設值），方便使用者直接微調
    final defaultDeadline =
        _registrationDeadline ??
        (_startsAt != null
            ? _startsAt!.subtract(const Duration(hours: 2))
            : now);
    final date = await showDatePicker(
      context: context,
      initialDate: defaultDeadline.isBefore(now) ? now : defaultDeadline,
      firstDate: now,
      lastDate: lastDate.isAfter(now) ? lastDate : now,
      helpText: '選擇報名截止日期',
    );
    if (date == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(defaultDeadline),
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

  String _formatDateOnly(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)}';
  }

  String _formatTimeOnly(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
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
                  _buildCoverPlaceholder(),
                  const SizedBox(height: 18),
                  _label('活動名稱', required: true),
                  _textField(_title, hint: '例如：青年族語營', maxLength: 100),
                  const SizedBox(height: 18),
                  IntrinsicHeight(
                    child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          icon: Icons.event,
                          label: '日期',
                          value: _startsAt == null
                              ? null
                              : _formatDateOnly(_startsAt!),
                          subValue: _startsAt == null
                              ? null
                              : _formatTimeOnly(_startsAt!),
                          placeholder: '選擇日期',
                          onTap: _pickDateTime,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildLocationCard(),
                      ),
                    ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _label('詳細地址', required: true),
                  _textField(_address, hint: '例如：花蓮縣秀林鄉…', maxLength: 200),
                  const SizedBox(height: 18),
                  _label('報名截止時間', required: false),
                  _buildDateField(
                    value: _registrationDeadline,
                    onTap: _pickRegistrationDeadline,
                    placeholder: '選擇日期與時間（選填）',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 2),
                    child: Text(
                      '未設定時，預設為活動開始前 2 小時截止',
                      style: TextStyle(fontSize: 11.5, color: AppColors.fog),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _label('名額', required: false),
                  _buildParticipantsStepper(),
                  const SizedBox(height: 18),
                  _label('活動說明', required: true),
                  _textField(
                    _desc,
                    hint: '介紹活動內容、流程、注意事項…',
                    maxLines: 6,
                    maxLength: 2000,
                  ),
                  const SizedBox(height: 18),
                  _label('標籤', required: false),
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.creamDeep)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(fontSize: 15, color: AppColors.inkSoft),
            ),
          ),
          Expanded(
            child: Text(
              '新發布',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSerifTc(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          GestureDetector(
            onTap: _submitting ? null : _submit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _submitting
                    ? AppColors.fog.withValues(alpha: 0.4)
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.creamLight,
                      ),
                    )
                  : Text(
                      '發布',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.creamLight,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('活動封面上傳功能尚未開放')),
        );
      },
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDeep, AppColors.primary],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              color: AppColors.creamLight.withValues(alpha: 0.85),
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              '活動封面（尚未開放）',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.creamLight.withValues(alpha: 0.85),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String? value,
    required String? subValue,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.fog,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value ?? placeholder,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: value == null ? AppColors.fog : AppColors.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subValue != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subValue,
                  style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.creamDeep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '地點',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.fog,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _location,
            focusNode: _locationFocus,
            maxLength: 200,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
            decoration: InputDecoration(
              hintText: '例如：秀林部落活動中心',
              hintStyle: TextStyle(color: AppColors.fog, fontSize: 14),
              border: InputBorder.none,
              counterText: '',
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.creamDeep),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _maxParticipants,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 15, color: AppColors.ink),
              decoration: const InputDecoration(
                hintText: '留空 = 不限名額',
                hintStyle: TextStyle(color: AppColors.fog, fontSize: 14),
                border: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          _stepperButton(
            icon: Icons.remove,
            onTap: () => _adjustMaxParticipants(-1),
            filled: false,
          ),
          const SizedBox(width: 8),
          _stepperButton(
            icon: Icons.add,
            onTap: () => _adjustMaxParticipants(1),
            filled: true,
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.creamLight,
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: AppColors.creamDeep),
        ),
        child: Icon(
          icon,
          size: 16,
          color: filled ? AppColors.creamLight : AppColors.inkSoft,
        ),
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
    FocusNode? focusNode,
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
        focusNode: focusNode,
        onChanged: (_) => setState(() {}),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.creamLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.creamDeep,
              ),
            ),
            child: Text(
              '# $c',
              style: GoogleFonts.notoSerifTc(
                fontSize: 13,
                color: selected ? AppColors.creamLight : AppColors.inkSoft,
                fontWeight: FontWeight.w600,
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

}
