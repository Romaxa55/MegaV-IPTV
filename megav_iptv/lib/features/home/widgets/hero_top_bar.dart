import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'glass_button.dart';

class HeroTopBar extends StatefulWidget {
  final VoidCallback onSettings;
  const HeroTopBar({super.key, required this.onSettings});

  @override
  State<HeroTopBar> createState() => _HeroTopBarState();
}

class _HeroTopBarState extends State<HeroTopBar> {
  late Timer _clockTimer;
  String _time = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() => _time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 20.h),
          child: Row(
            children: [
              // Logo
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.tv, size: TS.xl.sp, color: Colors.white),
              ),
              SizedBox(width: 12.w),
              Text(
                'MegaV',
                style: TextStyle(
                  fontSize: TS.sm.sp,
                  color: Colors.white.withValues(alpha: 0.95),
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                ' IPTV',
                style: TextStyle(fontSize: TS.t10.sp, color: Colors.white.withValues(alpha: 0.3), letterSpacing: 2),
              ),
              const Spacer(),
              // Geo + Weather + Time chip
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('📍', style: TextStyle(fontSize: TS.sm.sp)),
                    SizedBox(width: 4.w),
                    Text(
                      'Локация',
                      style: TextStyle(fontSize: TS.xs.sp, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    SizedBox(width: 10.w),
                    Text('☁️', style: TextStyle(fontSize: TS.sm.sp)),
                    SizedBox(width: 4.w),
                    Text(
                      '--°',
                      style: TextStyle(fontSize: TS.xs.sp, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                _time,
                style: TextStyle(fontSize: TS.sm.sp, color: Colors.white.withValues(alpha: 0.6)),
              ),
              SizedBox(width: 12.w),
              GlassButton(icon: Icons.settings, onTap: widget.onSettings),
            ],
          ),
        ),
      ),
    );
  }
}
