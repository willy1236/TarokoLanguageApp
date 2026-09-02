import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../services/senior_mode_controller.dart';

/// 頭像裁切畫面：讓使用者在選完照片後，自行框選要保留的範圍。
/// 裁切輸出固定為正方形 PNG。
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
          style: TextStyle(fontSize: seniorMode ? AppTypography.title : null),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          iconSize: seniorMode ? 30 : 24,
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
                      fontSize: seniorMode ? AppTypography.title : null,
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
              onCropped: (result) {
                if (!mounted) return;
                switch (result) {
                  case CropSuccess(:final croppedImage):
                    Navigator.pop(context, croppedImage);
                  case CropFailure():
                    setState(() => _isCropping = false);
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        const SnackBar(content: Text('裁切失敗，請重試')),
                      );
                }
              },
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
                  fontSize: AppTypography.title,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
