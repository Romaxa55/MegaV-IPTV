import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';

class GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const GlassButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: AppColors.glassButtonBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side: BorderSide(color: AppColors.glassBorder),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12.r),
            child: SizedBox(
              width: 40.w,
              height: 40.w,
              child: Icon(icon, size: 18.sp, color: Colors.white.withValues(alpha: 0.35)),
            ),
          ),
        ),
      ),
    );
  }
}
