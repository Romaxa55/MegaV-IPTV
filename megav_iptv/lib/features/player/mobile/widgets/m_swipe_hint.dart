import 'package:flutter/material.dart';

/// Pulsing "swipe to change channel" hint badge for the mobile player.
///
/// Animates opacity over a 1.5 s reversing cycle to attract attention to
/// the horizontal-swipe gesture that switches channels (Phase 5 task 5.3
/// of the mobile-adaptive-layout spec). Wrapped in a [RepaintBoundary]
/// so the animation does not invalidate ancestor layers.
class MSwipeHint extends StatefulWidget {
  const MSwipeHint({super.key});

  @override
  State<MSwipeHint> createState() => _MSwipeHintState();
}

class _MSwipeHintState extends State<MSwipeHint> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const Key('m-swipe-hint'),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
          child: const Text('SWIPE ↔ КАНАЛ', style: TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 0.16)),
        ),
      ),
    );
  }
}
