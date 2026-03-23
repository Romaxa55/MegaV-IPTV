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
  bool _thumbFailed = false;
  int _thumbRetryCount = 0;

  static const _cardBg = Color(0xFF12121E);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        scale: widget.isFocused ? 1.05 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: widget.cardWidth ?? 260.w,
          height: widget.cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: widget.isFocused
                ? Border.all(color: AppColors.primary, width: 3)
                : Border.all(color: Colors.transparent, width: 0),
            boxShadow: widget.isFocused
                ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 50, spreadRadius: -12)]
                : null,
          ),
          child: ClipRRect(borderRadius: BorderRadius.circular(16.r), child: _buildCardContent()),
        ),
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
            stops: const [0.0, 0.35, 0.55, 0.75, 1.0],
            colors: [
              Colors.transparent,
              Colors.transparent,
              const Color(0xFF08080F).withValues(alpha: 0.50),
              const Color(0xFF08080F).withValues(alpha: 0.85),
              const Color(0xFF08080F).withValues(alpha: 0.95),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    final prog = widget.item.program;
    final isExp = widget.expanded;

    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBadges(prog),
            const Spacer(),
            _buildAgeAndGenre(prog),
            SizedBox(height: 4.h),
            if (prog.isNow) ...[_buildProgressSection(prog, isExp), SizedBox(height: 6.h)],
            _buildBottomInfo(prog, isExp),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBadges(EpgProgram prog) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [if (prog.isNow) _liveBadge() else const SizedBox.shrink(), _ratingBadge()],
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFB2C36).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFB2C36).withValues(alpha: 0.20),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
          BoxShadow(color: const Color(0xFFFB2C36).withValues(alpha: 0.20), blurRadius: 6, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.77), shape: BoxShape.circle),
          ),
          SizedBox(width: 8.w),
          Text(
            'LIVE',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w400, color: Colors.white, letterSpacing: 0.35),
          ),
        ],
      ),
    );
  }

  Widget _ratingBadge() {
    final rating = _pseudoRating();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 16.sp, color: const Color(0xFF22C55E)),
          SizedBox(width: 4.w),
          Text(
            rating,
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFF22C55E)),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeAndGenre(EpgProgram prog) {
    final ageRating = _pseudoAgeRating();
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: const Color(0xFF08080F).withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.19)),
          ),
          child: Text(
            ageRating,
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFFF97316)),
          ),
        ),
        const Spacer(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(
            _genreEmoji(prog.category),
            style: TextStyle(fontSize: 16.sp, color: Colors.white.withValues(alpha: 0.50)),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection(EpgProgram prog, bool isExp) {
    return Column(
      children: [
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
                      borderRadius: BorderRadius.only(),
                      gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA78BFA)]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 4.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _fmtDuration(prog.elapsed),
              style: TextStyle(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.40)),
            ),
            Text(
              '−${_fmtDuration(prog.remaining)}',
              style: TextStyle(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.55)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomInfo(EpgProgram prog, bool isExp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prog.title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            height: 1.5,
            shadows: [const Shadow(color: Colors.black, blurRadius: 8)],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 4.h),
        Row(
          children: [
            if (prog.parsedYear != null) ...[
              Text(
                prog.parsedYear!,
                style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.50)),
              ),
              if (prog.category != null) _dot(),
            ],
            if (prog.category != null)
              Flexible(
                child: Text(
                  prog.category!,
                  style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.50)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        SizedBox(height: 4.h),
        Row(
          children: [
            _buildChannelIcon(),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                widget.item.channelName,
                style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.65)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChannelIcon() {
    final logoUrl = widget.item.logoUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4.r),
        child: Image.network(
          logoUrl,
          width: 18.w,
          height: 18.w,
          fit: BoxFit.contain,
          cacheWidth: 64,
          cacheHeight: 64,
          errorBuilder: (_, _, _) => Text('📺', style: TextStyle(fontSize: 18.sp)),
        ),
      );
    }
    return Text('📺', style: TextStyle(fontSize: 18.sp));
  }

  Widget _dot() => Padding(
    padding: EdgeInsets.symmetric(horizontal: 4.w),
    child: Text(
      '•',
      style: TextStyle(fontSize: 16.sp, color: Colors.white.withValues(alpha: 0.20)),
    ),
  );

  String _pseudoRating() {
    final hash = widget.item.program.title.hashCode.abs();
    final r = 6.0 + (hash % 40) / 10.0;
    return r.toStringAsFixed(1);
  }

  String _pseudoAgeRating() {
    final hash = widget.item.program.title.hashCode.abs();
    final ages = ['0+', '6+', '12+', '16+', '18+'];
    return ages[hash % ages.length];
  }

  String _genreEmoji(String? category) {
    if (category == null) return '🎬';
    final lower = category.toLowerCase();
    if (lower.contains('спорт') || lower.contains('футбол')) return '⚽';
    if (lower.contains('драма')) return '🎭';
    if (lower.contains('комед')) return '😂';
    if (lower.contains('ужас') || lower.contains('хоррор')) return '👻';
    if (lower.contains('боевик') || lower.contains('экшн')) return '💥';
    if (lower.contains('фантаст') || lower.contains('sci')) return '🚀';
    if (lower.contains('детектив') || lower.contains('крим')) return '🔍';
    if (lower.contains('мультфильм') || lower.contains('аним')) return '🎨';
    if (lower.contains('документ')) return '📹';
    if (lower.contains('музык')) return '🎵';
    if (lower.contains('новост')) return '📰';
    if (lower.contains('военн')) return '⚔️';
    return '🎬';
  }

  String _fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours} ч ${d.inMinutes.remainder(60)} мин';
    return '${d.inMinutes} мин';
  }

  Widget _buildPoster() {
    final iconUrl = widget.item.program.icon;
    final thumbUrl = widget.item.thumbnailUrl;
    final logoUrl = widget.item.logoUrl;

    // Priority: KP poster (icon) → stream thumbnail → channel logo
    final primaryUrl = (iconUrl != null && iconUrl.isNotEmpty) ? iconUrl : null;
    final secondaryUrl = (thumbUrl != null && thumbUrl.isNotEmpty) ? thumbUrl : null;
    final tertiaryUrl = (logoUrl != null && logoUrl.isNotEmpty) ? logoUrl : null;
    final bestUrl = primaryUrl ?? secondaryUrl ?? tertiaryUrl;

    if (bestUrl == null) return _posterPlaceholder();

    final attemptUrl = bestUrl == secondaryUrl && _thumbRetryCount > 0 ? '$bestUrl?retry=$_thumbRetryCount' : bestUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: _cardBg),
        if (!_thumbFailed)
          Image.network(
            attemptUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: 400,
            gaplessPlayback: true,
            alignment: Alignment.center,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              final ready = wasSynchronouslyLoaded || frame != null;
              return AnimatedOpacity(
                opacity: ready ? 1 : 0,
                duration: ready ? const Duration(milliseconds: 400) : Duration.zero,
                curve: Curves.easeOut,
                child: child,
              );
            },
            errorBuilder: (ctx, error, stackTrace) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_thumbFailed) {
                  setState(() => _thumbFailed = true);
                  _retryThumbnail();
                }
              });
              return const SizedBox.shrink();
            },
          ),
      ],
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
