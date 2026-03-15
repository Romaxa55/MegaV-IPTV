import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/now_playing.dart';
import '../../../core/theme/app_colors.dart';

class CinemaCard extends StatefulWidget {
  final NowPlayingItem item;
  final bool isFocused;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFocusChange;

  const CinemaCard({super.key, required this.item, this.isFocused = false, this.onTap, this.onFocusChange});

  @override
  State<CinemaCard> createState() => _CinemaCardState();
}

class _CinemaCardState extends State<CinemaCard> {
  bool _isHovered = false;
  bool _thumbFailed = false;
  int _thumbRetryCount = 0;
  int _refreshTick = 0;

  static const _cardBg = Color(0xFF12121E);

  @override
  void initState() {
    super.initState();
    _startRefreshTimer();
  }

  @override
  void didUpdateWidget(CinemaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused && !oldWidget.isFocused) {
      widget.onFocusChange?.call(true);
    }
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

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        widget.onFocusChange?.call(true);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        widget.onFocusChange?.call(false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: isHighlighted ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 220.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              border: isHighlighted ? Border.all(color: AppColors.primary, width: 2) : null,
              boxShadow: isHighlighted
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: 2)]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: Container(
                color: _cardBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [_buildPosterArea(isHighlighted), _buildInfoArea()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterArea(bool isHighlighted) {
    final prog = widget.item.program;
    return SizedBox(
      height: 200.h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildPoster(),
          _buildPosterGradient(),
          _buildLiveBadge(),
          _buildRatingBadge(),
          if (prog.isNow) _buildProgressOverlay(),
          if (isHighlighted) _buildPlayOverlay(),
        ],
      ),
    );
  }

  Widget _buildPoster() {
    final thumbUrl = widget.item.thumbnailUrl;
    final iconUrl = widget.item.program.icon;
    final logoUrl = widget.item.logoUrl;

    final useThumb = thumbUrl != null && thumbUrl.isNotEmpty && !_thumbFailed;
    final url = useThumb ? thumbUrl : (iconUrl ?? logoUrl);

    if (url == null || url.isEmpty) return _posterPlaceholder();

    final bustUrl = useThumb ? '$url?t=$_refreshTick' : url;

    return Image.network(
      bustUrl,
      key: ValueKey('$bustUrl-$_thumbRetryCount'),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: 440,
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
              cacheWidth: 440,
              alignment: Alignment.topCenter,
              errorBuilder: (ctx, _, _) => _posterPlaceholder(),
            );
          }
        }
        return _posterPlaceholder();
      },
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

  Widget _posterPlaceholder() {
    return Container(
      color: _cardBg,
      child: Center(
        child: Icon(Icons.tv, size: 40.sp, color: AppColors.textHint.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildPosterGradient() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.4, 0.85, 1.0],
            colors: [Colors.black.withValues(alpha: 0.2), Colors.transparent, _cardBg.withValues(alpha: 0.7), _cardBg],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    final prog = widget.item.program;
    return Positioned(
      top: 10.h,
      left: 10.w,
      child: prog.isNow
          ? Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppColors.liveBadge.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8.r),
                boxShadow: [BoxShadow(color: AppColors.liveBadge.withValues(alpha: 0.4), blurRadius: 10)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5.w,
                    height: 5.w,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: TS.t10.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
          : Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                _fmtTime(prog.start),
                style: TextStyle(fontSize: TS.t10.sp, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ),
    );
  }

  Widget _buildRatingBadge() {
    return Positioned(
      top: 10.h,
      right: 10.w,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: TS.t11.sp, color: AppColors.ratingGold),
            SizedBox(width: 3.w),
            Text(
              _pseudoRating(),
              style: TextStyle(
                fontSize: TS.t10.sp,
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressOverlay() {
    final prog = widget.item.program;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3.r),
          child: LinearProgressIndicator(
            value: prog.progress,
            minHeight: 4.h,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)],
            ),
            child: Icon(Icons.play_arrow_rounded, size: TS.t2xl.sp, color: AppColors.background),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoArea() {
    final prog = widget.item.program;
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  prog.title,
                  style: TextStyle(fontSize: TS.sm.sp, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (prog.isNow) ...[
                SizedBox(width: 6.w),
                Text(
                  '~${_fmtDuration(prog.remaining)}',
                  style: TextStyle(fontSize: TS.t9.sp, color: Colors.white.withValues(alpha: 0.35)),
                ),
              ],
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              if (prog.category != null) ...[
                Flexible(
                  child: Text(
                    prog.category!,
                    style: TextStyle(fontSize: TS.t10.sp, color: Colors.white.withValues(alpha: 0.4)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _dot(),
              ],
              Text(
                _fmtDuration(prog.duration),
                style: TextStyle(fontSize: TS.t10.sp, color: Colors.white.withValues(alpha: 0.35)),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Icon(Icons.tv_rounded, size: TS.t10.sp, color: Colors.white.withValues(alpha: 0.2)),
              SizedBox(width: 5.w),
              Expanded(
                child: Text(
                  widget.item.channelName,
                  style: TextStyle(fontSize: TS.t10.sp, color: Colors.white.withValues(alpha: 0.25)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot() => Padding(
    padding: EdgeInsets.symmetric(horizontal: 5.w),
    child: Text(
      '·',
      style: TextStyle(fontSize: TS.t10.sp, color: Colors.white.withValues(alpha: 0.15)),
    ),
  );

  String _pseudoRating() {
    final hash = widget.item.program.title.hashCode.abs();
    final r = 6.0 + (hash % 40) / 10.0;
    return r.toStringAsFixed(1);
  }

  String _fmtTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  String _fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours} ч ${d.inMinutes.remainder(60)} мин';
    return '${d.inMinutes} мин';
  }
}
