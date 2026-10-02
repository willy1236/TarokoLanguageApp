// 發起活動時在地圖上選位置：搜尋地點，或拖曳地圖讓中央的大頭針對準位置，
// 按「使用這個位置」帶回 PickedLocation。只在 PlatformFeatures.supportsMapPicker 時開啟。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/picked_location.dart';
import '../../services/places_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/app_back_button.dart';

class EventLocationPickerScreen extends StatefulWidget {
  /// 編輯時已有的選點，地圖從這裡開始；null 時從秀林鄉開始。
  final PickedLocation? initial;

  const EventLocationPickerScreen({super.key, this.initial});

  @override
  State<EventLocationPickerScreen> createState() =>
      _EventLocationPickerScreenState();
}

/// 新建活動時的地圖起點：花蓮秀林鄉。
const _defaultCenter = LatLng(24.1167, 121.6208);
const _zoom = 16.0;
const _searchDebounce = Duration(milliseconds: 400);
const _initTimeout = Duration(seconds: 15);

bool _samePoint(LatLng a, LatLng? b) =>
    b != null &&
    (a.latitude - b.latitude).abs() < 1e-6 &&
    (a.longitude - b.longitude).abs() < 1e-6;

class _EventLocationPickerScreenState extends State<EventLocationPickerScreen> {
  GoogleMapController? _map;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  /// 地圖起點；Web 的 Maps JS 載完前是 null，先顯示載入中。
  LatLng? _start;
  late LatLng _center;

  /// 目前大頭針位置的名稱與地址。名稱只有從搜尋結果選的才有，拖曳後清掉。
  String? _name;
  String? _address;
  bool _resolving = false;
  bool _addressFailed = false;

  List<PlaceSuggestion> _suggestions = const [];
  Timer? _debounce;

  /// 新的搜尋 session：開啟畫面後第一次搜尋、或選定一筆結果之後。
  bool _newSession = true;

  /// 目前名稱與地址對應的位置。鏡頭停下時中心沒離開這裡（地圖剛載入、移到搜尋
  /// 結果）就不重查，才不會蓋掉原本的地點名稱。
  LatLng? _resolvedAt;

  /// 地圖移動中：中心與下方的地址還對不上，先不能確認。
  bool _moving = false;

  /// 只有最後一次反向地理編碼的結果有效，避免舊請求晚回蓋掉新位置。
  int _resolveSeq = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final initial = widget.initial;
    final start = initial != null
        ? LatLng(initial.latitude, initial.longitude)
        : _defaultCenter;
    // Web 的地圖靠 Places 初始化時注入的 Maps JS，要先等它載完。Maps JS 載不到
    // （網路、CSP、金鑰被拒）時外掛不會回報錯誤，只會一直等，所以要設逾時。
    try {
      await PlacesService.ensureReady().timeout(_initTimeout);
    } catch (e) {
      debugPrint('EventLocationPickerScreen: Places 初始化失敗：$e');
      if (!mounted) return;
      _showMessage('地圖暫時無法使用，請直接輸入地址');
      Navigator.pop(context);
      return;
    }
    if (!mounted) return;
    setState(() {
      _start = start;
      _center = start;
      _resolvedAt = start;
      _name = initial?.name;
      _address = initial?.address;
    });
    if (initial == null) _resolveAddress(start);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _resolveAddress(LatLng at) async {
    final seq = ++_resolveSeq;
    _resolvedAt = at;
    setState(() {
      _resolving = true;
      _addressFailed = false;
    });
    String? address;
    try {
      address = await PlacesService.addressAt(at.latitude, at.longitude);
    } catch (e) {
      debugPrint('EventLocationPickerScreen: 反向地理編碼失敗：$e');
    }
    if (!mounted || seq != _resolveSeq) return;
    setState(() {
      _resolving = false;
      _address = address;
      _addressFailed = address == null;
    });
  }

  void _onCameraMove(CameraPosition p) => _center = p.target;

  void _onCameraMoveStarted() {
    if (!_moving) setState(() => _moving = true);
  }

