import 'package:flutter/widgets.dart';

/// 小米幣圖示，取代原本以 Icons.grain 暫代的位置。
class MilletCoinIcon extends StatelessWidget {
  final double size;

  const MilletCoinIcon({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/millet_coin.png',
      width: size,
      height: size,
    );
  }
}
