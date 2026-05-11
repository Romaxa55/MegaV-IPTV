import 'package:flutter/material.dart' hide Chip;

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/playlist/models/now_playing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Full cinematic hero content block — renders inside the full-bleed backdrop
/// Stack on top of [SafeBackdrop] + gradient layers.
///
/// Padding mirrors JSX design: `20px 56px 40px` (top / horizontal / bottom).
/// All layout decisions come from home-cinematic.jsx.
///
/// Kept in a separate file so [cinematic_home_screen.dart] stays under 600
/// lines (pre-commit hook limit).
class CinematicHeroContent extends StatelessWidget {
  const CinematicHeroContent({
    super.key,
    required this.item,
    required this.watchFocusNode,
    required this.onWatch,
    required this.onEpg,
    required this.onFavourite,
  });

  final NowPlayingItem item;
  final FocusNode watchFocusNode;
  final VoidCallback onWatch;
  final VoidCallback onEpg;
  final VoidCallback onFavourite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final palette = AppColors.activePalette;

    // Title: 110px italic display, lineHeight 0.95, letterSpacing -0.02em.
    // MegaVTextStyles.displayItalic is 96px; override size to match JSX spec.
    final titleBase =
        styles?.displayItalic ?? const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w600);
    final titleStyle = titleBase.copyWith(
      fontSize: 110,
      height: 0.95,
      letterSpacing: 110 * -0.02,
      color: palette.text,
      shadows: [
        Shadow(blurRadius: kSafeShadowBlurMax, color: Colors.black.withValues(alpha: 0.55), offset: const Offset(0, 2)),
      ],
    );

    // Meta row: monospace 12px, uppercase, letterSpacing 0.12em.
    final metaBase = styles?.metaMono ?? const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w500);
    final metaStyle = metaBase.copyWith(fontSize: 12, letterSpacing: 12 * 0.12, color: palette.textDim);

    // Summary text: 17px lineHeight 1.55.
    final summaryBase = styles?.bodyDim ?? const TextStyle();
    final summaryStyle = summaryBase.copyWith(fontSize: 17, height: 1.55, color: palette.textDim);

    final program = item.program;
    final title = program?.title.isNotEmpty == true ? program!.title : item.channelName;
    final genre = program?.category ?? item.groupTitle;
    final synopsis = program?.synopsis;
    final progressValue = program?.progress ?? 0.0;
    final elapsed = program?.elapsed;
    final remaining = program?.remaining;
    final totalDuration = program?.duration;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        // JSX: padding "20px 56px 40px" — top/h/bottom
        padding: const EdgeInsets.fromLTRB(56, 20, 56, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Chips row ──────────────────────────────────────────────
            _ChipsRow(genre: genre, channelName: item.channelName),
            const SizedBox(height: 22),

            // ── Hero title ─────────────────────────────────────────────
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Text(title, style: titleStyle, maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 22),

            // ── Meta row ───────────────────────────────────────────────
            _MetaRow(metaStyle: metaStyle, palette: palette, program: program, genre: genre),
            const SizedBox(height: 18),

            // ── Summary ────────────────────────────────────────────────
            if (synopsis != null && synopsis.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(synopsis, style: summaryStyle, maxLines: 4, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 32),
            ],

            // ── Progress + ticks ───────────────────────────────────────
            if (program != null) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _ProgressBlock(
                  progress: progressValue,
                  elapsed: elapsed,
                  remaining: remaining,
                  total: totalDuration,
                  metaStyle: metaStyle,
                  palette: palette,
                ),
              ),
              const SizedBox(height: 26),
            ] else
              const SizedBox(height: 32),

            // ── Action row ─────────────────────────────────────────────
            _ActionRow(watchFocusNode: watchFocusNode, onWatch: onWatch, onEpg: onEpg, onFavourite: onFavourite),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ChipsRow extends StatelessWidget {
  const _ChipsRow({required this.genre, required this.channelName});
  final String genre;
  final String channelName;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        const Chip(label: 'В эфире', variant: ChipVariant.live),
        if (channelName.isNotEmpty) Chip(label: channelName, variant: ChipVariant.brand, icon: const MMLogo(size: 14)),
        if (genre.isNotEmpty) Chip(label: genre),
        const Chip(label: 'HD · 5.1', variant: ChipVariant.ghost),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.metaStyle, required this.palette, required this.program, required this.genre});

  final TextStyle? metaStyle;
  final dynamic palette; // AppPalette
  final dynamic program; // EpgProgram?
  final String genre;

  @override
  Widget build(BuildContext context) {
    // Build meta items dynamically from available data
    final items = <_MetaEntry>[];

    final rating = '★ 8.4'; // static placeholder — no rating in EpgProgram model
    items.add(_MetaEntry(text: rating, color: AppColors.activePalette.gold));

    final year = program?.parsedYear;
    if (year != null) items.add(_MetaEntry(text: year));

    if (genre.isNotEmpty) items.add(_MetaEntry(text: genre));

    final totalMin = program?.duration?.inMinutes;
    if (totalMin != null && totalMin > 0) {
      final h = totalMin ~/ 60;
      final m = totalMin % 60;
      final dur = h > 0 ? '${h}ч ${m}м' : '$m мин'; // ignore: unnecessary_brace_in_string_interps
      items.add(_MetaEntry(text: dur));
    }

    items.add(_MetaEntry(text: '16+'));
    items.add(_MetaEntry(text: '● Сейчас идёт', color: AppColors.activePalette.accent));

    return Wrap(
      spacing: 24,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final e in items)
          Text(
            e.text,
            style: (metaStyle ?? const TextStyle()).copyWith(
              color: e.color ?? AppColors.activePalette.textDim,
              textBaseline: TextBaseline.alphabetic,
            ),
          ),
      ],
    );
  }
}

