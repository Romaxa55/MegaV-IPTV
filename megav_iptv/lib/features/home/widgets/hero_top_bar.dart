import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flag/flag.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui_performance.dart';
import '../providers/weather_provider.dart';

class HeroTopBar extends ConsumerStatefulWidget {
  final VoidCallback onSettings;
  const HeroTopBar({super.key, required this.onSettings});

  @override
  ConsumerState<HeroTopBar> createState() => _HeroTopBarState();
}

class _HeroTopBarState extends ConsumerState<HeroTopBar> {
  late Timer _clockTimer;
  String _time = '';

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) => _updateTime());
    // Initial time update is handled in build to ensure we can use ref
  }

  void _updateTime() {
    if (!mounted) return;

    final weatherState = ref.read(weatherProvider);
    DateTime now;

    if (weatherState.hasValue && weatherState.value != null) {
      final offset = weatherState.value!.utcOffsetSeconds;
      now = DateTime.now().toUtc().add(Duration(seconds: offset));
    } else {
      now = DateTime.now();
    }

    final newTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    if (_time != newTime) {
      setState(() => _time = newTime);
    }
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for changes to update time immediately
    ref.listen(weatherProvider, (previous, next) {
      if (next.hasValue && previous?.value?.utcOffsetSeconds != next.value?.utcOffsetSeconds) {
        _updateTime();
      }
    });

    // Ensure we have an initial time
    if (_time.isEmpty) {
      _updateTime();
    }

    final weatherAsync = ref.watch(weatherProvider);
    final isLowPower = effectiveLowPowerUi(context);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 24.h),
          child: Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  boxShadow: isLowPower
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Icon(Icons.tv_rounded, size: 24.sp, color: Colors.white),
              ),
              SizedBox(width: 14.w),
              Text(
                'MegaV',
                style: TextStyle(
                  fontSize: TS.lg.sp,
                  color: Colors.white.withValues(alpha: 0.95),
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                ' IPTV',
                style: TextStyle(fontSize: TS.sm.sp, color: Colors.white.withValues(alpha: 0.40), letterSpacing: 2.5),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: AppColors.chipBg,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppColors.chipBorder),
                ),
                child: weatherAsync.when(
                  data: (data) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flag.fromString(
                        data.countryCode,
                        height: 16.h,
                        width: 24.w,
                        fit: BoxFit.cover,
                        borderRadius: 2.r,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        data.city,
                        style: TextStyle(fontSize: TS.base.sp, color: Colors.white.withValues(alpha: 0.70)),
                      ),
                      _separator(),
                      Icon(_getWeatherIcon(data.weatherCode), size: 20.sp, color: _getWeatherColor(data.weatherCode)),
                      SizedBox(width: 6.w),
                      Text(
                        '${data.temperature.round()}°',
                        style: TextStyle(fontSize: TS.base.sp, color: Colors.white.withValues(alpha: 0.70)),
                      ),
                      _separator(),
                      Text(
                        _time,
                        style: TextStyle(fontSize: TS.base.sp, color: Colors.white.withValues(alpha: 0.60)),
                      ),
                    ],
                  ),
                  loading: () => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withValues(alpha: 0.5)),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        _time,
                        style: TextStyle(fontSize: TS.base.sp, color: Colors.white.withValues(alpha: 0.60)),
                      ),
                    ],
                  ),
                  error: (_, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, size: 16.sp, color: Colors.white.withValues(alpha: 0.5)),
                      _separator(),
                      Text(
                        _time,
                        style: TextStyle(fontSize: TS.base.sp, color: Colors.white.withValues(alpha: 0.60)),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              _SettingsButton(onTap: widget.onSettings),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code == 1 || code == 2) return Icons.wb_cloudy_rounded;
    if (code == 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 51 && code <= 67) return Icons.water_drop_rounded;
    if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
    if (code >= 80 && code <= 82) return Icons.grain_rounded;
    if (code >= 85 && code <= 86) return Icons.ac_unit_rounded;
    if (code >= 95 && code <= 99) return Icons.thunderstorm_rounded;
    return Icons.cloud_queue_rounded;
  }

  Color _getWeatherColor(int code) {
    if (code == 0) return const Color(0xFFFBBF24); // Sunny (yellow)
    if (code == 1 || code == 2) return const Color(0xFFFCD34D); // Partly cloudy (light yellow)
    if (code == 3) return Colors.white.withValues(alpha: 0.90); // Cloudy (white)
    if (code == 45 || code == 48) return Colors.white.withValues(alpha: 0.60); // Foggy (greyish)
    if (code >= 51 && code <= 67) return const Color(0xFF60A5FA); // Rain (blue)
    if (code >= 71 && code <= 77) return const Color(0xFF93C5FD); // Snow (light blue)
    if (code >= 80 && code <= 82) return const Color(0xFF3B82F6); // Showers (blue)
    if (code >= 85 && code <= 86) return const Color(0xFF93C5FD); // Snow showers
    if (code >= 95 && code <= 99) return const Color(0xFFA78BFA); // Thunderstorm (purple)
    return Colors.white.withValues(alpha: 0.80);
  }

  Widget _separator() => Padding(
    padding: EdgeInsets.symmetric(horizontal: 6.w),
    child: Text(
      '|',
      style: TextStyle(fontSize: TS.base.sp, color: Colors.white.withValues(alpha: 0.15)),
    ),
  );
}

class _SettingsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SettingsButton({required this.onTap});

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
          child: Icon(Icons.settings_outlined, size: 20.sp, color: Colors.white.withValues(alpha: 0.50)),
        ),
      ),
    );
  }
}
