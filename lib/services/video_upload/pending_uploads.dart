// 未完成的影片上傳清單：App 被關掉或網頁重新整理後，影片管理列表靠它提供「繼續上傳」。
// 存在 shared_preferences（網頁版是 localStorage），以影片 id 為鍵，一支影片最多一筆。
//
// 由 VideoUploadManager 自動維護：start（上傳、重新上傳都經過它）寫入，傳完、放棄、
// 工作階段失效時刪除。畫面只讀 [PendingUploads.items]，並用 [PendingUploads.discard] 放棄不在傳的那幾支。
// 紀錄帶登入者 uid，只顯示給同一個管理員。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/admin_models.dart';
import '../../models/video_upload.dart';
import 'background_upload.dart';
import 'upload_files.dart';

/// 雲端上傳工作階段的有效期限（GCS resumable 一週）。
const uploadSessionLifetime = Duration(days: 7);

/// 一支還沒傳完的影片。
class PendingUpload {
  /// 建立上傳的管理員 uid；只顯示給同一個人。
  final int? userId;
  final int videoId;
  final String title;
  final String category;
  final UploadSession session;

  /// 選檔時的檔名，網頁版（與手機檔案不見時）重選檔案用它比對。
  final String fileName;

  /// 手機上的檔案路徑；網頁版是 null。
  final String? filePath;

  /// [filePath] 是 App 自己的暫存複本（傳完或放棄時刪掉）。
  final bool temporaryFile;

  /// 工作階段建立的時間（續傳不會更新）。
  final DateTime createdAt;

  const PendingUpload({
    required this.userId,
    required this.videoId,
    required this.title,
    required this.category,
    required this.session,
    required this.fileName,
    required this.filePath,
    required this.temporaryFile,
    required this.createdAt,
  });

  /// 檔案總大小（bytes）。
  int get size => session.size;

  /// 給上傳服務與進度頁用的影片（只有 id、標題、分類；狀態一律當作處理中）。
  AdminVideo get video => AdminVideo(
    id: videoId,
    title: title,
    category: category,
    source: 'hls',
    status: 'processing',
  );

  /// 超過一週，雲端工作階段應已失效（以雲端回 404／410 為準，這裡只用來先提示）。
  bool isExpiredAt(DateTime now) =>
      now.difference(createdAt) >= uploadSessionLifetime;

  /// 存進本機的內容。`session_url` 本身就是寫入權限（GCS resumable 的網址帶著憑證，
  /// 拿到就能對這支影片的上傳寫入，一週後失效）；有意存放，續傳少不了它，
  /// 且只存在這台裝置的 App 資料（網頁版是這個網域的 localStorage）。
  Map<String, Object?> toJson() => {
    'user_id': userId,
    'video_id': videoId,
    'title': title,
    'category': category,
    'session_url': session.sessionUrl.toString(),
    'size': session.size,
    'chunk_size_multiple': session.chunkMultiple,
    'file_name': fileName,
    'file_path': filePath,
    'temporary_file': temporaryFile,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory PendingUpload.fromJson(Map<String, dynamic> j) => PendingUpload(
    userId: (j['user_id'] as num?)?.toInt(),
    videoId: (j['video_id'] as num).toInt(),
    title: j['title'] as String? ?? '',
    category: j['category'] as String? ?? '',
    session: UploadSession.fromJson(j),
    fileName: j['file_name'] as String,
    filePath: j['file_path'] as String?,
    temporaryFile: j['temporary_file'] as bool? ?? false,
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
  );

  PendingUpload _withCreatedAt(DateTime createdAt) => PendingUpload(
    userId: userId,
    videoId: videoId,
    title: title,
    category: category,
    session: session,
    fileName: fileName,
    filePath: filePath,
    temporaryFile: temporaryFile,
    createdAt: createdAt,
  );
}

class PendingUploads {
  PendingUploads._();

  static final PendingUploads instance = PendingUploads._();

  static const _prefsKey = 'admin_video_pending_uploads';

  final _items = ValueNotifier<List<PendingUpload>>(const []);
  Future<void>? _loading;
  bool _cleanedOrphans = false;

  /// 讀取時有紀錄讀不出來（整份或其中幾筆）。
  bool _readIncomplete = false;

  /// 所有未完成的上傳（含其他帳號的；畫面用 [visibleTo] 過濾）。[load] 之前是空的。
  ValueListenable<List<PendingUpload>> get items => _items;

