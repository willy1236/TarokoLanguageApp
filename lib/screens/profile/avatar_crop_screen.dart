import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('裁切頭像'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: _isCropping
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.cream,
                    ),
                  )
                : const Text(
                    '確定',
                    style: TextStyle(
                      color: AppColors.cream,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Crop(
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
                ..showSnackBar(const SnackBar(content: Text('裁切失敗，請重試')));
          }
        },
      ),
    );
  }
}
