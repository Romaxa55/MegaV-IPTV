import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/playlist/models/now_playing.dart';

import 'hero_backdrop.dart';
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

    return ClipRect(
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            HeroBackdrop(
              key: ValueKey('hero_backdrop_${item.channelId}'),
              imageUrl: item.program.icon ?? item.thumbnailUrl ?? item.logoUrl,
            ),
            if (widget.videoWidget != null)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeIn,
                builder: (_, opacity, child) => Opacity(opacity: opacity, child: child),
                child: widget.videoWidget!,
              ),
            _buildGradients(),
            HeroTopBar(onSettings: () => context.push('/settings')),
            _HeroContent(item: item, onPlay: () => widget.onPlay(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildGradients() {
    const bg = Color(0xFF08080F);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.5, 1.0],
                colors: [bg, bg.withValues(alpha: 0.70), Colors.transparent],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0.0, 0.5, 1.0],
                colors: [bg, Colors.transparent, bg.withValues(alpha: 0.50)],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 128.h,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [0.0, 0.20, 0.40, 0.60, 0.80, 1.0],
                  colors: [
                    bg,
                    const Color(0xFF040408).withValues(alpha: 0.80),
                    const Color(0xFF020203).withValues(alpha: 0.60),
                    const Color(0xFF010101).withValues(alpha: 0.40),
                    Colors.black.withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
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
      left: 40.w,
      right: 40.w,
      child: SizedBox(
        width: 0.45.sw,
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
              _buildBadges(),
              SizedBox(height: 8.h),
              Text(
                prog.title,
                style: TextStyle(
                  fontSize: 36.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.1,
                  shadows: const [Shadow(blurRadius: 20, color: Colors.black54, offset: Offset(0, 4))],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              _buildMetaRow(),
              if (prog.synopsis != null) ...[
                SizedBox(height: 8.h),
                SizedBox(
                  width: 672.w,
                  child: Text(
                    prog.synopsis!,
                    style: TextStyle(fontSize: 16.sp, color: Colors.white.withValues(alpha: 0.50), height: 1.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (prog.isNow) ...[SizedBox(height: 10.h), _buildProgressBar()],
              SizedBox(height: 12.h),
              _WatchButton(onPlay: onPlay),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadges() {
    return Row(
      children: [
        if (item.isLive) ...[
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFB2C36).withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.70), shape: BoxShape.circle),
                ),
                SizedBox(width: 6.w),
                Text(
                  'В ЭФИРЕ',
                  style: TextStyle(fontSize: 12.sp, color: Colors.white, letterSpacing: 0.3),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
        ],
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildChannelLogo(14.w),
              SizedBox(width: 6.w),
              Text(
                item.channelName,
                style: TextStyle(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.90)),
              ),
            ],
          ),
        ),
        if (item.program.category != null) ...[
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              item.program.category!,
              style: TextStyle(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.60)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaRow() {
    final prog = item.program;
    final hash = prog.title.hashCode.abs();
    final rating = 6.0 + (hash % 40) / 10.0;
    final year = prog.parsedYear;

    return Row(
      children: [
        Icon(Icons.star_rounded, size: 20.sp, color: const Color(0xFF22C55E)),
        SizedBox(width: 6.w),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(fontSize: 18.sp, color: const Color(0xFF22C55E)),
        ),
        if (year != null) ...[
          _dot(),
          Text(
            year,
            style: TextStyle(fontSize: 16.sp, color: Colors.white.withValues(alpha: 0.60)),
          ),
        ],
        if (prog.category != null) ...[
          _dot(),
          Text(
            prog.category!,
            style: TextStyle(fontSize: 16.sp, color: Colors.white.withValues(alpha: 0.60)),
          ),
        ],
        _dot(),
        Text(
          _formatDuration(prog.duration),
          style: TextStyle(fontSize: 16.sp, color: Colors.white.withValues(alpha: 0.60)),
        ),
      ],
    );
  }

  Widget _dot() => Padding(
    padding: EdgeInsets.symmetric(horizontal: 8.w),
    child: Text(
      '•',
      style: TextStyle(fontSize: 16.sp, color: Colors.white.withValues(alpha: 0.20)),
    ),
  );

  Widget _buildProgressBar() {
    final prog = item.program;
    return SizedBox(
      width: 448.w,
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16.sp, color: Colors.white.withValues(alpha: 0.40)),
              SizedBox(width: 12.w),
              Text(
                _fmtTime(prog.start),
                style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.50)),
              ),
              SizedBox(width: 12.w),
              Text(
                '—',
                style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.25)),
              ),
              SizedBox(width: 12.w),
              Text(
                _fmtTime(prog.end),
                style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.50)),
              ),
              const Spacer(),
              Text(
                'ещё ${_formatDuration(prog.remaining)}',
                style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.60)),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: SizedBox(
              height: 8.h,
              child: Stack(
                children: [
                  Container(color: Colors.white.withValues(alpha: 0.10)),
                  FractionallySizedBox(
                    widthFactor: prog.progress,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA78BFA)]),
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

  Widget _buildChannelLogo(double size) {
    final logoUrl = item.logoUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4.r),
        child: Image.network(
          logoUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          cacheWidth: 64,
          cacheHeight: 64,
          errorBuilder: (_, _, _) => Icon(Icons.tv_rounded, size: size, color: Colors.white.withValues(alpha: 0.60)),
        ),
      );
    }
    return Icon(Icons.tv_rounded, size: size, color: Colors.white.withValues(alpha: 0.60));
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

class _WatchButton extends StatefulWidget {
  final VoidCallback onPlay;
  const _WatchButton({required this.onPlay});

  @override
  State<_WatchButton> createState() => _WatchButtonState();
}

class _WatchButtonState extends State<_WatchButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          elevation: 0,
          child: Focus(
            onFocusChange: (hasFocus) {
              setState(() => _isFocused = hasFocus);
            },
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight) {
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: InkWell(
              onTap: widget.onPlay,
              borderRadius: BorderRadius.circular(12.r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40.h,
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: _isFocused
                      ? Border.all(color: const Color(0xFF6366F1), width: 3.w) // Highlight with primary color
                      : Border.all(color: Colors.transparent, width: 3.w),
                  boxShadow: _isFocused
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 8, spreadRadius: 2),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 18.sp, color: const Color(0xFF08080F)),
                    SizedBox(width: 8.w),
                    Text(
                      'Смотреть',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: const Color(0xFF08080F)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
