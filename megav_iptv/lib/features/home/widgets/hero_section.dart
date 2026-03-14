import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/playlist/models/now_playing.dart';
import '../../../core/theme/app_colors.dart';

import 'hero_backdrop.dart';
import 'hero_badges.dart';
import 'hero_dots.dart';
import 'hero_top_bar.dart';

class HeroSection extends StatefulWidget {
  final List<NowPlayingItem> featuredItems;
  final void Function(NowPlayingItem item) onPlay;

  const HeroSection({super.key, required this.featuredItems, required this.onPlay});

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {
  int _heroIndex = 0;
  Timer? _autoRotateTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRotate();
  }

  void _startAutoRotate() {
    _autoRotateTimer?.cancel();
    if (widget.featuredItems.length <= 1) return;
    _autoRotateTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        setState(() {
          _heroIndex = (_heroIndex + 1) % widget.featuredItems.length;
        });
      }
    });
  }

  void _goTo(int index) {
    _autoRotateTimer?.cancel();
    setState(() => _heroIndex = index.clamp(0, widget.featuredItems.length - 1));
    _startAutoRotate();
  }

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.featuredItems.isEmpty) return SizedBox(height: 0.3.sh);

    final item = widget.featuredItems[_heroIndex];
    final heroHeight = 0.42.sh;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          HeroBackdrop(imageUrl: item.thumbnailUrl ?? item.program.icon ?? item.logoUrl),
          _buildGradients(),
          HeroTopBar(onSettings: () => context.push('/settings')),
          _HeroContent(item: item, onPlay: () => widget.onPlay(item)),
          if (widget.featuredItems.length > 1)
            HeroDots(count: widget.featuredItems.length.clamp(0, 8), activeIndex: _heroIndex, onTap: _goTo),
        ],
      ),
    );
  }

  Widget _buildGradients() {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [AppColors.background, AppColors.background.withValues(alpha: 0.7), Colors.transparent],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [AppColors.background, Colors.transparent, AppColors.background.withValues(alpha: 0.5)],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 120.h,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AppColors.background, Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  final NowPlayingItem item;
  final VoidCallback onPlay;

  const _HeroContent({required this.item, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final prog = item.program;

    return Positioned(
      bottom: 32.h,
      left: 32.w,
      right: 32.w,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
              child: child,
            ),
          );
        },
        child: Column(
          key: ValueKey(prog.id),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBadges(),
            SizedBox(height: 8.h),
            Text(
              prog.title,
              style: TextStyle(
                fontSize: TS.t3xl.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 20, color: Colors.black54)],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            _buildMetaRow(),
            if (prog.description != null && prog.description!.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                prog.description!,
                style: TextStyle(fontSize: TS.sm.sp, color: Colors.white.withValues(alpha: 0.4)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (prog.isNow) ...[SizedBox(height: 10.h), _buildProgressBar()],
            SizedBox(height: 12.h),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildBadges() {
    return Wrap(
      spacing: 6.w,
      runSpacing: 4.h,
      children: [
        if (item.isLive) HeroBadge(text: 'В ЭФИРЕ', color: AppColors.liveBadge.withValues(alpha: 0.9), showPulse: true),
        HeroBadge(
          text: item.channelName,
          color: Colors.white.withValues(alpha: 0.1),
          textColor: Colors.white.withValues(alpha: 0.6),
          icon: Icons.live_tv,
        ),
        if (item.program.category != null)
          HeroBadge(
            text: item.program.category!,
            color: Colors.white.withValues(alpha: 0.06),
            textColor: Colors.white.withValues(alpha: 0.4),
          ),
      ],
    );
  }

  Widget _buildMetaRow() {
    final prog = item.program;
    return Row(
      children: [
        if (prog.category != null) ...[
          Text(
            prog.category!,
            style: TextStyle(fontSize: TS.xs.sp, color: Colors.white.withValues(alpha: 0.4)),
          ),
          _dot(),
        ],
        Icon(Icons.timer_outlined, size: TS.xs.sp, color: Colors.white.withValues(alpha: 0.25)),
        SizedBox(width: 4.w),
        Text(
          _formatDuration(prog.duration),
          style: TextStyle(fontSize: TS.xs.sp, color: Colors.white.withValues(alpha: 0.4)),
        ),
        _dot(),
        Text(
          '${_fmtTime(prog.start)} — ${_fmtTime(prog.end)}',
          style: TextStyle(fontSize: TS.xs.sp, color: Colors.white.withValues(alpha: 0.35)),
        ),
      ],
    );
  }

  Widget _dot() => Padding(
    padding: EdgeInsets.symmetric(horizontal: 6.w),
    child: Text(
      '•',
      style: TextStyle(fontSize: TS.xs.sp, color: Colors.white.withValues(alpha: 0.15)),
    ),
  );

  Widget _buildProgressBar() {
    final prog = item.program;
    return SizedBox(
      width: 400.w,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'ещё ${_formatDuration(prog.remaining)}',
                style: TextStyle(fontSize: TS.xs.sp, color: Colors.white.withValues(alpha: 0.5)),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: SizedBox(
              height: 5.h,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: prog.progress,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4.r),
                        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          elevation: 4,
          shadowColor: Colors.white.withValues(alpha: 0.1),
          child: InkWell(
            onTap: onPlay,
            borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, size: TS.lg.sp, color: AppColors.background),
                  SizedBox(width: 6.w),
                  Text(
                    'Смотреть',
                    style: TextStyle(fontSize: TS.sm.sp, fontWeight: FontWeight.w600, color: AppColors.background),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tv, size: TS.sm.sp, color: Colors.white.withValues(alpha: 0.7)),
              SizedBox(width: 6.w),
              Text(
                item.channelName,
                style: TextStyle(fontSize: TS.sm.sp, color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours} ч ${d.inMinutes.remainder(60)} мин';
    return '${d.inMinutes} мин';
  }
}
