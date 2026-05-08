import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/epg_program.dart';
import '../../../core/playlist/models/now_playing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui_performance.dart';
import '../../../core/ui/utils/fast_scroll_detector.dart';
import '_grid_tokens.dart';

/// Плитка ряда главной сетки.
///
/// Контракт (см. spec home-grid-optimization, design.md → CinemaCard):
///   * `cardWidth`/`cardHeight` обязательны и фиксированы — ширина не анимируется
///     при смене фокуса (Req 1.4, 1.5, 3.1, 3.2, 3.6).
///   * Compact overlay (логотип+название канала+LIVE) рендерится всегда (Req 5).
///   * Full overlay (рейтинг, возраст, жанр, название программы, год, прогресс)
///     раскрывается через `AnimatedOpacity` при `isFocused == true` (Req 6).
///   * Тяжёлый `boxShadow.blurRadius=50` удалён в пользу яркой рамки (Req 3.5, 9.4).
///   * Псевдо-данные кэшируются один раз через `late final` поля (Req 9.4).
///   * При fast-scroll анимации схлопываются до `Duration.zero` (Req 4.4).
class CinemaCard extends StatefulWidget {
  final NowPlayingItem item;
  final bool isFocused;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFocusChange;
  final double cardWidth;
  final double cardHeight;

  const CinemaCard({
    super.key,
    required this.item,
    required this.cardWidth,
    required this.cardHeight,
    this.isFocused = false,
    this.onTap,
    this.onFocusChange,
  });

  @override
  State<CinemaCard> createState() => _CinemaCardState();
}

class _CinemaCardState extends State<CinemaCard> {
  bool _thumbFailed = false;
  int _thumbRetryCount = 0;

  // Кэш псевдо-данных. Считаются один раз на инстанс карточки (task 2.1, Req 9.4).
  // Используем initializer-form `late final = ...` — методы гарантированно
  // дёргаются ровно один раз на первый доступ из build.
  late final String _ratingCached = _computeRating();
  late final String _ageRatingCached = _computeAgeRating();
  late final String _genreEmojiCached = _computeGenreEmoji();

  static const _cardBg = Color(0xFF12121E);

