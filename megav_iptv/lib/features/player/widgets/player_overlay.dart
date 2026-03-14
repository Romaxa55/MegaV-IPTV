import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

enum PlayerOverlayMode { none, epg, channels, info, similar }

class PlayerControlsOverlay extends StatelessWidget {
  final String channelName;
  final String? groupName;
  final String channelId;
  final String? logoUrl;
  final VoidCallback onBack;
  final VoidCallback onChannelUp;
  final VoidCallback onChannelDown;
  final PlayerOverlayMode activeOverlay;
  final void Function(PlayerOverlayMode) onToggleOverlay;

  const PlayerControlsOverlay({
    super.key,
    required this.channelName,
    this.groupName,
    required this.channelId,
    this.logoUrl,
    required this.onBack,
    required this.onChannelUp,
    required this.onChannelDown,
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
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 140.h,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
              ),
            ),
          ),
        ),
        _buildTopBar(context),
        _buildBottomBar(),
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
              SizedBox(width: 12.w),
              if (logoUrl != null && logoUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: Image.network(
                    logoUrl!,
                    width: 32.w,
                    height: 32.w,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) => SizedBox(width: 32.w),
                  ),
                ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channelName,
                      style: TextStyle(fontSize: 16.sp, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    if (groupName != null)
                      Text(
                        groupName!,
                        style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.4)),
                      ),
                  ],
                ),
              ),
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

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Row(
            children: [
              _GlassIconButton(icon: Icons.skip_previous, onTap: onChannelDown),
              SizedBox(width: 8.w),
              Container(
                width: 56.w,
                height: 56.w,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.pause, size: 24.sp, color: AppColors.background),
              ),
              SizedBox(width: 8.w),
              _GlassIconButton(icon: Icons.skip_next, onTap: onChannelUp),
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GlassIconButton(icon: Icons.keyboard_arrow_up, size: 36, onTap: onChannelUp),
                  SizedBox(height: 2.h),
                  _GlassIconButton(icon: Icons.keyboard_arrow_down, size: 36, onTap: onChannelDown),
                ],
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

  const _GlassIconButton({required this.icon, required this.onTap, this.size = 44});

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
              width: size.w,
              height: size.w,
              child: Icon(icon, size: (size * 0.45).sp, color: Colors.white),
            ),
          ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: isActive ? AppColors.primary.withValues(alpha: 0.3) : AppColors.glassButtonBg,
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
              child: Icon(icon, size: 18.sp, color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ),
    );
  }
}
