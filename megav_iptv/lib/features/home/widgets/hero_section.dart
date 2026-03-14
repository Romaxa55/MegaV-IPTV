import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/playlist/models/epg_program.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';

import 'glass_button.dart';

class HeroSection extends ConsumerStatefulWidget {
  final List<Channel> featuredChannels;
  final void Function(Channel channel) onPlay;

  const HeroSection({super.key, required this.featuredChannels, required this.onPlay});

  @override
  ConsumerState<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends ConsumerState<HeroSection> {
  int _heroIndex = 0;
  Timer? _autoRotateTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRotate();
  }

  void _startAutoRotate() {
    _autoRotateTimer?.cancel();
    if (widget.featuredChannels.length <= 1) return;
    _autoRotateTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        setState(() {
          _heroIndex = (_heroIndex + 1) % widget.featuredChannels.length;
        });
      }
    });
  }

  void _goTo(int index) {
    _autoRotateTimer?.cancel();
    setState(() => _heroIndex = index.clamp(0, widget.featuredChannels.length - 1));
    _startAutoRotate();
  }

  /// Navigate hero left/right (available for keyboard binding)
  void goToPrev() => _goTo(_heroIndex > 0 ? _heroIndex - 1 : widget.featuredChannels.length - 1);
  void goToNext() => _goTo((_heroIndex + 1) % widget.featuredChannels.length);

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.featuredChannels.isEmpty) {
      return SizedBox(height: 0.3.sh);
    }

    final channel = widget.featuredChannels[_heroIndex];
    final heroHeight = 0.56.sh;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeroBackdrop(channel: channel),
          _buildGradients(),
          _HeroTopBar(onSettings: () => context.push('/settings')),
          _HeroContent(channel: channel, onPlay: () => widget.onPlay(channel)),
          if (widget.featuredChannels.length > 1)
            _HeroDots(count: widget.featuredChannels.length.clamp(0, 8), activeIndex: _heroIndex, onTap: _goTo),
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

class _HeroBackdrop extends StatelessWidget {
  final Channel channel;
  const _HeroBackdrop({required this.channel});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1200),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 1.05,
              end: 1.0,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
      child: channel.logoUrl != null && channel.logoUrl!.isNotEmpty
          ? Image.network(
              channel.logoUrl!,
              key: ValueKey(channel.url),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (ctx, err, st) => _placeholder(),
            )
          : _placeholder(key: ValueKey(channel.url)),
    );
  }

  Widget _placeholder({Key? key}) {
    return Container(
      key: key,
      color: AppColors.surface,
      child: Center(
        child: Icon(Icons.tv, size: 80.sp, color: AppColors.textHint.withValues(alpha: 0.3)),
      ),
    );
  }
}

class _HeroTopBar extends StatelessWidget {
  final VoidCallback onSettings;
  const _HeroTopBar({required this.onSettings});

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
                child: Icon(Icons.tv, size: 20.sp, color: Colors.white),
              ),
              SizedBox(width: 12.w),
              Text(
                'MegaV',
                style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.95), letterSpacing: 1.5),
              ),
              Text(
                ' IPTV',
                style: TextStyle(fontSize: 10.sp, color: Colors.white.withValues(alpha: 0.3), letterSpacing: 2),
              ),
              const Spacer(),
              GlassButton(icon: Icons.settings, onTap: onSettings),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroContent extends ConsumerWidget {
  final Channel channel;
  final VoidCallback onPlay;

  const _HeroContent({required this.channel, required this.onPlay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tvgId = channel.tvgId;
    final nowAsync = tvgId != null && tvgId.isNotEmpty
        ? ref.watch(currentProgramProvider(tvgId))
        : const AsyncValue<EpgProgram?>.data(null);

    return Positioned(
      bottom: 48.h,
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
          key: ValueKey(channel.url),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBadges(nowAsync),
            SizedBox(height: 12.h),
            Text(
              channel.name,
              style: TextStyle(
                fontSize: 36.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 20, color: Colors.black54)],
              ),
            ),
            if (channel.groupTitle != null) ...[
              SizedBox(height: 4.h),
              Text(
                channel.groupTitle!,
                style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.4)),
              ),
            ],
            SizedBox(height: 8.h),
            nowAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, st) => const SizedBox.shrink(),
              data: (prog) => _buildProgramInfo(prog),
            ),
            SizedBox(height: 16.h),
            _buildActions(onPlay),
          ],
        ),
      ),
    );
  }

  Widget _buildBadges(AsyncValue<EpgProgram?> nowAsync) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 4.h,
      children: [
        nowAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, st) => const SizedBox.shrink(),
          data: (prog) {
            if (prog != null && prog.isNow) {
              return _Badge(text: 'В ЭФИРЕ', color: AppColors.liveBadge, showPulse: true);
            }
            return const SizedBox.shrink();
          },
        ),
        _Badge(
          text: channel.groupTitle ?? 'TV',
          color: Colors.white.withValues(alpha: 0.1),
          textColor: Colors.white.withValues(alpha: 0.6),
        ),
      ],
    );
  }

  Widget _buildProgramInfo(EpgProgram? prog) {
    if (prog == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prog.title,
          style: TextStyle(fontSize: 16.sp, color: Colors.white.withValues(alpha: 0.7)),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (prog.isNow) ...[
          SizedBox(height: 8.h),
          SizedBox(
            width: 400.w,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 12.sp, color: Colors.white.withValues(alpha: 0.25)),
                    SizedBox(width: 6.w),
                    Text(
                      '${_formatTime(prog.start)} — ${_formatTime(prog.end)}',
                      style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.35)),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
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
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions(VoidCallback onPlay) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          child: InkWell(
            onTap: onPlay,
            borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 12.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, size: 18.sp, color: AppColors.background),
                  SizedBox(width: 8.w),
                  Text(
                    'Смотреть',
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.background),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _HeroDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  final void Function(int) onTap;

  const _HeroDots({required this.count, required this.activeIndex, required this.onTap});

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

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final Color? textColor;
  final bool showPulse;

  const _Badge({required this.text, required this.color, this.textColor, this.showPulse = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: color == AppColors.liveBadge ? 0.9 : null),
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: color == AppColors.liveBadge
            ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPulse) ...[_PulsingDot(), SizedBox(width: 6.w)],
          Text(
            text,
            style: TextStyle(fontSize: 11.sp, color: textColor ?? Colors.white, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.4 + 0.6 * _controller.value,
          child: Container(
            width: 6.w,
            height: 6.w,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        );
      },
    );
  }
}
