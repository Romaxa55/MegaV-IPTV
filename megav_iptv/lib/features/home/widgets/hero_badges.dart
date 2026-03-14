import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class HeroBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color? textColor;
  final bool showPulse;
  final IconData? icon;

  const HeroBadge({
    super.key,
    required this.text,
    required this.color,
    this.textColor,
    this.showPulse = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: showPulse ? [BoxShadow(color: AppColors.liveBadge.withValues(alpha: 0.2), blurRadius: 8)] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPulse) ...[const _PulsingDot(), SizedBox(width: 6.w)],
          if (icon != null && !showPulse) ...[
            Icon(icon, size: TS.t11.sp, color: textColor ?? Colors.white),
            SizedBox(width: 4.w),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: TS.t11.sp,
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
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.4 + 0.6 * _controller.value,
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
