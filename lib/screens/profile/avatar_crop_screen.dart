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

/// 頭像裁切畫面：讓使用者在選完照片後，自行框選要保留的範圍。
/// 裁切輸出固定為正方形 PNG，邊長不超過 [avatarMaxSide]。
class AvatarCropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  const AvatarCropScreen({super.key, required this.imageBytes});

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  final _controller = CropController();
  bool _isCropping = false;

  void _confirm() {
    if (_isCropping) return;
    setState(() => _isCropping = true);
    _controller.crop();
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
      body: Column(
        children: [
          Expanded(
            child: Crop(
              controller: _controller,
              image: widget.imageBytes,
              aspectRatio: 1,
              withCircleUi: true,
              baseColor: Colors.black,
              maskColor: Colors.black.withValues(alpha: 0.6),
              onCropped: _onCropped,
            ),
          ),
          if (seniorMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                '用兩指縮放，拖曳照片來對齊圓框',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: AppTypography.bodyLarge + AppTypography.seniorStep,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
