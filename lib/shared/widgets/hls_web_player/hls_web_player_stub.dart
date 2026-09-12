import 'package:flutter/widgets.dart';

/// 非 Web 平台的空實作（手機走 better_player_plus，不會用到這個 widget）。
class HlsWebPlayer extends StatelessWidget {
  final String url;
  final VoidCallback? onError;

  const HlsWebPlayer({super.key, required this.url, this.onError});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
