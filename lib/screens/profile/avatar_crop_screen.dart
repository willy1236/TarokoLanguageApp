import 'dart:math';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icon_size.dart';
import '../../core/constants/app_typography.dart';
import '../../services/senior_mode_controller.dart';

/// 上傳頭像的最大邊長。相機原圖裁切後原解析度的 PNG 會超過後端 8MB 上限，
/// 後端最後縮成 512×512，這裡縮到 1024 已綽綽有餘。
const avatarMaxSide = 1024;

/// 裁切結果縮到邊長 [avatarMaxSide] 以內（已小於就不動），一律輸出 PNG。
/// 去掉 EXIF：裁切輸出的像素已是畫面上看到的方向，留著方向標記會被再轉一次。
/// 解不開時原樣回傳。
@visibleForTesting
Uint8List shrinkAvatar(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final out = max(decoded.width, decoded.height) <= avatarMaxSide
      ? decoded
      : img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? avatarMaxSide : null,
          height: decoded.height > decoded.width ? avatarMaxSide : null,
          interpolation: img.Interpolation.average,
        );
  out.exif = img.ExifData();
  return img.encodePng(out);
}

/// 照片向右轉 90 度（裁切畫面的旋轉鈕用）。先套用 EXIF 方向再轉、去掉 EXIF，
/// 轉完的像素就是畫面上看到的方向；有透明度的存 PNG，其餘存 JPEG 以免大圖編碼太慢。
/// 解不開時原樣回傳。
@visibleForTesting
Uint8List rotateAvatarSource(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final rotated = img.copyRotate(img.bakeOrientation(decoded), angle: 90)
    ..exif = img.ExifData();
  return rotated.hasAlpha
      ? img.encodePng(rotated)
      : img.encodeJpg(rotated, quality: 95);
}

/// 頭像裁切畫面：讓使用者在選完照片後，自行框選要保留的範圍。
/// 可雙指縮放、拖曳照片，按旋轉鈕向右轉 90 度。
/// 裁切輸出固定為正方形 PNG，邊長不超過 [avatarMaxSide]。
class AvatarCropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  const AvatarCropScreen({super.key, required this.imageBytes});

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  final _controller = CropController();
  late Uint8List _image = widget.imageBytes;
  bool _isCropping = false;
  bool _isRotating = false;

  void _confirm() {
    if (_isCropping || _isRotating) return;
    setState(() => _isCropping = true);
    _controller.crop();
  }

  /// 旋轉在 compute 內解碼、轉向、編碼，大圖也不卡畫面；換圖後裁切框重設。
  Future<void> _rotate() async {
    if (_isCropping || _isRotating) return;
    setState(() => _isRotating = true);
    try {
      final rotated = await compute(rotateAvatarSource, _image);
      if (!mounted) return;
      setState(() => _image = rotated);
    } catch (e) {
      debugPrint('AvatarCropScreen: 旋轉失敗：$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('旋轉失敗，請重試')));
    } finally {
      if (mounted) setState(() => _isRotating = false);
    }
  }

  Future<void> _onCropped(CropResult result) async {
    if (!mounted) return;
    if (result case CropSuccess(:final croppedImage)) {
      try {
        // Web 上 compute 會退回主執行緒，照樣可用。
        final avatar = await compute(shrinkAvatar, croppedImage);
        if (!mounted) return;
        Navigator.pop(context, avatar);
        return;
      } catch (e) {
        debugPrint('AvatarCropScreen: 縮圖失敗：$e');
        if (!mounted) return;
      }
    }
    setState(() => _isCropping = false);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('裁切失敗，請重試')));
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '裁切頭像',
          style: TextStyle(
            fontSize: seniorMode
                ? AppTypography.bodyLarge + AppTypography.seniorStep
                : null,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          iconSize: AppIconSize.action(seniorMode),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _confirm,
            style: seniorMode
                ? TextButton.styleFrom(minimumSize: const Size(72, 48))
                : null,
            child: _isCropping
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.cream,
                    ),
                  )
                : Text(
                    '確定',
                    style: TextStyle(
                      color: AppColors.cream,
                      fontWeight: FontWeight.bold,
                      fontSize: seniorMode
                          ? AppTypography.bodyLarge + AppTypography.seniorStep
                          : null,
                    ),
                  ),
          ),
        ],
      ),
      // 底部旋轉鈕不能被手勢列／Home 指示條蓋住。
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Crop(
                // 換圖時重建：Crop 只在第一次建立時解析圖片尺寸。
                key: ObjectKey(_image),
                controller: _controller,
                image: _image,
                interactive: true,
                aspectRatio: 1,
                withCircleUi: true,
                baseColor: Colors.black,
                maskColor: Colors.black.withValues(alpha: 0.6),
                onCropped: _onCropped,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: IconButton(
                tooltip: '向右轉 90 度',
                onPressed: _isRotating || _isCropping ? null : _rotate,
                iconSize: AppIconSize.action(seniorMode),
                constraints: const BoxConstraints(
                  minWidth: AppIconSize.tapTarget,
                  minHeight: AppIconSize.tapTarget,
                ),
                color: Colors.white,
                icon: _isRotating
                    ? SizedBox.square(
                        dimension: AppIconSize.action(seniorMode),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.cream,
                        ),
                      )
                    : const Icon(Icons.rotate_90_degrees_cw),
              ),
            ),
            if (seniorMode)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Text(
                  '用兩指縮放，拖曳照片來對齊圓框',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize:
                        AppTypography.bodyLarge + AppTypography.seniorStep,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
