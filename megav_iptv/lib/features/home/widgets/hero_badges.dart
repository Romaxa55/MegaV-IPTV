import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui_performance.dart';

class HeroBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color? textColor;
  final Color? borderColor;
  final bool showPulse;
  final IconData? icon;

  const HeroBadge({
    super.key,
    required this.text,
    required this.color,
    this.textColor,
    this.borderColor,
    this.showPulse = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isLowPower = effectiveLowPowerUi(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12.r),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        boxShadow: (showPulse && !isLowPower)
            ? [BoxShadow(color: AppColors.liveBadge.withValues(alpha: 0.20), blurRadius: 8)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPulse) ...[const _PulsingDot(), SizedBox(width: 6.w)],
          if (icon != null && !showPulse) ...[
            Icon(icon, size: TS.sm.sp, color: textColor ?? Colors.white),
            SizedBox(width: 4.w),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: TS.sm.sp,
              color: textColor ?? Colors.white,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _isLowPower = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isLowPower = effectiveLowPowerUi(context);

    if (_isLowPower) {
      _controller?.dispose();
      _controller = null;
    } else {
      _controller ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLowPower || _controller == null) {
      return Opacity(
        opacity: 0.85,
        child: Container(
          width: 6.w,
          height: 6.w,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        return Opacity(
          opacity: 0.4 + 0.6 * _controller!.value,
          child: Container(
            width: 6.w,
            height: 6.w,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        );
      },
    );
  }
}