  @override
  Widget build(BuildContext context) {
    final isFastScroll = context.isFastScrolling;
    final scaleDuration = isFastScroll ? Duration.zero : GridTokens.focusAnimation;
    final containerDuration = isFastScroll ? Duration.zero : GridTokens.focusAnimation;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: scaleDuration,
        curve: GridTokens.focusCurve,
        alignment: Alignment.bottomCenter,
        scale: widget.isFocused ? GridTokens.focusedScale : 1.0,
        child: AnimatedContainer(
          duration: containerDuration,
          curve: GridTokens.focusCurve,
          width: widget.cardWidth,
          height: widget.cardHeight,
          decoration: _decorationFor(widget.isFocused),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: _buildCardContent(context, isFastScroll: isFastScroll),
          ),
        ),
      ),
    );
  }

  /// Декорация плитки. Один дешёвый стиль для всех устройств: яркая рамка
  /// + лёгкая тень (blurRadius ≤ 12) при фокусе. Тяжёлый blur=50 удалён
  /// (task 2.2, Req 3.5, 9.1, 9.4).
  BoxDecoration _decorationFor(bool isFocused) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(color: isFocused ? AppColors.primary : Colors.transparent, width: GridTokens.focusBorderWidth),
      boxShadow: isFocused
          ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 12, spreadRadius: 0)]
          : null,
    );
  }

  Widget _buildCardContent(BuildContext context, {required bool isFastScroll}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildPoster(),
        _buildGradient(context),
        _buildCompactOverlay(context),
        _buildFullOverlayWithFade(isFastScroll: isFastScroll),
      ],
    );
  }

  Widget _buildGradient(BuildContext context) {
    final isLowPower = effectiveLowPowerUi(context);

    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: isLowPower ? const [0.0, 0.75, 1.0] : const [0.0, 0.35, 0.55, 0.75, 1.0],
            colors: isLowPower
                ? [
                    Colors.transparent,
                    const Color(0xFF08080F).withValues(alpha: 0.85),
                    const Color(0xFF08080F).withValues(alpha: 0.95),
                  ]
                : [
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

  // --- Overlays ------------------------------------------------------------

  /// Compact overlay: рендерится **всегда** (Req 5.1–5.5).
  ///
  /// Содержит:
  ///   * LIVE-индикатор в верхнем-левом углу, если `program.isNow == true`.
  ///   * Нижнюю строку с логотипом канала и названием канала.
  ///
  /// Поднятая в постер часть (LIVE-бейдж) и нижняя строка вместе занимают
  /// существенно меньше четверти высоты плитки, поэтому постер остаётся
  /// доминантой (Req 5.5).
  ///
  /// Имя канала живёт **только** здесь — full overlay его не дублирует,
  /// благодаря чему смена focused/unfocused не вызывает reflow (Req 6.4).
  Widget _buildCompactOverlay(BuildContext context) {
    final prog = widget.item.program;
    final showLive = prog?.isNow == true;

    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [if (showLive) _liveBadge(context), const Spacer(), _buildBottomChannelLine()],
        ),
      ),
    );
  }

  Widget _buildBottomChannelLine() {
    return Row(
      children: [
        _buildChannelIcon(),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            widget.item.channelName,
            key: const Key('channel-name'),
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white.withValues(alpha: 0.85),
              shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Full overlay в обёртке `AnimatedOpacity` (Req 6.1–6.3).
  ///
  /// При fast-scroll fade-out схлопывается до `Duration.zero`, чтобы
  /// неактивные плитки не «тянули» затухающий overlay за фокусом
  /// (task 2.5, опциональный путь).
  Widget _buildFullOverlayWithFade({required bool isFastScroll}) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: widget.isFocused ? 1.0 : 0.0,
          duration: isFastScroll ? Duration.zero : GridTokens.overlayFade,
          curve: GridTokens.overlayCurve,
          child: _buildFullOverlay(),
        ),
      ),
    );
  }

  /// Full overlay: только то, что НЕ в compact (Req 6.1).
  ///
  /// Содержит: рейтинг (top-right), возраст+жанр, прогресс (если live),
  /// название программы, год, категорию. **Не** содержит имя канала и LIVE —
  /// они уже в compact (Req 6.4).
  Widget _buildFullOverlay() {
    final prog = widget.item.program;

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [_ratingBadge()]),
          const Spacer(),
          if (prog != null) _buildAgeAndGenre(prog),
          SizedBox(height: 4.h),
          if (prog?.isNow == true) ...[_buildProgressSection(prog!), SizedBox(height: 6.h)],
          _buildProgrammeInfo(prog),
          // Резерв высоты под compact channel-line, чтобы full overlay не залезал
          // на имя канала. Compact-line ≈ 18.w иконка + 14.sp текст ≈ 22.h.
          SizedBox(height: 22.h + 4.h),
        ],
      ),
    );
  }

  // --- Helpers (preserved) -------------------------------------------------

  Widget _liveBadge(BuildContext context) {
    final isLowPower = effectiveLowPowerUi(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFB2C36).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: isLowPower
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFFFB2C36).withValues(alpha: 0.20),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: const Color(0xFFFB2C36).withValues(alpha: 0.20),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
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
    return Container(
      key: const Key('rating-badge'),
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
            _ratingCached,
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFF22C55E)),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeAndGenre(EpgProgram prog) {
    return Row(
      children: [
        Container(
          key: const Key('age-rating'),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: const Color(0xFF08080F).withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.19)),
          ),
          child: Text(
            _ageRatingCached,
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFFF97316)),
          ),
        ),
        const Spacer(),
        Container(
          key: const Key('genre-emoji'),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(
            _genreEmojiCached,
            style: TextStyle(fontSize: 16.sp, color: Colors.white.withValues(alpha: 0.50)),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection(EpgProgram prog) {
    return Column(
      key: const Key('progress-section'),
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

  /// Часть `_buildBottomInfo` без channel-line (она в compact'е).
  Widget _buildProgrammeInfo(EpgProgram? prog) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prog?.title ?? 'Нет данных EPG',
          key: const Key('programme-title'),
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
            if (prog?.parsedYear != null) ...[
              Text(
                prog!.parsedYear!,
                style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.50)),
              ),
              if (prog.category != null) _dot(),
            ],
            if (prog?.category != null)
              Flexible(
                child: Text(
                  prog!.category!,
                  style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.50)),
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

  // --- Pseudo-data computation (cached via late final) ---------------------

  String _computeRating() {
    final title = widget.item.program?.title ?? widget.item.channelName;
    final hash = title.hashCode.abs();
    final r = 6.0 + (hash % 40) / 10.0;
    return r.toStringAsFixed(1);
  }

  String _computeAgeRating() {
    final title = widget.item.program?.title ?? widget.item.channelName;
    final hash = title.hashCode.abs();
    const ages = ['0+', '6+', '12+', '16+', '18+'];
    return ages[hash % ages.length];
  }

  String _computeGenreEmoji() {
    final category = widget.item.program?.category;
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

  // --- Poster + retry logic (preserved) -----------------------------------

  Widget _buildPoster() {
    final iconUrl = widget.item.program?.icon;
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
