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
  final double? cardHeight;

  const CinemaCard({
    super.key,
    required this.item,
    this.isFocused = false,
    this.expanded = false,
    this.onTap,
    this.onFocusChange,
    this.cardWidth,
    this.cardHeight,
  });

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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: widget.cardWidth ?? 260.w,
          height: widget.cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: isHighlighted
                ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2)
                : Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
            boxShadow: isHighlighted
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 4)]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: widget.expanded ? _buildExpandedCard() : _buildNarrowCard(),
          ),
        ),
      ),
    );
  }

  // --- NARROW CARD: poster only, no text ---
  Widget _buildNarrowCard() {
    return Stack(fit: StackFit.expand, children: [_buildPoster(), _buildNarrowGradient(), _buildNarrowTitle()]);
  }

  Widget _buildNarrowGradient() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.5, 1.0],
            colors: [Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.7)],
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowTitle() {
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
          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 6)],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // --- EXPANDED CARD: Netflix-style with badges and info ---
  Widget _buildExpandedCard() {
    final prog = widget.item.program;
    return Container(
      color: _cardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildExpandedPoster()),
          _buildExpandedInfo(prog),
        ],
      ),
    );
  }

  Widget _buildExpandedPoster() {
    final prog = widget.item.program;
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildPoster(),
        _buildExpandedGradient(),
        _buildExpandedBadges(),
        if (prog.isNow) _buildProgressOverlay(),
      ],
    );
  }

  Widget _buildExpandedGradient() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.3, 0.85, 1.0],
            colors: [Colors.black.withValues(alpha: 0.15), Colors.transparent, _cardBg.withValues(alpha: 0.6), _cardBg],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedBadges() {
    final prog = widget.item.program;
    return Positioned(
      bottom: 10.h,
      left: 12.w,
      right: 12.w,
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
              shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 8)],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              if (prog.isNow) _badge('LIVE', AppColors.liveBadge),
              if (prog.isNow) SizedBox(width: 6.w),
              _badge(_pseudoRating(), const Color(0xFF1DB954), icon: Icons.star_rounded),
              SizedBox(width: 6.w),
              _badge(widget.item.channelName, Colors.white.withValues(alpha: 0.15)),
            ],
          ),
        ],
      ),
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
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: TS.t9.sp, fontWeight: FontWeight.w600, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedInfo(EpgProgram prog) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (prog.category != null) ...[
                Text(
                  prog.category!,
                  style: TextStyle(fontSize: TS.t10.sp, color: Colors.white.withValues(alpha: 0.5)),
                ),
                _dot(),
              ],
              Text(
                _fmtDuration(prog.duration),
                style: TextStyle(fontSize: TS.t10.sp, color: Colors.white.withValues(alpha: 0.4)),
              ),
              if (prog.isNow) ...[
                _dot(),
                Text(
                  'ещё ${_fmtDuration(prog.remaining)}',
                  style: TextStyle(fontSize: TS.t10.sp, color: AppColors.primary),
                ),
              ],
            ],
          ),
          if (prog.description != null && prog.description!.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              prog.description!,
              style: TextStyle(fontSize: TS.t10.sp, color: Colors.white.withValues(alpha: 0.35), height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: 6.h),
          Row(
            children: [
              _buildChannelLogo(),
              SizedBox(width: 5.w),
              Expanded(
                child: Text(
                  widget.item.channelName,
                  style: TextStyle(fontSize: TS.t10.sp, color: Colors.white.withValues(alpha: 0.35)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${_fmtTime(prog.start)} — ${_fmtTime(prog.end)}',
                style: TextStyle(fontSize: TS.t9.sp, color: Colors.white.withValues(alpha: 0.25)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressOverlay() {
    final prog = widget.item.program;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: LinearProgressIndicator(
          value: prog.progress,
          minHeight: 3.h,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }

  // --- SHARED ---
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
    if (d.inHours > 0) return '${d.inHours} ч ${d.inMinutes.remainder(60)} мин';
    return '${d.inMinutes} мин';
  }
}
