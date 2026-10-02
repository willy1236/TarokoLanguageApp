import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../core/platform/platform_features.dart';
import '../../core/utils/date_format.dart';
import '../../models/event_draft.dart';
import '../../models/event_model.dart';
import '../../models/picked_location.dart';
import '../../models/tribe_model.dart';
import '../../services/event_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/user_service.dart';
import '../../shared/utils/pick_date_time.dart';
import '../../shared/utils/utf16_length_limit.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/related_tribe_field.dart';
import 'event_location_picker_screen.dart';
import 'widgets/event_images_field.dart';

/// 發起／編輯活動表單。
///
/// [editing] 為 null 時是發起新活動，送出呼叫 EventService.createEvent
/// （POST /api/events）；帶入既有 EventDetail 時是編輯模式，預填欄位，
/// 送出呼叫 EventService.updateEvent（PATCH /api/events/:id）。
///
/// **編輯模式只能改後端 PATCH 接受的欄位**：活動名稱、說明、地址、
/// 聯絡 Email/電話、提醒事項、標籤、名額、相關部落。開始時間與報名截止在後端不可改
/// （牽涉提醒重新排程），所以表單設為唯讀並顯示說明。
/// 清空語意：文字欄位送空字串即清空；名額留空送 null（不限名額）。
/// 後端只允許編輯未取消、未開始的活動，否則回 409 EVENT_CLOSED / EVENT_ENDED。
///
/// 必填：標題 / 活動介紹 / 地址 / 開始時間（需未來、1 年內）。後端的地點名稱由
/// 地址推得，見 [EventDraft.location]。
/// 聯絡 email、電話為選填。
/// 權限：僅 organizer / admin 角色可發起，一般帳號會收到 403，表單會顯示錯誤訊息。
///
/// 成功時 Navigator.pop(context, true)，呼叫端（活動列表/詳情頁）據此刷新。
class EventComposeScreen extends StatefulWidget {
  final EventDetail? editing;

  const EventComposeScreen({super.key, this.editing});

  @override
  State<EventComposeScreen> createState() => _EventComposeScreenState();
}

