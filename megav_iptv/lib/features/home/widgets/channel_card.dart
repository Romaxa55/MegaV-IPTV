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
            width: 280.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              border: isHighlighted ? Border.all(color: AppColors.primary, width: 2) : null,
              boxShadow: isHighlighted
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2)]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPoster(),
                  _buildGradientOverlay(),
                  _buildStatusBadges(tvgId),
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
        child: Icon(Icons.tv, size: 40.sp, color: AppColors.textHint.withValues(alpha: 0.3)),
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
            colors: [Colors.transparent, Colors.transparent, AppColors.background.withValues(alpha: 0.9)],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadges(String? tvgId) {
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
                  boxShadow: [BoxShadow(color: AppColors.liveBadge.withValues(alpha: 0.2), blurRadius: 8)],
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
                      style: TextStyle(fontSize: 10.sp, color: Colors.white, fontWeight: FontWeight.bold),
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
            Text(
              widget.channel.name,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (tvgId != null && tvgId.isNotEmpty)
              Consumer(
                builder: (context, ref, _) {
                  final nowAsync = ref.watch(currentProgramProvider(tvgId));
                  return nowAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, st) => const SizedBox.shrink(),
                    data: (prog) {
                      if (prog == null) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 2.h),
                          Text(
                            prog.title,
                            style: TextStyle(fontSize: 10.sp, color: Colors.white.withValues(alpha: 0.5)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (prog.isNow) ...[
                            SizedBox(height: 4.h),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2.r),
                              child: LinearProgressIndicator(
                                value: prog.progress,
                                minHeight: 2.h,
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            SizedBox(height: 2.h),
            Text(
              widget.channel.groupTitle ?? '',
              style: TextStyle(fontSize: 9.sp, color: Colors.white.withValues(alpha: 0.15)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayOverlay() {
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          color: Colors.black.withValues(alpha: 0.2),
          child: Center(
            child: Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)],
              ),
              child: Icon(Icons.play_arrow, size: 24.sp, color: AppColors.background),
            ),
          ),
        ),
      ),
    );
  }
}
