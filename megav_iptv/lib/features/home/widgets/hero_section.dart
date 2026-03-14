import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/playlist/models/epg_program.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';

import 'hero_backdrop.dart';
import 'hero_badges.dart';
import 'hero_dots.dart';
import 'hero_top_bar.dart';

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

  void goToPrev() => _goTo(_heroIndex > 0 ? _heroIndex - 1 : widget.featuredChannels.length - 1);
  void goToNext() => _goTo((_heroIndex + 1) % widget.featuredChannels.length);

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.featuredChannels.isEmpty) return SizedBox(height: 0.3.sh);

    final channel = widget.featuredChannels[_heroIndex];
    final heroHeight = 0.56.sh;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          HeroBackdrop(channel: channel),
          _buildGradients(),
          HeroTopBar(onSettings: () => context.push('/settings')),
          _HeroContent(channel: channel, onPlay: () => widget.onPlay(channel)),
          if (widget.featuredChannels.length > 1)
            HeroDots(count: widget.featuredChannels.length.clamp(0, 8), activeIndex: _heroIndex, onTap: _goTo),
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

// --- Backdrop extracted to hero_backdrop.dart ---

// --- Top Bar removed and extracted to hero_top_bar.dart ---

// --- Hero Content ---
class _HeroContent extends ConsumerWidget {
  final Channel channel;
  final VoidCallback onPlay;

