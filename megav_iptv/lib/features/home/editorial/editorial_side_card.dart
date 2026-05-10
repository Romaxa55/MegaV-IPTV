import 'package:flutter/material.dart' hide Chip;

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/playlist/models/now_playing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Editorial side card — flat semi-opaque tile: poster thumb + eyebrow +
/// italic title + meta line + accent countdown.
///
/// JSX reference (`home-editorial.jsx` SideCard):
/// ```jsx
/// <div style={{display:"flex", gap: 14, padding: 14,
///   background: "rgba(20,20,26,0.55)", border: "1px solid var(--line)",
///   borderRadius: "var(--r-md)", backdropFilter: "blur(12px)"}}>
///   <Poster idx={idx} w={84} h={112} />
///   <div style={{flex:1}}>
///     <div style={{fontFamily:"var(--font-mono)", fontSize:10, letterSpacing:"0.14em",
///       color:"var(--text-mute)", textTransform:"uppercase"}}>{label}</div>
///     <div style={{fontFamily:"var(--font-display)", fontStyle:"italic",
///       fontSize:22, lineHeight:1.1, marginTop:6}}>{t.t}</div>
///     <div style={{fontSize:12, color:"var(--text-dim)", marginTop:4}}>{t.y} · {t.g}</div>
///     <div style={{fontFamily:"var(--font-mono)", fontSize:10,
///       color:"var(--accent)", letterSpacing:"0.1em"}}>{remaining}</div>
///   </div>
/// </div>
/// ```
///
/// Perf contract: NO BackdropFilter (JSX uses blur(12px) — forbidden on
/// 512 MB Android 6; replaced by opaque surface2.withAlpha(0x8C)).
class EditorialSideCard extends StatefulWidget {
  const EditorialSideCard.next({super.key, required this.item, required this.remaining})
    : label = 'ДАЛЕЕ В ЭФИРЕ',
      slot = 'next';

  const EditorialSideCard.featured({super.key, required this.item, required this.remaining})
    : label = 'РЕКОМЕНДУЕМ',
      slot = 'featured';

  final NowPlayingItem item;
  final String remaining;
  final String label;
  final String slot;

  @override
  State<EditorialSideCard> createState() => _EditorialSideCardState();
}

class _EditorialSideCardState extends State<EditorialSideCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final palette = AppColors.activePalette;

    // Eyebrow: mono 10sp, ls=0.14em, textMute, uppercase.
    final eyebrowStyle = (styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 10,
      letterSpacing: 0.14 * 10,
      color: palette.textMute,
    );

    // Title: display italic 22sp, lh=1.1, text.
    final titleStyle = (styles?.displayItalic ?? theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
      fontSize: 22,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w400,
      height: 1.1,
      color: palette.text,
    );

    // Meta line: 12sp, textDim.
    final metaStyle = (styles?.bodyDim ?? theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
      fontSize: 12,
      color: palette.textDim,
    );

    // Countdown: mono 10sp, ls=0.1em, accent.
    final countdownStyle = (styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 10,
      letterSpacing: 0.1 * 10,
      color: palette.accent,
    );

    final program = widget.item.program;
    final title = program?.title ?? widget.item.channelName;
    final year = program?.parsedYear;
    final genre = program?.category ?? widget.item.groupTitle;
    final metaParts = <String>[if (year != null && year.isNotEmpty) year, if (genre.isNotEmpty) genre];
    final metaLine = metaParts.join(' · ');
    final posterUrl = program?.icon ?? widget.item.thumbnailUrl ?? widget.item.logoUrl ?? '';

    return Focus(
      onFocusChange: (hasFocus) {
        if (_focused != hasFocus) setState(() => _focused = hasFocus);
      },
      child: SafeFocusRing(
        isFocused: _focused,
        child: DecoratedBox(
          key: Key('editorial-side-card-${widget.slot}'),
          decoration: BoxDecoration(
            // JSX: rgba(20,20,26,0.55) — no backdrop blur (perf constraint).
            color: palette.surface2.withAlpha(0x8C),
            border: Border.all(color: palette.line),
            // JSX: borderRadius var(--r-md) = 14px.
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            // JSX: padding: 14.
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // JSX: Poster w=84 h=112.
                SizedBox(
                  width: 84,
                  height: 112,
                  child: Poster(
                    image: NetworkImage(posterUrl),
                    orientation: PosterOrientation.portrait,
                    hideText: true,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Eyebrow label.
                          Text(widget.label, style: eyebrowStyle, maxLines: 1),
                          const SizedBox(height: 6),
                          // Italic display title.
                          Text(title, style: titleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (metaLine.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(metaLine, style: metaStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Accent countdown.
                      Text(widget.remaining, style: countdownStyle),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
