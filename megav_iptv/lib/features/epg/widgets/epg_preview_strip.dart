import 'package:flutter/material.dart' hide Chip;

import '../../../core/playlist/models/channel.dart';
import '../../../core/playlist/models/epg_program.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Sticky bottom preview strip for the EPG screen.
///
/// JSX reference (`epg-v2.jsx` PREVIEW STRIP):
/// ```jsx
/// <div style={{
///   borderTop: "1px solid var(--line)", padding: "20px 56px",
///   display: "flex", alignItems: "center", gap: 24,
///   background: "rgba(15,15,20,0.8)",
/// }}>
///   <div style={{width: 132, height: 76, borderRadius: 8, ...}}>thumb</div>
///   <div style={{flex: 1}}>
///     <div style={{fontFamily:"var(--font-mono)", fontSize:10, ...}}>channel · time · LIVE</div>
///     <div style={{fontFamily:"var(--font-display)", fontWeight:600, fontSize:30,
///       lineHeight:1.05, letterSpacing:"-0.015em"}}>title</div>
///     {isLive && progress track}
///   </div>
///   <button>Смотреть (OK)</button>
///   <button>i Подробно</button>
/// </div>
/// ```
///
/// Performance contract:
/// - No BackdropFilter (JSX uses blur(20px) — forbidden).
/// - Thumb wrapped in RepaintBoundary.
/// - No animated width containers.
///
/// Maps to Requirements 10.1–10.5, 13.1, 13.2.
class EpgPreviewStrip extends StatelessWidget {
  const EpgPreviewStrip({super.key, this.program, this.channel, this.onWatch, this.onDetails});

  final EpgProgram? program;
  final Channel? channel;
  final VoidCallback? onWatch;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.activePalette;
    final theme = Theme.of(context);
    final megavText = theme.extension<MegaVTextStyles>();

    final topBorder = Border(top: BorderSide(color: palette.line));
    // JSX: background "rgba(15,15,20,0.8)" — opaque approx.
    final stripBg = const Color(0xFF0F0F14).withAlpha(0xCC);

    if (program == null || channel == null) {
      // Empty placeholder: same key, fixed height for layout stability.
      return Container(
        key: const Key('epg-preview-strip'),
        height: 96,
        decoration: BoxDecoration(border: topBorder, color: stripBg),
      );
    }

    final p = program!;
    final c = channel!;

    // Title: display 30sp, w600, lh=1.05, ls=-0.015em. JSX uses font-display.
    final titleStyle = (megavText?.displayLarge ?? theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w600,
      height: 1.05,
      letterSpacing: -0.015 * 30,
      color: palette.text,
    );
    // Meta: mono 10sp, ls=0.18em, textMute, uppercase.
    final metaStyle = (megavText?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 10,
      letterSpacing: 0.18 * 10,
      color: palette.textMute,
    );
    final liveChipStyle = metaStyle.copyWith(fontWeight: FontWeight.w600, color: Colors.white);

    return Container(
      key: const Key('epg-preview-strip'),
      decoration: BoxDecoration(border: topBorder, color: stripBg),
      // JSX: padding "20px 56px".
      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Thumbnail — 132×76, borderRadius 8.
          RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 132, height: 76, child: _buildThumb(p, c)),
            ),
          ),
          const SizedBox(width: 24),
          // Meta + title + (optional progress).
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Channel · time range · LIVE chip.
                Row(
                  children: [
                    Text(c.name, style: metaStyle),
                    Text(' · ', style: metaStyle),
                    Text(_formatRange(p), style: metaStyle),
                    Text(' · ${p.duration.inMinutes} мин', style: metaStyle),
                    if (p.isNow) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: palette.accent, borderRadius: BorderRadius.circular(4)),
                        child: Text('● LIVE', style: liveChipStyle),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Programme title.
                Text(p.title, style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                // Progress track for live programmes.
                if (p.isNow) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: MvTrack(progress: p.progress, showKnob: false)),
                      const SizedBox(width: 12),
                      Text('ещё ${_remainingMin(p)} мин', style: metaStyle),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 24),
          // CTAs.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p.isNow)
                MvButton.primary(label: 'Смотреть', onPressed: onWatch)
              else
                MvButton.ghost(label: 'Напомнить', onPressed: onWatch),
              const SizedBox(width: 10),
              MvButton.ghost(label: 'Подробнее', onPressed: onDetails),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumb(EpgProgram p, Channel c) {
    final url = p.icon ?? c.logoUrl;
    if (url == null || url.isEmpty) {
      return ColoredBox(color: AppColors.activePalette.surface2);
    }
    return Poster(image: NetworkImage(url), orientation: PosterOrientation.landscape, hideText: true);
  }
}

String _formatRange(EpgProgram p) => '${_hhmm(p.start)}–${_hhmm(p.end)}';

String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

int _remainingMin(EpgProgram p) {
  final remaining = p.end.difference(DateTime.now()).inMinutes;
  return remaining < 0 ? 0 : remaining;
}
