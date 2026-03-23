import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

enum PlayerOverlayMode { none, epg, channels, info, similar }

class PlayerControlsOverlay extends StatelessWidget {
  final VoidCallback onBack;
  final PlayerOverlayMode activeOverlay;
  final void Function(PlayerOverlayMode) onToggleOverlay;

  const PlayerControlsOverlay({
    super.key,
    required this.onBack,
    required this.activeOverlay,
    required this.onToggleOverlay,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 112.h,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
              ),
            ),
          ),
        ),
        _buildTopBar(context),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Row(
            children: [
              _GlassIconButton(icon: Icons.arrow_back, onTap: onBack),
              const Spacer(),
              _OverlayToggleButton(
                icon: Icons.info_outline,
                mode: PlayerOverlayMode.info,
                activeOverlay: activeOverlay,
                onTap: () => onToggleOverlay(PlayerOverlayMode.info),
              ),
              SizedBox(width: 6.w),
              _OverlayToggleButton(
                icon: Icons.calendar_month,
                mode: PlayerOverlayMode.epg,
                activeOverlay: activeOverlay,
                onTap: () => onToggleOverlay(PlayerOverlayMode.epg),
              ),
              SizedBox(width: 6.w),
              _OverlayToggleButton(
                icon: Icons.list,
                mode: PlayerOverlayMode.channels,
                activeOverlay: activeOverlay,
                onTap: () => onToggleOverlay(PlayerOverlayMode.channels),
              ),
              SizedBox(width: 6.w),
              _OverlayToggleButton(
                icon: Icons.auto_awesome,
                mode: PlayerOverlayMode.similar,
                activeOverlay: activeOverlay,
                onTap: () => onToggleOverlay(PlayerOverlayMode.similar),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: AppColors.glassBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: SizedBox(
          width: size.w,
          height: size.w,
          child: Icon(icon, size: (size * 0.45).sp, color: Colors.white),
        ),
      ),
    );
  }
}

class _OverlayToggleButton extends StatelessWidget {
  final IconData icon;
  final PlayerOverlayMode mode;
  final PlayerOverlayMode activeOverlay;
  final VoidCallback onTap;

  const _OverlayToggleButton({
    required this.icon,
    required this.mode,
    required this.activeOverlay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = activeOverlay == mode;
    return Material(
      color: isActive ? AppColors.primary.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.85),
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
          child: Icon(icon, size: 18.sp, color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
