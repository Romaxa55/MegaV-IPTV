import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';

class GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const GlassButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chipBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: AppColors.chipBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: SizedBox(
          width: 48.w,
          height: 48.w,
          child: Icon(icon, size: 20.sp, color: Colors.white.withValues(alpha: 0.50)),
        ),
      ),
    );
  }
}
