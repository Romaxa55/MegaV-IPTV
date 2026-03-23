import 'dart:math';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Hero background: uses a slow zoom/pan effect (Ken Burns)
/// and [Image.gaplessPlayback] to avoid blinking on load.
class HeroBackdrop extends StatefulWidget {
  final String? imageUrl;
  const HeroBackdrop({super.key, this.imageUrl});

  @override
  State<HeroBackdrop> createState() => _HeroBackdropState();
}

class _HeroBackdropState extends State<HeroBackdrop> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Alignment _alignEnd = Alignment.center;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 30));

    _generateAnimations();
    _controller.forward();
  }

  @override
  void didUpdateWidget(HeroBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _controller.stop();
      _generateAnimations();
      _controller.forward(from: 0.0);
    }
  }

  void _generateAnimations() {
    // Zoom slowly
    _scaleAnimation = Tween<double>(
      begin: 1.05,
      end: 1.20,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));

    // Pick a random alignment to slowly drift towards
    final aligns = [
      Alignment.topLeft,
      Alignment.topCenter,
      Alignment.topRight,
      Alignment.centerLeft,
      Alignment.centerRight,
      Alignment.bottomLeft,
      Alignment.bottomCenter,
      Alignment.bottomRight,
    ];
    _alignEnd = aligns[_random.nextInt(aligns.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return _placeholder();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Stable base so we never flash to black
        const ColoredBox(color: AppColors.surface),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final currentAlign = Alignment.lerp(Alignment.center, _alignEnd, _controller.value)!;
            return Transform(
              alignment: currentAlign,
              transform: Matrix4.identity()..scale(_scaleAnimation.value),
              child: child,
            );
          },
          child: Image.network(
            widget.imageUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: 1280,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, _, _) => _placeholder(),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return const ColoredBox(color: AppColors.surface);
  }
}