  const _HeroContent({required this.channel, required this.onPlay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = channel.id;
    final nowAsync = ref.watch(currentProgramProvider(key));
    final upcomingAsync = ref.watch(upcomingProgramsProvider(key));

    return Positioned(
      bottom: 40.h,
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
        child: Row(
          key: ValueKey(channel.url),
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _buildLeftContent(nowAsync)),
            SizedBox(width: 24.w),
            _buildMiniEpg(key, nowAsync, upcomingAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftContent(AsyncValue<EpgProgram?> nowAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badges
        _buildBadges(nowAsync),
        SizedBox(height: 10.h),
        // Title (channel name or EPG program title)
        nowAsync.when(
          loading: () => _channelTitle(),
          error: (e, st) => _channelTitle(),
          data: (prog) {
            if (prog != null && prog.isNow) {
              return Text(
                prog.title,
                style: TextStyle(
                  fontSize: TS.t4xl.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: const [Shadow(blurRadius: 20, color: Colors.black54)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
            }
            return _channelTitle();
          },
        ),
        // Subtitle (group)
        if (channel.groupTitle != null) ...[
          SizedBox(height: 2.h),
          Text(
            channel.groupTitle!,
            style: TextStyle(fontSize: TS.sm.sp, color: Colors.white.withValues(alpha: 0.25)),
          ),
        ],
        SizedBox(height: 6.h),
        // Rating + meta row
        _buildMetaRow(nowAsync),
        SizedBox(height: 6.h),
        // Description
        nowAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, st) => const SizedBox.shrink(),
          data: (prog) {
            if (prog?.description == null || prog!.description!.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Text(
                prog.description!,
                style: TextStyle(fontSize: TS.sm.sp, color: Colors.white.withValues(alpha: 0.4)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
        // Progress bar
        _buildProgressBar(nowAsync),
        SizedBox(height: 14.h),
        // CTA button
        _buildActions(),
      ],
    );
  }

  Widget _channelTitle() {
    return Text(
      channel.name,
      style: TextStyle(
        fontSize: TS.t4xl.sp,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        shadows: const [Shadow(blurRadius: 20, color: Colors.black54)],
      ),
    );
  }

  Widget _buildBadges(AsyncValue<EpgProgram?> nowAsync) {
    return Wrap(
      spacing: 6.w,
      runSpacing: 4.h,
      children: [
        nowAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, st) => const SizedBox.shrink(),
          data: (prog) {
            if (prog != null && prog.isNow) {
              return HeroBadge(text: 'В ЭФИРЕ', color: AppColors.liveBadge.withValues(alpha: 0.9), showPulse: true);
            }
            return const SizedBox.shrink();
          },
        ),
        HeroBadge(
          text: channel.groupTitle ?? 'TV',
          color: Colors.white.withValues(alpha: 0.15),
          textColor: Colors.white.withValues(alpha: 0.8),
          icon: Icons.live_tv,
        ),
        nowAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, st) => const SizedBox.shrink(),
          data: (prog) {
            if (prog?.category != null && prog!.category!.isNotEmpty) {
              return HeroBadge(
                text: prog.category!,
                color: Colors.white.withValues(alpha: 0.1),
                textColor: Colors.white.withValues(alpha: 0.6),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildMetaRow(AsyncValue<EpgProgram?> nowAsync) {
    return nowAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (prog) {
        if (prog == null) return const SizedBox.shrink();
        return Row(
          children: [
            Icon(Icons.star_rounded, size: TS.sm.sp, color: AppColors.ratingGold),
            SizedBox(width: 3.w),
            Text(
              '7.8',
              style: TextStyle(fontSize: TS.sm.sp, color: AppColors.ratingGold),
            ),
            _dot(),
            if (prog.category != null) ...[
              Text(
                prog.category!,
                style: TextStyle(fontSize: TS.xs.sp, color: Colors.white.withValues(alpha: 0.4)),
              ),
              _dot(),
            ],
            Text(
              _formatDuration(prog.duration),
              style: TextStyle(fontSize: TS.xs.sp, color: Colors.white.withValues(alpha: 0.4)),
            ),
          ],
        );
      },
    );
  }

  Widget _dot() => Padding(
    padding: EdgeInsets.symmetric(horizontal: 6.w),
    child: Text(
      '•',
      style: TextStyle(fontSize: TS.xs.sp, color: Colors.white.withValues(alpha: 0.15)),
    ),
  );

  Widget _buildProgressBar(AsyncValue<EpgProgram?> nowAsync) {
    return nowAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (prog) {
        if (prog == null || !prog.isNow) return const SizedBox.shrink();
        final remaining = prog.end.difference(DateTime.now());
        return SizedBox(
          width: 400.w,
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: TS.xs.sp, color: Colors.white.withValues(alpha: 0.25)),
                  SizedBox(width: 6.w),
                  Text(
                    '${_fmtTime(prog.start)} — ${_fmtTime(prog.end)}',
                    style: TextStyle(fontSize: TS.xs.sp, color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  const Spacer(),
                  Text(
                    'ещё ${_formatDuration(remaining)}',
                    style: TextStyle(fontSize: TS.xs.sp, color: Colors.white.withValues(alpha: 0.5)),
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
        );
      },
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
              padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 12.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, size: TS.lg.sp, color: AppColors.background),
                  SizedBox(width: 8.w),
                  Text(
                    'Смотреть',
                    style: TextStyle(fontSize: TS.sm.sp, fontWeight: FontWeight.w600, color: AppColors.background),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Mini EPG sidebar (right side in hero, "Далее на канале")
  Widget _buildMiniEpg(
    String epgLookupKey,
    AsyncValue<EpgProgram?> nowAsync,
    AsyncValue<List<EpgProgram>> upcomingAsync,
  ) {
    return Container(
      width: 220.w,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: TS.t11.sp, color: AppColors.primary),
              SizedBox(width: 6.w),
              Text(
                'Далее на канале',
                style: TextStyle(fontSize: TS.t11.sp, color: Colors.white.withValues(alpha: 0.6)),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          nowAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
            data: (prog) {
              if (prog == null) {
                return Text(
                  'Нет данных',
                  style: TextStyle(fontSize: TS.t11.sp, color: Colors.white.withValues(alpha: 0.2)),
                );
              }
              return _MiniEpgItem(program: prog, isCurrent: true);
            },
          ),
          SizedBox(height: 4.h),
          upcomingAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
            data: (programs) {
              if (programs.isEmpty) return const SizedBox.shrink();
              return _MiniEpgItem(program: programs.first, isCurrent: false);
            },
          ),
        ],
      ),
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

class _MiniEpgItem extends StatelessWidget {
  final EpgProgram program;
  final bool isCurrent;

  const _MiniEpgItem({required this.program, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3.h),
      child: Row(
        children: [
          if (isCurrent)
            Container(
              width: 3.w,
              height: 24.h,
              margin: EdgeInsets.only(right: 8.w),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2.r)),
            ),
          if (!isCurrent) SizedBox(width: 11.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.title,
                  style: TextStyle(
                    fontSize: TS.t11.sp,
                    color: isCurrent ? Colors.white.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.4),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _fmtTime(program.start),
                  style: TextStyle(fontSize: TS.t9.sp, color: Colors.white.withValues(alpha: 0.2)),
                ),
              ],
            ),
          ),
          if (isCurrent && program.isNow)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppColors.liveBadge.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                'LIVE',
                style: TextStyle(fontSize: TS.t8.sp, color: AppColors.liveBadge),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

// --- Dots extracted to hero_dots.dart ---

// --- Badges extracted to hero_badges.dart ---
