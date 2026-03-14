import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';

class CinemaCard extends ConsumerStatefulWidget {
  final Channel channel;
  final bool isFocused;
  final VoidCallback? onTap;

  const CinemaCard({super.key, required this.channel, this.isFocused = false, this.onTap});

  @override
  ConsumerState<CinemaCard> createState() => _CinemaCardState();
}

class _CinemaCardState extends ConsumerState<CinemaCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isFocused || _isHovered;
    final tvgId = widget.channel.tvgId;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: isHighlighted ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 220.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: isHighlighted ? Border.all(color: AppColors.primary, width: 2) : null,
              boxShadow: isHighlighted
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2)]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14.r),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPoster(),
                  _buildGradientOverlay(),
                  _buildLiveBadge(tvgId),
                  _buildRatingBadge(),
                  _buildBottomInfo(tvgId),
                  if (isHighlighted) _buildPlayOverlay(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoster() {
    if (widget.channel.logoUrl != null && widget.channel.logoUrl!.isNotEmpty) {
      return Image.network(
        widget.channel.logoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, st) => _posterPlaceholder(),
      );
    }
    return _posterPlaceholder();
  }

  Widget _posterPlaceholder() {
    return Container(
      color: const Color(0xFF12121E),
      child: Center(
        child: Icon(Icons.tv, size: 36.sp, color: AppColors.textHint.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.3, 0.65, 1.0],
            colors: [
              Colors.transparent,
              AppColors.background.withValues(alpha: 0.5),
              AppColors.background.withValues(alpha: 0.95),
            ],
          ),
        ),
      ),
    );
  }

  // LIVE badge (top-left)
  Widget _buildLiveBadge(String? tvgId) {
    if (tvgId == null || tvgId.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: 8.h,
      left: 8.w,
      child: Consumer(
        builder: (context, ref, _) {
          final nowAsync = ref.watch(currentProgramProvider(tvgId));
          return nowAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
            data: (prog) {
              if (prog == null || !prog.isNow) return const SizedBox.shrink();
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.liveBadge.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: [BoxShadow(color: AppColors.liveBadge.withValues(alpha: 0.3), blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4.w,
                      height: 4.w,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'LIVE',
                      style: TextStyle(fontSize: TS.t10.sp, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Rating badge (top-right)
  Widget _buildRatingBadge() {
    return Positioned(
      top: 8.h,
      right: 8.w,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: TS.t10.sp, color: AppColors.ratingGold),
            SizedBox(width: 2.w),
            Text(
              '${(widget.channel.name.hashCode % 30 + 50) / 10.0}',
              style: TextStyle(fontSize: TS.t10.sp, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInfo(String? tvgId) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.all(10.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // EPG program progress bar
            if (tvgId != null && tvgId.isNotEmpty)
              Consumer(
                builder: (context, ref, _) {
                  final nowAsync = ref.watch(currentProgramProvider(tvgId));
                  return nowAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, st) => const SizedBox.shrink(),
                    data: (prog) {
                      if (prog == null || !prog.isNow) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.only(bottom: 6.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _fmtDuration(prog.end.difference(DateTime.now())),
                                  style: TextStyle(fontSize: TS.t7.sp, color: Colors.white.withValues(alpha: 0.25)),
                                ),
                                const Spacer(),
                                Text(
                                  '-${_fmtDuration(prog.end.difference(DateTime.now()))}',
                                  style: TextStyle(fontSize: TS.t7.sp, color: Colors.white.withValues(alpha: 0.4)),
                                ),
                              ],
                            ),
                            SizedBox(height: 2.h),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2.r),
                              child: LinearProgressIndicator(
                                value: prog.progress,
                                minHeight: 3.h,
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            // Channel/program title
            Text(
              widget.channel.name,
              style: TextStyle(
                fontSize: TS.xs.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Meta row
            SizedBox(height: 2.h),
            if (tvgId != null && tvgId.isNotEmpty)
              Consumer(
                builder: (context, ref, _) {
                  final nowAsync = ref.watch(currentProgramProvider(tvgId));
                  return nowAsync.when(
                    loading: () => _metaFallback(),
                    error: (e, st) => _metaFallback(),
                    data: (prog) {
                      if (prog == null) return _metaFallback();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (prog.category != null) ...[
                                Text(
                                  prog.category!,
                                  style: TextStyle(fontSize: TS.t9.sp, color: Colors.white.withValues(alpha: 0.3)),
                                ),
                                Text(
                                  ' · ',
                                  style: TextStyle(fontSize: TS.t9.sp, color: Colors.white.withValues(alpha: 0.15)),
                                ),
                              ],
                              Text(
                                _fmtDuration(prog.duration),
                                style: TextStyle(fontSize: TS.t9.sp, color: Colors.white.withValues(alpha: 0.3)),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              )
            else
              _metaFallback(),
            SizedBox(height: 1.h),
            Text(
              widget.channel.groupTitle ?? '',
              style: TextStyle(fontSize: TS.t9.sp, color: Colors.white.withValues(alpha: 0.15)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaFallback() {
    return Text(
      widget.channel.groupTitle ?? '',
      style: TextStyle(fontSize: TS.t9.sp, color: Colors.white.withValues(alpha: 0.3)),
      maxLines: 1,
    );
  }

  Widget _buildPlayOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.2),
        child: Center(
          child: Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)],
            ),
            child: Icon(Icons.play_arrow, size: TS.xl.sp, color: AppColors.background),
          ),
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours} ч ${d.inMinutes.remainder(60)} мин';
    return '${d.inMinutes} мин';
  }
}
