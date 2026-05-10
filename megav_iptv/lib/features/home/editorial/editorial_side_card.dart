import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/playlist/models/now_playing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Editorial side card — flat semi-opaque tile that pairs a portrait
/// poster thumbnail with an eyebrow label, italic display title, mono
/// year/genre meta line and an accent-coloured countdown.
///
/// Two named ctors set the eyebrow label:
/// - `EditorialSideCard.next(...)` → label `ДАЛЕЕ В ЭФИРЕ` (slot
///   `next`).
/// - `EditorialSideCard.featured(...)` → label `РЕКОМЕНДУЕМ` (slot
///   `featured`).
///
/// The widget tracks focus via a [Focus] callback so the surrounding
/// [SafeFocusRing] can light up — focus state is the only reason the
/// widget is a `StatefulWidget`.
///
/// **Perf contract**: NO `BackdropFilter` (Req 4.2). The semi-opaque
/// look is built from `palette.surface2.withValues(alpha: 0.55)` over a
/// hairline `palette.line` border — runtime blur over Texture layers is
/// catastrophic on the rtd2851a target.
///
/// Maps to Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 9.1, 9.2 and 13.1 of
/// `home-editorial-redesign`.
class EditorialSideCard extends StatefulWidget {
  /// Eyebrow label `ДАЛЕЕ В ЭФИРЕ`.
  const EditorialSideCard.next({super.key, required this.item, required this.remaining})
    : label = 'ДАЛЕЕ В ЭФИРЕ',
      slot = 'next';

  /// Eyebrow label `РЕКОМЕНДУЕМ`.
  const EditorialSideCard.featured({super.key, required this.item, required this.remaining})
    : label = 'РЕКОМЕНДУЕМ',
      slot = 'featured';

  /// Source item providing poster / title / meta-fields. The card
  /// gracefully falls back to channel-level fields when no EPG program
  /// is attached.
  final NowPlayingItem item;

  /// Pre-formatted countdown (e.g. `через 55 мин`, `2ч 06м`). Caller
  /// owns formatting.
  final String remaining;

  /// Eyebrow label baked in by the named ctor.
  final String label;

  /// Slot identifier used to namespace the root [Key] (`next` or
  /// `featured`).
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

    final metaMono = styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle();
    final displayItalic = styles?.displayItalic ?? theme.textTheme.headlineSmall ?? const TextStyle();
    final bodyDim = styles?.bodyDim ?? theme.textTheme.bodySmall ?? const TextStyle();

    final program = widget.item.program;
    final title = program?.title ?? widget.item.channelName;
    final year = program?.parsedYear;
    final genre = program?.category ?? widget.item.groupTitle;
    final metaParts = <String>[if (year != null && year.isNotEmpty) year, if (genre.isNotEmpty) genre];
    final metaLine = metaParts.join(' · ');

    final posterUrl = program?.icon ?? widget.item.thumbnailUrl ?? widget.item.logoUrl ?? '';

    return Focus(
      onFocusChange: (hasFocus) {
        if (_focused != hasFocus) {
          setState(() => _focused = hasFocus);
        }
      },
      child: SafeFocusRing(
        isFocused: _focused,
        child: DecoratedBox(
          key: Key('editorial-side-card-${widget.slot}'),
          decoration: BoxDecoration(
            color: palette.surface2.withValues(alpha: 0.55),
            border: Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 84.w,
                  height: 112.h,
                  child: Poster(
                    image: NetworkImage(posterUrl),
                    orientation: PosterOrientation.portrait,
                    hideText: true,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.label, style: metaMono.copyWith(color: palette.textMute)),
                      SizedBox(height: 6.h),
                      Text(
                        title,
                        style: displayItalic.copyWith(fontSize: 20, height: 1.1, color: palette.text),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (metaLine.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          metaLine,
                          style: bodyDim.copyWith(color: palette.textDim),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: 8.h),
                      Text(widget.remaining, style: metaMono.copyWith(color: palette.accent)),
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