class _EventComposeScreenState extends State<EventComposeScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _maxParticipants = TextEditingController();

  /// 提醒事項：後端 PATCH 支援的欄位之一，只在編輯模式顯示（建立活動的
  /// POST 沒有這個欄位）。
  final _reminderNote = TextEditingController();

  /// 在地圖上選的位置；地址欄被改得跟回填的不一樣就清掉（座標不再可信）。
  PickedLocation? _picked;

  /// 選點後又手動改了地址，提示可以重新在地圖上選。
  bool _pickCleared = false;

  DateTime? _startsAt;
  DateTime? _registrationDeadline;
  DateTime? _registrationStartsAt;
  DateTime? _endsAt;
  String? _category; // 選填，null = 不分類

  /// 相關部落，預設不選；不可預設帶發起人自己的部落。
  TribeTag? _tribe;

  /// 推播給相關部落成員。只在建立時提供，且要先選部落才能勾。
  bool _notifyTribe = false;
  bool _submitting = false;

  /// 照片：按發布／儲存才送出，建立時在活動建好、拿到 id 之後才上傳。
  late final _images = EventImagesController(
    widget.editing?.images ?? const [],
  );

  // 常用分類（對應活動列表的篩選標籤）；點一下切換，可不選。
  static const _categories = ['族語', '走讀', '工藝', '線上', '音樂', '其他'];

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e == null) return;
    final d = EventDraft.fromDetail(e);
    _title.text = d.title;
    _desc.text = d.description;
    _address.text = d.address;
    _picked = d.picked;
    _email.text = d.contactEmail;
    _phone.text = d.contactPhone;
    _maxParticipants.text = d.maxParticipantsText;
    _reminderNote.text = d.reminderNote;
    _startsAt = d.startsAt;
    _registrationDeadline = d.registrationDeadline;
    _registrationStartsAt = d.registrationStartsAt;
    _endsAt = d.endsAt;
    _category = d.category;
    final tribeId = d.tribeId;
    if (tribeId != null) {
      _tribe = TribeTag(id: tribeId, name: '');
      _loadTribeName(tribeId);
    }
  }

  /// 活動只回 tribe_id，名稱另外對照；查不到就維持空白，不影響送出。
  Future<void> _loadTribeName(int id) async {
    try {
      final name = await UserService.tribeName(id);
      if (!mounted || name == null || _tribe?.id != id) return;
      setState(() => _tribe = TribeTag(id: id, name: name));
    } catch (e) {
      debugPrint('EventComposeScreen: 部落名稱載入失敗（忽略）：$e');
    }
  }

  EventDraft get _draft => EventDraft(
    title: _title.text,
    description: _desc.text,
    address: _address.text,
    picked: _picked,
    startsAt: _startsAt,
    registrationDeadline: _registrationDeadline,
    registrationStartsAt: _registrationStartsAt,
    endsAt: _endsAt,
    contactEmail: _email.text,
    contactPhone: _phone.text,
    maxParticipantsText: _maxParticipants.text,
    category: _category,
    reminderNote: _reminderNote.text,
    tribeId: _tribe?.id,
    notifyTribe: _notifyTribe,
  );

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _address.dispose();
    _email.dispose();
    _phone.dispose();
    _maxParticipants.dispose();
    _reminderNote.dispose();
    _images.dispose();
    super.dispose();
  }

  void _onAddressChanged(String text) {
    final picked = _picked;
    if (picked == null || picked.address.trim() == text.trim()) return;
    setState(() {
      _picked = null;
      _pickCleared = true;
    });
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => EventLocationPickerScreen(initial: _picked),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _picked = picked;
      _pickCleared = false;
      _address.text = picked.address;
    });
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
    final tomorrow = now.add(const Duration(days: 1));
    final hourLater = now.add(const Duration(hours: 1));
    final picked = await pickDateTime(
      context,
      // 沒選過時，日期預設明天、時間預設一小時後。
      initial:
          _startsAt ??
          DateTime(
            tomorrow.year,
            tomorrow.month,
            tomorrow.day,
            hourLater.hour,
            hourLater.minute,
          ),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      dateHelp: '選擇活動日期',
      timeHelp: '選擇活動時間',
    );
    if (picked == null || !mounted) return;
    setState(() => _startsAt = picked);
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
    final picked = await pickDateTime(
      context,
      initial: defaultDeadline,
      firstDate: now,
      lastDate: lastDate.isAfter(now) ? lastDate : now,
      dateHelp: '選擇報名截止日期',
      timeHelp: '選擇報名截止時間',
    );
    if (picked == null || !mounted) return;
    setState(() => _registrationDeadline = picked);
  }

  Future<void> _pickEndsAt() async {
    final starts = _startsAt;
    if (starts == null) {
      _showError('請先選擇活動開始時間');
      return;
    }
    final picked = await pickDateTime(
      context,
      initial: _endsAt ?? starts.add(const Duration(hours: 3)),
      firstDate: DateTime(starts.year, starts.month, starts.day),
      lastDate: starts.add(EventDraft.maxDuration),
      dateHelp: '選擇活動結束日期',
      timeHelp: '選擇活動結束時間',
    );
    if (picked != null && mounted) setState(() => _endsAt = picked);
  }

  Future<void> _pickRegistrationStartsAt() async {
    final now = DateTime.now();
    final last = _registrationDeadline ?? _startsAt;
    final picked = await pickDateTime(
      context,
      initial: _registrationStartsAt ?? now.add(const Duration(hours: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: last != null && last.isAfter(now)
          ? last
          : now.add(const Duration(days: 365)),
      dateHelp: '選擇報名開始日期',
      timeHelp: '選擇報名開始時間',
    );
    if (picked != null && mounted) {
      setState(() => _registrationStartsAt = picked);
    }
  }

  // 送出失敗一律用 SnackBar：送出按鈕在固定的 header，錯誤訊息若渲染在表單裡，
  // 使用者按下去會看不到任何反應。與 reminder_compose_screen 的作法一致。
  void _showError(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final editing = widget.editing;
    final draft = _draft;
    final invalid = draft.validate(
      creating: editing == null,
      now: DateTime.now(),
    );
    if (invalid != null) {
      _showError(invalid);
      return;
    }

    if (_images.picking) {
      _showError('照片還在處理中，請稍候再送出');
      return;
    }

    setState(() => _submitting = true);
    try {
      var tribeNotifyLimited = false;
      String? imageFailure;
      if (editing == null) {
        final created = await EventService.createEvent(draft);
        tribeNotifyLimited = draft.notifyTribe && created.tribeNotifyLimited;
        imageFailure = await _uploadNewImages(created.id);
      } else {
        // 時間欄位已不能改時後端回 409，照片也就不送，見下方 catch。
        await EventService.updateEvent(editing.id, draft, editing);
        imageFailure = await _syncEditedImages(editing.id);
      }
      if (!mounted) return;
      final notices = [
        if (tribeNotifyLimited) '今天的部落推播次數已用完，這次沒有通知部落成員',
        ?imageFailure,
      ];
      final done = editing == null ? '活動已建立' : '活動已更新';
      ScaffoldMessenger.of(context).showSnackBar(
        notices.isNotEmpty
            // 發起人以為都送出了，這則要停久一點讓人讀完。
            ? SnackBar(
                content: Text('$done，${notices.join('；')}'),
                duration: const Duration(seconds: 8),
              )
            : SnackBar(content: Text(editing == null ? '活動已發起' : done)),
      );
      Navigator.pop(context, true); // 通知列表/詳情頁刷新
    } catch (e) {
      if (!mounted) return;
      final code = e is ApiException ? e.code : null;
      if (code == 'EVENT_CLOSED' || code == 'EVENT_ENDED') {
        // 活動在編輯期間被取消或已開始：留在表單也存不了，退回詳情頁刷新狀態。
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(code == 'EVENT_CLOSED' ? '活動已取消，無法修改' : '活動已開始，無法修改'),
          ),
        );
        Navigator.pop(context, true);
        return;
      }
      setState(() => _submitting = false);
      if (code == 'EVENT_TRIBE_REQUIRED') {
        _showError('請先選擇相關部落');
        return;
      }
      // 後端訊息，例如「需要活動主辦權限（organizer / admin）」
      _showError(e.toString());
    }
  }

  /// 編輯時既有照片的網址過期（詳情頁取得後超過 15 分鐘）：重新取得詳情換網址。
  /// 自動觸發有次數上限，照片本身壞掉時才不會一直重打；[manual]（使用者點重試）不受限。
  int _imageUrlRefreshes = 0;
  bool _refreshingImageUrls = false;

  Future<void> _refreshImageUrls({bool manual = false}) async {
    final editing = widget.editing;
    if (editing == null || _refreshingImageUrls) return;
    if (!manual) {
      if (_imageUrlRefreshes >= 3) return;
      _imageUrlRefreshes++;
    }
    _refreshingImageUrls = true;
    try {
      final detail = await EventService.fetchEventDetail(editing.id);
      if (mounted) _images.refreshUrls(detail.images);
    } catch (e) {
      debugPrint('EventComposeScreen: 照片網址更新失敗（忽略）：$e');
    } finally {
      _refreshingImageUrls = false;
    }
  }

  /// 建立活動後上傳選好的照片。活動已經建立，照片失敗不能讓整個送出變失敗
  /// 而留在表單（再按一次會重複建立活動），回傳要告訴發起人的說明。
  Future<String?> _uploadNewImages(int eventId) async {
    final images = _images.toUpload;
    if (images.isEmpty) return null;
    try {
      await EventService.uploadImages(eventId, images);
      return null;
    } catch (e) {
      final reason = apiErrorMessage(e, fallback: '網路不穩');
      return '圖片可以稍後在編輯頁補上（$reason）';
    }
  }

  /// 編輯儲存時，文字欄位存好後處理照片：先刪標記的、再傳新的——先刪才不會在
  /// 已有 6 張時被上限擋下。文字已存、無法回滾，照片失敗只回傳說明。
  Future<String?> _syncEditedImages(int eventId) async {
    final uploads = _images.toUpload;
    try {
      for (final imageId in _images.toDelete) {
        await EventService.deleteImage(eventId, imageId);
      }
    } catch (e) {
      final reason = apiErrorMessage(e, fallback: '網路不穩');
      return uploads.isEmpty
          ? '有照片沒有刪除（$reason），可到活動頁頂端再刪'
          : '有照片沒有刪除、新照片也沒有上傳（$reason），可到活動頁頂端調整';
    }
    if (uploads.isEmpty) return null;
    try {
      await EventService.uploadImages(eventId, uploads);
      return null;
    } catch (e) {
      final reason = apiErrorMessage(e, fallback: '網路不穩');
      return '新照片沒有上傳（$reason），可到活動頁頂端重新新增';
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
                  _label('活動照片', required: false, seniorMode: seniorMode),
                  EventImagesField(
                    controller: _images,
                    seniorMode: seniorMode,
                    enabled: !_submitting,
                    onExistingExpired: _refreshImageUrls,
                    onExistingRetryTap: () => _refreshImageUrls(manual: true),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 18),
                    _buildReadOnlyNotice(seniorMode),
                  ],
                  const SizedBox(height: 18),
                  _label('活動名稱', required: true, seniorMode: seniorMode),
                  _textField(
                    _title,
                    hint: '例如：青年族語營',
                    maxLength: EventDraft.titleMax,
                    seniorMode: seniorMode,
                  ),
                  const SizedBox(height: 18),
                  // 地址會換行，不放進跟日期並排的半寬卡片。
                  _buildSummaryCard(
                    icon: Icons.event,
                    label: '日期',
                    value: _startsAt == null ? null : formatDate(_startsAt!),
                    subValue: _startsAt == null ? null : formatTime(_startsAt!),
                    placeholder: '選擇日期',
                    onTap: _isEditing ? null : _pickDateTime,
                    seniorMode: seniorMode,
                  ),
                  const SizedBox(height: 12),
                  _buildLocationCard(seniorMode),
                  const SizedBox(height: 18),
                  _label('活動結束時間', required: false, seniorMode: seniorMode),
                  _buildDateField(
                    value: _endsAt,
                    onTap: _isEditing ? null : _pickEndsAt,
                    placeholder: '選擇日期與時間（選填）',
                    seniorMode: seniorMode,
                  ),
                  _caption('未設定時，預設為活動開始後 3 小時結束', seniorMode),
                  const SizedBox(height: 18),
                  _label('報名開始時間', required: false, seniorMode: seniorMode),
                  _buildDateField(
                    value: _registrationStartsAt,
                    onTap: _isEditing ? null : _pickRegistrationStartsAt,
                    placeholder: '選擇日期與時間（選填）',
                    seniorMode: seniorMode,
                  ),
                  _caption('未設定時，活動發起後立即開放報名', seniorMode),
                  const SizedBox(height: 18),
                  _label('報名截止時間', required: false, seniorMode: seniorMode),
                  _buildDateField(
                    value: _registrationDeadline,
                    onTap: _isEditing ? null : _pickRegistrationDeadline,
                    placeholder: '選擇日期與時間（選填）',
                    seniorMode: seniorMode,
                  ),
                  _caption('未設定時，預設為活動開始前 2 小時截止', seniorMode),
                  const SizedBox(height: 18),
                  _label('名額', required: false, seniorMode: seniorMode),
                  _buildParticipantsStepper(seniorMode),
                  const SizedBox(height: 18),
                  _label('活動說明', required: true, seniorMode: seniorMode),
                  _textField(
                    _desc,
                    hint: '介紹活動內容、流程、注意事項…',
                    maxLines: 6,
                    maxLength: EventDraft.descriptionMax,
                    seniorMode: seniorMode,
                  ),
                  const SizedBox(height: 18),
                  _label('標籤', required: false, seniorMode: seniorMode),
                  _buildCategoryChips(seniorMode),
                  const SizedBox(height: 18),
                  RelatedTribeField(
                    tribe: _tribe,
                    seniorMode: seniorMode,
                    onChanged: (tribe) => setState(() {
                      _tribe = tribe;
                      if (tribe == null) _notifyTribe = false;
                    }),
                  ),
                  // 部落推播只在建立時送出；編輯改標籤後端不會重新推播。
                  if (!_isEditing) _buildNotifyTribeToggle(seniorMode),
                  const SizedBox(height: 18),
                  _label('聯絡 Email', required: false, seniorMode: seniorMode),
                  _textField(
                    _email,
                    hint: '選填',
                    keyboardType: TextInputType.emailAddress,
                    seniorMode: seniorMode,
                  ),
                  const SizedBox(height: 18),
                  _label('聯絡電話', required: false, seniorMode: seniorMode),
                  _textField(
                    _phone,
                    hint: '選填',
                    keyboardType: TextInputType.phone,
                    seniorMode: seniorMode,
                  ),
                  // 提醒事項只有 PATCH 支援（建立活動的 POST 沒有這個欄位）。
                  if (_isEditing) ...[
                    const SizedBox(height: 18),
                    _label('提醒事項', required: false, seniorMode: seniorMode),
                    _textField(
                      _reminderNote,
                      hint: '給參加者的提醒，例如需自備雨具（選填，留空即清除）',
                      maxLines: 3,
                      maxLength: EventDraft.reminderNoteMax,
                      seniorMode: seniorMode,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 沒選相關部落時停用：後端要求 notify_tribe 必須搭配 tribe_id。
  Widget _buildNotifyTribeToggle(bool seniorMode) {
    final tribe = _tribe;
    final enabled = tribe != null;
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.primary,
      // activeColor 只管勾選後；未勾選的外框預設色太淡，在米色底上幾乎看不見。
      side: BorderSide(
        color: enabled ? AppColors.primary : AppColors.fog,
        width: 1.5,
      ),
      value: enabled && _notifyTribe,
      onChanged: enabled
          ? (v) => setState(() => _notifyTribe = v ?? false)
          : null,
      title: Text(
        enabled
            ? '推播給${tribe.name.isEmpty ? '相關部落' : tribe.name}的成員'
            : '推播給部落成員（請先選擇相關部落）',
        style: AppTypography.serif(
          fontSize: AppTypography.size(
            AppTypography.caption,
            seniorMode: seniorMode,
          ),
          color: enabled ? AppColors.ink : AppColors.fog,
        ),
      ),
    );
  }

  Widget _buildHeader(bool seniorMode) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.creamDeep)),
      ),
      child: Row(
        children: [
          const AppBackButton(),
          Expanded(
            child: Text(
              _isEditing ? '編輯活動' : '新發布',
              textAlign: TextAlign.center,
              style: AppTypography.serif(
                fontSize: AppTypography.size(
                  AppTypography.subtitle,
                  seniorMode: seniorMode,
                ),
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          GestureDetector(
            onTap: _submitting ? null : _submit,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: seniorMode ? 24 : 20,
                vertical: seniorMode ? 14 : 10,
              ),
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
                      _isEditing ? '儲存' : '發布',
                      style: TextStyle(
                        fontSize: AppTypography.size(
                          AppTypography.body,
                          seniorMode: seniorMode,
                        ),
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

  /// 編輯模式的唯讀提示。後端 PATCH /events/:id 只接受說明、地點、地址、
  /// 聯絡方式、提醒事項、標籤；其餘欄位送了會被靜默丟棄，所以直接鎖住並
  /// 說明原因，而不是讓使用者改了半天卻沒存到。
  Widget _buildReadOnlyNotice(bool seniorMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.creamDeep),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: seniorMode ? 24 : 18,
            color: AppColors.inkSoft,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '活動時間與報名截止發布後就不能再改（灰底欄位）。'
              '需要調整時間，請取消這場活動後重新發起。',
              style: TextStyle(
                fontSize: AppTypography.size(
                  AppTypography.body,
                  seniorMode: seniorMode,
                ),
                color: AppColors.inkSoft,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String? value,
    required String? subValue,
    required String placeholder,
    required VoidCallback? onTap, // null = 唯讀（編輯模式的不可改欄位）
    required bool seniorMode,
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
                Icon(
                  icon,
                  size: seniorMode ? 20 : 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppTypography.size(
                      AppTypography.caption,
                      seniorMode: seniorMode,
                    ),
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
                fontSize: AppTypography.size(
                  AppTypography.bodyLarge,
                  seniorMode: seniorMode,
                ),
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
                  style: TextStyle(
                    fontSize: AppTypography.size(
                      AppTypography.caption,
                      seniorMode: seniorMode,
                    ),
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(bool seniorMode) {
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
              Icon(
                Icons.location_on_outlined,
                size: seniorMode ? 20 : 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '地址',
                style: TextStyle(
                  fontSize: AppTypography.size(
                    AppTypography.caption,
                    seniorMode: seniorMode,
                  ),
                  color: AppColors.fog,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 地址可能很長，換行最多三行。
          TextField(
            controller: _address,
            onChanged: _onAddressChanged,
            minLines: 1,
            maxLines: 3,
            inputFormatters: const [
              Utf16LengthLimitingTextInputFormatter(EventDraft.addressMax),
            ],
            style: TextStyle(
              fontSize: AppTypography.size(
                AppTypography.bodyLarge,
                seniorMode: seniorMode,
              ),
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
            decoration: InputDecoration(
              hintText: '門牌或描述，例如：秀林鄉富世村 12 號／部落活動中心',
              hintMaxLines: 3,
              hintStyle: TextStyle(
                color: AppColors.fog,
                fontSize: AppTypography.size(
                  AppTypography.body,
                  seniorMode: seniorMode,
                ),
              ),
              border: InputBorder.none,
              counterText: '',
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (_picked != null)
            _locationHint(Icons.check_circle_outline, '已在地圖上定位', seniorMode)
          else if (_pickCleared)
            _locationHint(Icons.info_outline, '已改為手動地址，可重新在地圖上選擇', seniorMode),
          if (PlatformFeatures.supportsMapPicker)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _submitting ? null : _pickOnMap,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size(0, seniorMode ? 48 : 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.map_outlined, size: seniorMode ? 22 : 18),
                label: Text(
                  '在地圖上選擇',
                  style: AppTypography.bodyStyle(
                    seniorMode: seniorMode,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _locationHint(IconData icon, String text, bool seniorMode) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Icon(icon, size: seniorMode ? 18 : 14, color: AppColors.inkSoft),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTypography.captionStyle(
              seniorMode: seniorMode,
              color: AppColors.inkSoft,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildParticipantsStepper(bool seniorMode) {
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
              style: TextStyle(
                fontSize: AppTypography.size(
                  AppTypography.bodyLarge,
                  seniorMode: seniorMode,
                ),
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                hintText: '留空 = 不限名額',
                hintStyle: TextStyle(
                  color: AppColors.fog,
                  fontSize: AppTypography.size(
                    AppTypography.body,
                    seniorMode: seniorMode,
                  ),
                ),
                border: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          _stepperButton(
            icon: Icons.remove,
            onTap: () => _adjustMaxParticipants(-1),
            filled: false,
            seniorMode: seniorMode,
          ),
          const SizedBox(width: 8),
          _stepperButton(
            icon: Icons.add,
            onTap: () => _adjustMaxParticipants(1),
            filled: true,
            seniorMode: seniorMode,
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool filled,
    required bool seniorMode,
  }) {
    final size = seniorMode ? 48.0 : 32.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.creamLight,
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: AppColors.creamDeep),
        ),
        child: Icon(
          icon,
          size: seniorMode ? 24 : 16,
          color: filled ? AppColors.creamLight : AppColors.inkSoft,
        ),
      ),
    );
  }

  Widget _label(
    String text, {
    required bool required,
    required bool seniorMode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            text,
            style: AppTypography.serif(
              fontSize: AppTypography.size(
                AppTypography.body,
                seniorMode: seniorMode,
              ),
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              letterSpacing: 1.0,
            ),
          ),
          if (required)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '*',
                style: TextStyle(
                  fontSize: AppTypography.size(
                    AppTypography.body,
                    seniorMode: seniorMode,
                  ),
                  color: AppColors.primary,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                '選填',
                style: TextStyle(
                  fontSize: AppTypography.size(
                    AppTypography.caption,
                    seniorMode: seniorMode,
                  ),
                  color: AppColors.fog,
                ),
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
    bool readOnly = false,
    required bool seniorMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? AppColors.creamDeep : AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.creamDeep),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: c,
        focusNode: focusNode,
        readOnly: readOnly,
        onChanged: (_) => setState(() {}),
        maxLines: maxLines,
        inputFormatters: [
          if (maxLength != null)
            Utf16LengthLimitingTextInputFormatter(maxLength),
        ],
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: AppTypography.size(
            AppTypography.body,
            seniorMode: seniorMode,
          ),
          color: AppColors.ink,
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.fog,
            fontSize: AppTypography.size(
              AppTypography.body,
              seniorMode: seniorMode,
            ),
          ),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _caption(String text, bool seniorMode) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 2),
    child: Text(
      text,
      style: AppTypography.captionStyle(
        seniorMode: seniorMode,
        color: AppColors.fog,
      ),
    ),
  );

  Widget _buildDateField({
    required DateTime? value,
    required VoidCallback? onTap, // null = 唯讀（編輯模式的不可改欄位）
    String placeholder = '選擇日期與時間',
    required bool seniorMode,
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
            Icon(
              Icons.event,
              size: seniorMode ? 24 : 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value == null ? placeholder : formatDateTime(value),
                style: TextStyle(
                  fontSize: AppTypography.size(
                    AppTypography.body,
                    seniorMode: seniorMode,
                  ),
                  color: value == null ? AppColors.fog : AppColors.ink,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips(bool seniorMode) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((c) {
        final selected = _category == c;
        return GestureDetector(
          onTap: () => setState(() => _category = selected ? null : c),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: seniorMode ? 14 : 10,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.creamLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.creamDeep,
              ),
            ),
            child: Text(
              '# $c',
              style: AppTypography.serif(
                fontSize: AppTypography.size(
                  AppTypography.body,
                  seniorMode: seniorMode,
                ),
                color: selected ? AppColors.creamLight : AppColors.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