  void _onCameraIdle() {
    if (_start == null) return;
    if (_moving) setState(() => _moving = false);
    if (_samePoint(_center, _resolvedAt)) return;
    _name = null;
    _resolveAddress(_center);
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }
    setState(() {}); // 更新清除鈕
    _debounce = Timer(_searchDebounce, () => _runSearch(text));
  }

  Future<void> _runSearch(String text) async {
    final newSession = _newSession;
    _newSession = false;
    try {
      final results = await PlacesService.search(
        text,
        newSession: newSession,
        near: (lat: _center.latitude, lng: _center.longitude),
      );
      if (!mounted || _search.text != text) return;
      setState(() => _suggestions = results);
    } catch (e) {
      debugPrint('EventLocationPickerScreen: 地點搜尋失敗：$e');
      if (!mounted) return;
      _showMessage('搜尋暫時無法使用，可以直接拖曳地圖選位置');
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion s) async {
    _searchFocus.unfocus();
    setState(() => _suggestions = const []);
    PickedLocation? place;
    try {
      place = await PlacesService.details(s.placeId);
    } catch (e) {
      debugPrint('EventLocationPickerScreen: 地點詳情失敗：$e');
    }
    _newSession = true;
    if (!mounted) return;
    if (place == null) {
      _showMessage('找不到這個地點的位置，請換一個結果或拖曳地圖');
      return;
    }
    final target = LatLng(place.latitude, place.longitude);
    _resolveSeq++; // 讓還沒回來的反向地理編碼作廢
    setState(() {
      _center = target;
      _resolvedAt = target;
      _name = place!.name;
      _address = place.address;
      _resolving = false;
      _addressFailed = false;
    });
    await _map?.animateCamera(CameraUpdate.newLatLngZoom(target, _zoom));
  }

  void _showMessage(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _confirm() {
    final address = _address;
    if (address == null || address.isEmpty) return;
    Navigator.pop(
      context,
      PickedLocation(
        name: _name,
        address: address,
        latitude: _center.latitude,
        longitude: _center.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => _buildScaffold(seniorModeController.enabled),
    );
  }

  Widget _buildScaffold(bool seniorMode) {
    final start = _start;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(
          '選擇活動位置',
          style: AppTypography.titleStyle(
            seniorMode: seniorMode,
            color: AppColors.ink,
          ),
        ),
      ),
      body: start == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: start,
                          zoom: _zoom,
                        ),
                        onMapCreated: (c) => _map = c,
                        onCameraMoveStarted: _onCameraMoveStarted,
                        onCameraMove: _onCameraMove,
                        onCameraIdle: _onCameraIdle,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                      ),
                      // 大頭針固定在地圖中央，拖曳地圖來調整位置；針尖對準中心點。
                      IgnorePointer(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: seniorMode ? 48 : 40,
                            ),
                            child: Icon(
                              Icons.location_on,
                              size: seniorMode ? 48 : 40,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        top: 12,
                        child: _buildSearch(seniorMode),
                      ),
                    ],
                  ),
                ),
                _buildBottomPanel(seniorMode),
              ],
            ),
    );
  }

  Widget _buildSearch(bool seniorMode) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      color: AppColors.creamLight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _search,
            focusNode: _searchFocus,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            style: AppTypography.bodyStyle(
              seniorMode: seniorMode,
              color: AppColors.ink,
            ),
            decoration: InputDecoration(
              hintText: '搜尋地點，例如：富世部落',
              hintStyle: AppTypography.bodyStyle(
                seniorMode: seniorMode,
                color: AppColors.fog,
              ),
              prefixIcon: const Icon(Icons.search, color: AppColors.inkSoft),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        _onSearchChanged('');
                      },
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (_suggestions.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.creamDeep),
                itemBuilder: (context, i) {
                  final s = _suggestions[i];
                  return ListTile(
                    leading: const Icon(
                      Icons.place_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      s.title,
                      style: AppTypography.bodyStyle(
                        seniorMode: seniorMode,
                        color: AppColors.ink,
                      ),
                    ),
                    subtitle: s.subtitle.isEmpty
                        ? null
                        : Text(
                            s.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.captionStyle(
                              seniorMode: seniorMode,
                              color: AppColors.inkSoft,
                            ),
                          ),
                    onTap: () => _selectSuggestion(s),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(bool seniorMode) {
    final name = _name;
    final address = _address;
    final String preview;
    if (_resolving) {
      preview = '正在查詢地址…';
    } else if (_addressFailed || address == null) {
      preview = '這個位置查不到地址，可以移動一點或改用搜尋';
    } else {
      preview = address;
    }
    final canConfirm =
        !_moving && !_resolving && address != null && address.isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.creamLight,
          border: Border(top: BorderSide(color: AppColors.creamDeep)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (name != null && name.isNotEmpty) ...[
              Text(
                name,
                style: AppTypography.bodyLargeStyle(
                  seniorMode: seniorMode,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              preview,
              style: AppTypography.bodyStyle(
                seniorMode: seniorMode,
                color: canConfirm ? AppColors.inkSoft : AppColors.fog,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canConfirm ? _confirm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.creamLight,
                  minimumSize: Size.fromHeight(seniorMode ? 56 : 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  '使用這個位置',
                  style: AppTypography.bodyLargeStyle(
                    seniorMode: seniorMode,
                    color: AppColors.creamLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
