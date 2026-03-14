import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HeroDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  final void Function(int) onTap;

  const HeroDots({super.key, required this.count, required this.activeIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24.h,
      right: 32.w,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final isActive = i == activeIndex;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.symmetric(horizontal: 3.w),
              width: isActive ? 24.w : 6.w,
              height: 6.h,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          );
        }),
      ),
    );
  }
}
