import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/now_playing.dart';
import '../../../core/theme/app_colors.dart';

class CinemaCard extends StatefulWidget {
  final NowPlayingItem item;
  final bool isFocused;
  final VoidCallback? onTap;

  const CinemaCard({super.key, required this.item, this.isFocused = false, this.onTap});

  @override
  State<CinemaCard> createState() => _CinemaCardState();
}

class _CinemaCardState extends State<CinemaCard> {
  bool _isHovered = false;
  bool _thumbFailed = false;
  int _thumbRetryCount = 0;
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() => _refreshTick++);
        _startRefreshTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isFocused || _isHovered;
    final prog = widget.item.program;

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
            width: 180.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              border: isHighlighted ? Border.all(color: AppColors.primary, width: 2) : null,
              boxShadow: isHighlighted
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2)]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: Container(
                color: const Color(0xFF12121E),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(top: 0, left: 0, right: 0, height: 140.h, child: _buildPoster()),
                    _buildGradientOverlay(),
                    _buildStatusBadge(),
                    _buildBottomInfo(),
                    if (prog.isNow) _buildProgressBar(),
                    if (isHighlighted) _buildPlayOverlay(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _retryThumbnail() {
    if (_thumbRetryCount >= 3) return;
    Future.delayed(Duration(seconds: 5 * (_thumbRetryCount + 1)), () {
      if (mounted) {
        setState(() {
          _thumbFailed = false;
          _thumbRetryCount++;
        });
      }
    });
  }

  Widget _buildPoster() {
    final thumbUrl = widget.item.thumbnailUrl;
    final iconUrl = widget.item.program.icon;
    final logoUrl = widget.item.logoUrl;

    final useThumb = thumbUrl != null && thumbUrl.isNotEmpty && !_thumbFailed;
    final url = useThumb ? thumbUrl : (iconUrl ?? logoUrl);

    if (url == null || url.isEmpty) {
      return _posterPlaceholder();
    }

    final bustUrl = useThumb ? '$url?t=$_refreshTick' : url;

    return Image.network(
      bustUrl,
      key: ValueKey('$bustUrl-$_thumbRetryCount'),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: 360,
      alignment: Alignment.topCenter,
      frameBuilder: (ctx, child, frame, loaded) {
        if (loaded) return child;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: frame != null ? child : _posterPlaceholder(),
        );
      },
      errorBuilder: (ctx, _, _) {
        if (useThumb) {
          _thumbFailed = true;
          _retryThumbnail();
          final fallback = iconUrl ?? logoUrl;
          if (fallback != null && fallback.isNotEmpty) {
            return Image.network(
              fallback,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: 360,
              alignment: Alignment.topCenter,
              errorBuilder: (ctx, _, _) => _posterPlaceholder(),
            );
          }
        }
        return _posterPlaceholder();
      },
    );
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
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 140.h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.5, 0.85, 1.0],
            colors: [
              Colors.black.withValues(alpha: 0.15),
              Colors.transparent,
              const Color(0xFF12121E).withValues(alpha: 0.6),
              const Color(0xFF12121E),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final prog = widget.item.program;
    return Positioned(
      top: 8.h,
      left: 8.w,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prog.isNow)
            Container(
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
            )
          else
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                _fmtTime(prog.start),
                style: TextStyle(fontSize: TS.t10.sp, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final prog = widget.item.program;
    return Positioned(
      bottom: 56.h,
      left: 8.w,
      right: 8.w,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2.r),
            child: LinearProgressIndicator(
              value: prog.progress,
              minHeight: 3.h,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmtDuration(prog.elapsed),
                style: TextStyle(fontSize: TS.t7.sp, color: Colors.white.withValues(alpha: 0.25)),
              ),
              Text(
                '-${_fmtDuration(prog.remaining)}',
                style: TextStyle(fontSize: TS.t7.sp, color: Colors.white.withValues(alpha: 0.4)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfo() {
    final prog = widget.item.program;
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
              prog.title,
              style: TextStyle(
                fontSize: TS.xs.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
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
            SizedBox(height: 1.h),
            Text(
              widget.item.channelName,
              style: TextStyle(fontSize: TS.t9.sp, color: Colors.white.withValues(alpha: 0.15)),
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

  String _fmtTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  String _fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}ч ${d.inMinutes.remainder(60)}м';
    return '${d.inMinutes} мин';
  }
}