  /// [uid] 這位管理員自己的紀錄。
  List<PendingUpload> visibleTo(int? uid) =>
      _items.value.where((p) => p.userId == uid).toList();

  /// 讀出本機紀錄（只讀一次）。App 啟動後第一次由畫面呼叫時，順便刪掉上傳暫存目錄裡
  /// 沒有紀錄的檔案（App 在選檔後、送出前被關掉留下的）。上傳服務寫紀錄時只讀不清，
  /// 免得清掉正要寫進紀錄的檔案。
  ///
  /// 前提：影片管理是選檔與上傳的唯一入口，它第一次呼叫這裡時，這次啟動還沒有任何
  /// 選好但未寫進紀錄的檔案。T-06 若讓背景工作在 App 啟動時就接手上傳，要重新檢查這個前提。
  Future<void> load() async {
    await _ensureLoaded();
    if (_cleanedOrphans) return;
    _cleanedOrphans = true;
    // 有紀錄讀不出來時不清：不知道它用哪個檔案，清了可能刪掉還能續傳的暫存檔。
    if (_readIncomplete) return;
    await deleteOrphanUploadFiles({
      for (final p in _items.value)
        if (p.filePath != null) p.filePath!,
    });
  }

  Future<void> _ensureLoaded() => _loading ??= _read();

  /// 每筆各自解析，壞掉的跳過，不連累其他紀錄。
  Future<void> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final items = <PendingUpload>[];
      for (final j in jsonDecode(raw) as List) {
        try {
          items.add(PendingUpload.fromJson(j as Map<String, dynamic>));
        } catch (e) {
          _readIncomplete = true;
          debugPrint('PendingUploads: 跳過讀不出來的未完成上傳：$e');
        }
      }
      _items.value = List.unmodifiable(items);
    } catch (e) {
      _readIncomplete = true;
      debugPrint('PendingUploads: 讀取未完成上傳失敗，當作沒有：$e');
    }
  }

  /// 新增或更新一支（同一支影片只留一筆）。同一個工作階段續傳時保留原本的建立時間。
  /// 回傳被取代的舊紀錄（沒有就是 null）；舊紀錄的暫存複本由呼叫端決定要不要刪。
  Future<PendingUpload?> save(PendingUpload upload) async {
    await _ensureLoaded();
    final existing = _items.value.where((p) => p.videoId == upload.videoId);
    final keepCreatedAt =
        existing.isNotEmpty &&
        existing.first.session.sessionUrl == upload.session.sessionUrl;
    final record = keepCreatedAt
        ? upload._withCreatedAt(existing.first.createdAt)
        : upload;
    await _write([
      for (final p in _items.value)
        if (p.videoId != upload.videoId) p,
      record,
    ]);
    return existing.firstOrNull;
  }

  /// 刪掉這支的紀錄（檔案不動，由上傳服務的讀檔來源負責）。
  Future<void> remove(int videoId) async {
    await _ensureLoaded();
    if (!_items.value.any((p) => p.videoId == videoId)) return;
    await _write([
      for (final p in _items.value)
        if (p.videoId != videoId) p,
    ]);
  }

  /// 放棄一支不在傳的：刪紀錄，暫存複本一併刪掉。
  Future<void> discard(PendingUpload upload) async {
    await remove(upload.videoId);
    // 系統背景傳輸可能還在傳這支（App 被關掉前排的），先取消並等它停下，免得刪檔後仍被傳完。
    try {
      await cancelBackgroundUploads(upload.videoId);
    } catch (e) {
      debugPrint('PendingUploads: 取消背景上傳失敗（忽略）：$e');
    }
    final path = upload.filePath;
    if (upload.temporaryFile && path != null) await deleteUploadFile(path);
  }

  Future<void> _write(List<PendingUpload> items) async {
    _items.value = List.unmodifiable(items);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode([for (final p in items) p.toJson()]),
      );
    } catch (e) {
      debugPrint('PendingUploads: 寫入未完成上傳失敗（忽略）：$e');
    }
  }

  /// 測試之間清掉狀態（下次 [load] 重新讀 prefs）。
  @visibleForTesting
  void resetForTest() {
    _items.value = const [];
    _loading = null;
    _cleanedOrphans = false;
    _readIncomplete = false;
  }
}
