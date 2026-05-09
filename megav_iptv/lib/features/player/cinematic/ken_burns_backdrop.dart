import 'package:flutter/material.dart';

/// Static-image fallback shown when no video texture is active. Subtle
/// 30-second ken-burns scale 1.0 → 1.05 imperceptible per-frame work.
///
/// Maps to Req 7, Req 9.1, Req 9.4.
class KenBurnsBackdrop extends StatefulWidget {
  const KenBurnsBackdrop({super.key, required this.imageProvider, required this.active});

  final ImageProvider? imageProvider;
  final bool active;

  @override
  State<KenBurnsBackdrop> createState() => _KenBurnsBackdropState();
}

class _KenBurnsBackdropState extends State<KenBurnsBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 30));
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(KenBurnsBackdrop old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) {
      if (widget.active) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageProvider == null) return const SizedBox.expand();
    return Visibility(
      visible: widget.active,
      maintainState: false,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(scale: 1.0 + 0.05 * _controller.value, child: child);
        },
        child: Image(image: widget.imageProvider!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
      ),
    );
  }
}