class _MetaEntry {
  const _MetaEntry({required this.text, this.color});
  final String text;
  final Color? color;
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({
    required this.progress,
    required this.elapsed,
    required this.remaining,
    required this.total,
    required this.metaStyle,
    required this.palette,
  });

  final double progress;
  final Duration? elapsed;
  final Duration? remaining;
  final Duration? total;
  final TextStyle? metaStyle;
  final dynamic palette;

  String _fmt(Duration? d) {
    if (d == null) return '--:--';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _fmtRemaining(Duration? d) {
    if (d == null) return '';
    final m = d.inMinutes;
    if (m <= 0) return 'заканчивается';
    return 'ещё $m мин';
  }

  @override
  Widget build(BuildContext context) {
    final dimStyle = (metaStyle ?? const TextStyle()).copyWith(color: AppColors.activePalette.textDim);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(child: MvTrack(progress: progress)),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(_fmt(elapsed), style: metaStyle),
            const Spacer(),
            Text(_fmtRemaining(remaining), style: dimStyle),
            const Spacer(),
            Text(_fmt(total), style: metaStyle),
          ],
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.watchFocusNode,
    required this.onWatch,
    required this.onEpg,
    required this.onFavourite,
  });

  final FocusNode watchFocusNode;
  final VoidCallback onWatch;
  final VoidCallback onEpg;
  final VoidCallback onFavourite;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Focus(
          focusNode: watchFocusNode,
          child: Builder(
            builder: (ctx) {
              final focused = Focus.of(ctx).hasFocus;
              return MvButton.primary(
                label: 'Смотреть · продолжить',
                onPressed: onWatch,
                isFocused: focused,
                icon: const Icon(Icons.play_arrow, size: 14),
              );
            },
          ),
        ),
        const SizedBox(width: 14),
        MvButton.ghost(label: 'Программа', onPressed: onEpg, icon: const Icon(Icons.tv, size: 14)),
        const SizedBox(width: 14),
        MvButton.ghost(
          label: 'В избранное',
          onPressed: onFavourite,
          icon: const Icon(Icons.bookmark_outline, size: 14),
        ),
        const Spacer(),
        const ExcludeFocus(
          child: IgnorePointer(
            child: RemoteHint(
              hints: [
                RemoteHintEntry(glyph: '←→', label: 'каналы'),
                RemoteHintEntry(glyph: 'OK', label: 'смотреть'),
                RemoteHintEntry(glyph: '≡', label: 'EPG'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
