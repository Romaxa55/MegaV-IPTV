import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/epg_program.dart';
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
  bool _isHovered = false;
  bool _thumbFailed = false;
  int _thumbRetryCount = 0;

  static const _cardBg = Color(0xFF12121E);

  @override
  void didUpdateWidget(CinemaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused && !oldWidget.isFocused) {
      widget.onFocusChange?.call(true);
    }
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: widget.cardWidth ?? 260.w,
          height: widget.cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: isHighlighted
                ? Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2)
                : Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
            boxShadow: isHighlighted
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 30, spreadRadius: 4)]
                : null,
          ),
          child: ClipRRect(borderRadius: BorderRadius.circular(12.r), child: _buildCardContent()),
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    final pW = widget.posterWidth ?? widget.cardWidth ?? 260.w;
    final cW = widget.cardWidth ?? 260.w;
    final isCropped = pW > cW + 1;

    if (!isCropped) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildPoster(),
          _buildGradient(),
          if (widget.expanded) _buildExpandedOverlay() else _buildNarrowOverlay(),
        ],
      );
    }

    final shift = (pW - cW) / 2;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(left: -shift, top: 0, bottom: 0, width: pW, child: _buildPoster()),
        _buildGradient(),
        _buildNarrowOverlay(),
      ],
    );
  }

  Widget _buildGradient() {
    if (widget.expanded) {
      return Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.35, 0.75, 1.0],
              colors: [
                Colors.black.withValues(alpha: 0.1),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.65),
                Colors.black.withValues(alpha: 0.92),
              ],
            ),
          ),
        ),
      );
    }
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.55, 1.0],
            colors: [Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.75)],
          ),
        ),
      ),
    );
  }

  // --- NARROW: just title at bottom ---
  Widget _buildNarrowOverlay() {
    return Positioned(
      bottom: 8.h,
      left: 8.w,
      right: 8.w,
      child: Text(
        widget.item.program.title,
        style: TextStyle(
          fontSize: TS.t10.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.9),
          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // --- EXPANDED: Netflix-style overlay at bottom ---
  Widget _buildExpandedOverlay() {
    final prog = widget.item.program;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              prog.title,
              style: TextStyle(
                fontSize: TS.lg.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.2,
                shadows: [Shadow(color: Colors.black, blurRadius: 10)],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 4.h,
              children: [
                if (prog.isNow) _badge('LIVE', AppColors.liveBadge),
                _badge(_pseudoRating(), const Color(0xFF1DB954), icon: Icons.star_rounded),
                _badge(widget.item.channelName, Colors.white.withValues(alpha: 0.15)),
              ],
            ),
            SizedBox(height: 8.h),
            _buildMeta(prog),
            if (prog.description != null && prog.description!.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Text(
                prog.description!,
                style: TextStyle(fontSize: TS.t10.sp, color: Colors.white.withValues(alpha: 0.5), height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (prog.isNow) ...[
              SizedBox(height: 8.h),
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
          ],
        ),
      ),
    );
  }

  Widget _buildMeta(EpgProgram prog) {
    return Row(
      children: [
        _buildChannelLogo(),
        SizedBox(width: 5.w),
        if (prog.category != null) ...[
          Text(
            prog.category!,
            style: TextStyle(fontSize: TS.t10.sp, color: Colors.white.withValues(alpha: 0.45)),
          ),
          _dot(),
        ],
        Text(
          '${_fmtTime(prog.start)} — ${_fmtTime(prog.end)}',
          style: TextStyle(fontSize: TS.t10.sp, color: Colors.white.withValues(alpha: 0.35)),
        ),
        if (prog.isNow) ...[
          _dot(),
          Text(
            'ещё ${_fmtDuration(prog.remaining)}',
            style: TextStyle(fontSize: TS.t10.sp, color: AppColors.primary),
          ),
        ],
      ],
    );
  }

  Widget _badge(String text, Color bg, {IconData? icon}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: TS.t10.sp, color: Colors.white), SizedBox(width: 3.w)],
          Text(
            text,
            style: TextStyle(fontSize: TS.t9.sp, fontWeight: FontWeight.w600, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
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

  Widget _buildChannelLogo() {
    final logoUrl = widget.item.logoUrl;
    final size = 16.w;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4.r),
        child: Image.network(
          logoUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              Icon(Icons.tv_rounded, size: TS.t11.sp, color: Colors.white.withValues(alpha: 0.2)),
        ),
      );
    }
    return Icon(Icons.tv_rounded, size: TS.t11.sp, color: Colors.white.withValues(alpha: 0.2));
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
    if (d.inHours > 0) return '${d.inHours}ч ${d.inMinutes.remainder(60)}м';
    return '${d.inMinutes} мин';
  }
}
