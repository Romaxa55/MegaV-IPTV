import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/playlist/models/now_playing.dart';
import '../../../core/theme/app_colors.dart';

import 'hero_backdrop.dart';
import 'hero_badges.dart';
import 'hero_top_bar.dart';

class HeroSection extends StatefulWidget {
  final List<NowPlayingItem> featuredItems;
  final NowPlayingItem? overrideItem;
  final void Function(NowPlayingItem item) onPlay;
  final Widget? videoWidget;

  const HeroSection({
    super.key,
    required this.featuredItems,
    this.overrideItem,
    required this.onPlay,
    this.videoWidget,
  });

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {
  static const Duration _carouselInterval = Duration(seconds: 8);

  Timer? _carouselTimer;
  int _carouselIndex = 0;

  NowPlayingItem? get _effectiveItem {
    if (widget.overrideItem != null) return widget.overrideItem;
    if (widget.featuredItems.isEmpty) return null;
    return widget.featuredItems[_carouselIndex % widget.featuredItems.length];
  }

  @override
  void initState() {
    super.initState();
    _restartCarousel();
  }

  @override
  void didUpdateWidget(HeroSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLen = oldWidget.featuredItems.length;
    final newLen = widget.featuredItems.length;
    final oldOverride = oldWidget.overrideItem?.channelId;
    final newOverride = widget.overrideItem?.channelId;
    if (_carouselIndex >= newLen) _carouselIndex = 0;
    if (oldOverride != newOverride || oldLen != newLen) {
      _restartCarousel();
    }
  }

  void _restartCarousel() {
    _carouselTimer?.cancel();
    _carouselTimer = null;
    if (widget.overrideItem != null) return;
    if (widget.featuredItems.length < 2) return;
    _carouselTimer = Timer.periodic(_carouselInterval, (_) {
      if (!mounted || widget.overrideItem != null) return;
      setState(() {
        _carouselIndex = (_carouselIndex + 1) % widget.featuredItems.length;
      });
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.featuredItems.isEmpty && widget.overrideItem == null) return const SizedBox.expand();

    final item = _effectiveItem;
    if (item == null) return const SizedBox.expand();

    final showDots = widget.overrideItem == null && widget.featuredItems.length > 1;

    return ClipRect(
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            HeroBackdrop(
              key: ValueKey('hero_backdrop_${item.channelId}'),
              imageUrl: item.thumbnailUrl ?? item.program.icon ?? item.logoUrl,
            ),
            if (widget.videoWidget != null) widget.videoWidget!,
            _buildGradients(),
            HeroTopBar(onSettings: () => context.push('/settings')),
            _HeroContent(item: item, onPlay: () => widget.onPlay(item)),
            if (showDots) _buildPageDots(),
          ],
        ),
      ),
    );
  }

  Widget _buildPageDots() {
    final n = widget.featuredItems.length;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 10.h,
      child: IgnorePointer(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(n, (i) {
            final active = i == _carouselIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              margin: EdgeInsets.symmetric(horizontal: 3.w),
              width: active ? 18.w : 6.w,
              height: 6.h,
              decoration: BoxDecoration(
                color: active ? AppColors.primaryLight : Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999.r),
              ),
            );
          }),
        ),
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
      bottom: 24.h,
      left: 40.w,
      child: SizedBox(
        width: 0.55.sw,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeOut,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(alignment: Alignment.topLeft, children: <Widget>[...previousChildren, ?currentChild]);
          },
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Column(
            key: ValueKey('hero_${item.channelId}_${prog.id}_${prog.title}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildChannelLogo(),
              SizedBox(height: 10.h),
              _buildBadges(),
              SizedBox(height: 8.h),
              Text(
                prog.title,
                style: TextStyle(
                  fontSize: 42.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                  letterSpacing: -0.5,
                  shadows: const [Shadow(blurRadius: 24, color: Colors.black87)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (prog.description != null && prog.description!.isNotEmpty) ...[
                SizedBox(height: 6.h),
                Text(
                  prog.description!,
                  style: TextStyle(fontSize: TS.sm.sp, color: Colors.white.withValues(alpha: 0.6), height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: 6.h),
              _buildMetaRow(),
              if (prog.isNow) ...[SizedBox(height: 8.h), _buildProgressBar()],
              SizedBox(height: 14.h),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelLogo() {
    final logoUrl = item.logoUrl;
    if (logoUrl == null || logoUrl.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: Image.network(
        logoUrl,
        width: 48.w,
        height: 48.w,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
          color: AppColors.primary.withValues(alpha: 0.2),
          textColor: AppColors.primaryLight,
        ),
        if (item.program.category != null)
          HeroBadge(
            text: item.program.category!,
            color: Colors.white.withValues(alpha: 0.1),
            textColor: Colors.white.withValues(alpha: 0.7),
          ),
      ],
    );
  }

  Widget _buildMetaRow() {
    final prog = item.program;
    final hash = prog.title.hashCode.abs();
    final rating = 6.0 + (hash % 40) / 10.0;

    return Row(
      children: [
        Icon(Icons.star_rounded, size: TS.lg.sp, color: AppColors.ratingGold),
        SizedBox(width: 4.w),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(fontSize: TS.sm.sp, color: AppColors.ratingGold, fontWeight: FontWeight.w600),
        ),
        _dot(),
        if (prog.category != null) ...[
          Text(
            prog.category!,
            style: TextStyle(fontSize: TS.sm.sp, color: Colors.white.withValues(alpha: 0.6)),
          ),
          _dot(),
        ],
        Text(
          _formatDuration(prog.duration),
          style: TextStyle(fontSize: TS.sm.sp, color: Colors.white.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  Widget _dot() => Padding(
    padding: EdgeInsets.symmetric(horizontal: 6.w),
    child: Text(
      '·',
      style: TextStyle(fontSize: TS.lg.sp, color: Colors.white.withValues(alpha: 0.2)),
    ),
  );

  Widget _buildProgressBar() {
    final prog = item.program;
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.schedule_rounded, size: TS.sm.sp, color: Colors.white.withValues(alpha: 0.3)),
            SizedBox(width: 4.w),
            Text(
              '${_fmtTime(prog.start)} — ${_fmtTime(prog.end)}',
              style: TextStyle(fontSize: TS.sm.sp, color: Colors.white.withValues(alpha: 0.5)),
            ),
            const Spacer(),
            Text(
              'ещё ${_formatDuration(prog.remaining)}',
              style: TextStyle(fontSize: TS.sm.sp, color: Colors.white.withValues(alpha: 0.4)),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: SizedBox(
            height: 6.h,
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
          child: Focus(
            onKeyEvent: (node, event) {
              // Prevent jumping from the Play button diagonally into the 6th card of the row below.
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight) {
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: InkWell(
              onTap: onPlay,
              borderRadius: BorderRadius.circular(12.r),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 12.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, size: TS.xl.sp, color: AppColors.background),
                    SizedBox(width: 8.w),
                    Text(
                      'Смотреть',
                      style: TextStyle(fontSize: TS.lg.sp, fontWeight: FontWeight.w600, color: AppColors.background),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.logoUrl != null && item.logoUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: Image.network(
                    item.logoUrl!,
                    width: 24.w,
                    height: 24.w,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.tv, size: TS.sm.sp, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                )
              else
                Icon(Icons.tv, size: TS.sm.sp, color: Colors.white.withValues(alpha: 0.7)),
              SizedBox(width: 6.w),
              Text(
                item.channelName,
                style: TextStyle(fontSize: TS.lg.sp, color: Colors.white.withValues(alpha: 0.7)),
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
