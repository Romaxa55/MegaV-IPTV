import 'dart:math';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui_performance.dart';

/// Hero background: uses a slow zoom/pan effect (Ken Burns)
/// and [Image.gaplessPlayback] to avoid blinking on load.
class HeroBackdrop extends StatefulWidget {
  final String? imageUrl;
  const HeroBackdrop({super.key, this.imageUrl});

  @override
  State<HeroBackdrop> createState() => _HeroBackdropState();
}

class _HeroBackdropState extends State<HeroBackdrop> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scaleAnimation;
  Alignment _alignEnd = Alignment.center;
  final _random = Random();
  bool _isLowPower = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasLowPower = _isLowPower;
    _isLowPower = effectiveLowPowerUi(context);

    if (_isLowPower) {
      if (_controller != null) {
        _controller?.dispose();
        _controller = null;
      }
    } else {
      if (_controller == null) {
        _controller = AnimationController(vsync: this, duration: const Duration(seconds: 30));
        _generateAnimations();
        _controller?.forward();
      } else if (wasLowPower) {
        // we transitioned from low power to high power
        _generateAnimations();
        _controller?.forward(from: 0.0);
      }
    }
  }

  @override
  void didUpdateWidget(HeroBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      if (!_isLowPower && _controller != null) {
        _controller?.stop();
        _generateAnimations();
        _controller?.forward(from: 0.0);
      }
    }
  }

  void _generateAnimations() {
    if (_controller == null) return;

    // Zoom slowly
    _scaleAnimation = Tween<double>(
      begin: 1.05,
      end: 1.20,
    ).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeInOutSine));

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
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return _placeholder();
    }

    final image = Image.network(
      widget.imageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: 1280,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) => _placeholder(),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Stable base so we never flash to black
        const ColoredBox(color: AppColors.surface),
        if (_isLowPower || _controller == null || _scaleAnimation == null)
          Transform.scale(scale: 1.05, child: image)
        else
          AnimatedBuilder(
            animation: _controller!,
            builder: (context, child) {
              final currentAlign = Alignment.lerp(Alignment.center, _alignEnd, _controller!.value)!;
              return Transform.scale(alignment: currentAlign, scale: _scaleAnimation!.value, child: child);
            },
            child: image,
          ),
      ],
    );
  }

  Widget _placeholder() {
    return const ColoredBox(color: AppColors.surface);
  }
}
