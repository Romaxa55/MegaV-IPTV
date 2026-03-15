import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/now_playing.dart';
import '../../../core/theme/app_colors.dart';

class CinemaCard extends StatefulWidget {
  final NowPlayingItem item;
  final bool isFocused;
  final bool expanded;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFocusChange;
  final double? cardWidth;
  final double? posterWidth;
  final double? cardHeight;

  const CinemaCard({
    super.key,
    required this.item,
    this.isFocused = false,
    this.expanded = false,
    this.onTap,
    this.onFocusChange,
    this.cardWidth,
    this.posterWidth,
    this.cardHeight,
  });

  @override
  State<CinemaCard> createState() => _CinemaCardState();
}

class _CinemaCardState extends State<CinemaCard> {
  bool _thumbFailed = false;
  int _thumbRetryCount = 0;

  static const _cardBg = Color(0xFF12121E);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: widget.cardWidth ?? 260.w,
        height: widget.cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: widget.isFocused
              ? Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2)
              : Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
          boxShadow: widget.isFocused
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 30, spreadRadius: 4)]
              : null,
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(12.r), child: _buildCardContent()),
      ),
    );
  }

  Widget _buildCardContent() {
    return Stack(fit: StackFit.expand, children: [_buildPoster(), _buildGradient(), _buildOverlay()]);
  }

  Widget _buildGradient() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.45, 1.0],
            colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent, Colors.black.withValues(alpha: 0.9)],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    final prog = widget.item.program;
    final isExp = widget.expanded;
    final padH = isExp ? 14.w : 10.w;
    final titleSize = isExp ? TS.sm.sp : TS.xs.sp;
    final metaSize = isExp ? TS.t11.sp : TS.t9.sp;

    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.fromLTRB(padH, 10.h, padH, 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (prog.isNow) _badge('LIVE', AppColors.liveBadge, size: metaSize),
                if (!prog.isNow) const Spacer(),
                _badge(_pseudoRating(), const Color(0xFF1DB954), icon: Icons.star_rounded, size: metaSize),
              ],
            ),
            const Spacer(),
            Text(
              prog.title,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.2,
                shadows: [Shadow(color: Colors.black, blurRadius: 10)],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                if (prog.category != null) ...[
                  Text(
                    prog.category!,
                    style: TextStyle(fontSize: metaSize, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Text(
                      '·',
                      style: TextStyle(fontSize: metaSize, color: Colors.white.withValues(alpha: 0.3)),
                    ),
                  ),
                ],
                Text(
                  _fmtTime(prog.start),
                  style: TextStyle(fontSize: metaSize, color: Colors.white.withValues(alpha: 0.5)),
                ),
                if (prog.isNow && isExp) ...[
                  const Spacer(),
                  Text(
                    '-${_fmtDuration(prog.remaining)}',
                    style: TextStyle(fontSize: metaSize, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ],
              ],
            ),
            if (prog.isNow) ...[
              SizedBox(height: 8.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(2.r),
                child: LinearProgressIndicator(
                  value: prog.progress,
                  minHeight: isExp ? 4.h : 3.h,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
            SizedBox(height: 8.h),
            Row(
              children: [
                _buildChannelLogo(isExp ? 18.w : 14.w),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    widget.item.channelName,
                    style: TextStyle(fontSize: metaSize, color: Colors.white.withValues(alpha: 0.6)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg, {IconData? icon, required double size}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: size, color: Colors.white), SizedBox(width: 2.w)],
          Text(
            text,
            style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildChannelLogo(double size) {
    final logoUrl = widget.item.logoUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4.r),
        child: Image.network(
          logoUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Icon(Icons.tv_rounded, size: size, color: Colors.white.withValues(alpha: 0.2)),
        ),
      );
    }
    return Icon(Icons.tv_rounded, size: size, color: Colors.white.withValues(alpha: 0.2));
  }

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
    if (d.inHours > 0) return '${d.inHours}ч ${d.inMinutes.remainder(60)}м';
    return '${d.inMinutes} мин';
  }

  // --- SHARED ---
  Widget _buildPoster() {
    final thumbUrl = widget.item.thumbnailUrl;
    final iconUrl = widget.item.program.icon;
    final logoUrl = widget.item.logoUrl;

    final useThumb = thumbUrl != null && !_thumbFailed;
    final url = useThumb ? thumbUrl : (iconUrl ?? logoUrl);

    if (url == null || url.isEmpty) return _posterPlaceholder();

    return Image.network(
      url,
      key: ValueKey('$url-$_thumbRetryCount'),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: widget.expanded ? 600 : 300,
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
              cacheWidth: widget.expanded ? 600 : 300,
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
    if (_thumbRetryCount >= 6) return;
    final delays = [3, 5, 10, 15, 30, 60];
    final delaySec = delays[_thumbRetryCount.clamp(0, delays.length - 1)];
    Future.delayed(Duration(seconds: delaySec), () {
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
        child: Icon(Icons.tv, size: 32.sp, color: AppColors.textHint.withValues(alpha: 0.2)),
      ),
    );
  }
}
