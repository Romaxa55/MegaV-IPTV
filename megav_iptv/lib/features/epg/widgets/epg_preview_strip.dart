import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/playlist/models/epg_program.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Sticky bottom preview strip rendered below the EPG time grid.
///
/// Shows the currently focused programme alongside its channel: a small
/// `_PreviewThumb` (channel icon / programme icon) on the left, the
/// programme title + meta line in the middle, and a single CTA on the
/// right — `MvButton.primary('Смотреть')` if [program] is currently live,
/// otherwise `MvButton.ghost('Подробнее')` (visually equivalent to a
/// "secondary" button — `MvButton` exposes only `.primary`/`.ghost`/`.accent`
/// named ctors, no `.secondary`).
///
/// The strip itself does NOT debounce focus changes — the caller is
/// expected to drive [program] / [channel] from `EpgFocusController` after
/// the 400 ms stabilisation timer fires (Req 9.5, 10.3).
///
/// Null-safe: when [program] or [channel] is `null` (e.g. focus is on an
/// empty cell or the screen has not yet selected a programme), the strip
/// renders an empty container of the same height with the same root key,
/// so smoke tests probing for `Key('epg-preview-strip')` keep passing.
///
/// Performance contract (Req 13.1, 13.2):
/// - No GPU-blurring widgets in the build tree (no `BackdropFilter`,
///   `ShaderMask`, `ImageFilter.blur`).
/// - No animated `width:` on any container — the strip is a plain
///   `Container` with a static `BoxDecoration`.
/// - The thumb is wrapped in a [RepaintBoundary] so re-paints driven by
///   the metadata column do not propagate into the image's render layer
///   (Req 10.2).
///
/// Maps to Requirements 10.1, 10.2, 10.3, 10.4, 10.5, 13.1, 13.2.
class EpgPreviewStrip extends StatelessWidget {
  const EpgPreviewStrip({super.key, this.program, this.channel, this.onWatch, this.onDetails});

  /// Currently focused programme. May be `null` when no programme is
  /// focused yet.
  final EpgProgram? program;

  /// Channel that owns [program]. May be `null` when the focused cell is
  /// empty or the channel list has not yet loaded.
  final Channel? channel;

  /// Tap handler for the primary "Смотреть" CTA — invoked only when
  /// [program] is live (`program.isNow == true`).
  final VoidCallback? onWatch;

  /// Tap handler for the ghost "Подробнее" CTA — invoked when [program]
  /// is upcoming or finished (`program.isNow == false`).
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.activePalette;
    final theme = Theme.of(context);
    final megavText = theme.extension<MegaVTextStyles>();

    // Top hairline divider — uses `palette.line` (subtle divider token).
    final topBorder = Border(top: BorderSide(color: palette.line));

    // Empty / loading state: keep the same key + same height so layout
    // and smoke-tests remain stable.
    if (program == null || channel == null) {
      return Container(
        key: const Key('epg-preview-strip'),
        height: 96.h,
        decoration: BoxDecoration(border: topBorder),
        child: const SizedBox.shrink(),
      );
    }

    final p = program!;
    final c = channel!;

    final titleStyle = (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(fontStyle: FontStyle.normal);
    final metaStyle = megavText?.metaMono ?? theme.textTheme.labelSmall;

    return Container(
      key: const Key('epg-preview-strip'),
      height: 96.h,
      decoration: BoxDecoration(border: topBorder),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PreviewThumb(channel: c, programme: p),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title, style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 4.h),
                Text('${c.name} · ${_formatRange(p)}', style: metaStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          if (p.isNow)
            MvButton.primary(label: 'Смотреть', onPressed: onWatch)
          else
            // `MvButton` has no `.secondary` named ctor; `.ghost` is the
            // direct visual equivalent for the inactive / non-live branch.
            MvButton.ghost(label: 'Подробнее', onPressed: onDetails),
        ],
      ),
    );
  }
}

/// Private leaf widget that renders the strip's thumbnail.
///
/// Wrapped in a [RepaintBoundary] (Req 10.2) so changes in the parent
/// `EpgPreviewStrip` (title text, focus updates, button state) never
/// trigger a re-decode / re-paint of the underlying image. Sized to a
/// fixed 132 × 76 design pixels so layout never reflows when the
/// programme changes.
class _PreviewThumb extends StatelessWidget {
  const _PreviewThumb({required this.channel, required this.programme});

  final Channel channel;
  final EpgProgram programme;

  @override
  Widget build(BuildContext context) {
    // Prefer programme icon (per-programme artwork from EPG XMLTV) and
    // fall back to the channel logo when none is provided.
    final imageUrl = programme.icon ?? channel.logoUrl;

    return RepaintBoundary(
      child: SizedBox(
        width: 132.w,
        height: 76.h,
        child: imageUrl == null || imageUrl.isEmpty
            ? const ColoredBox(color: Color(0xFF12121E))
            : Poster(image: NetworkImage(imageUrl), orientation: PosterOrientation.landscape, hideText: true),
      ),
    );
  }
}

/// Formats a programme's `start – end` range as `HH:MM – HH:MM`
/// (24-hour, zero-padded), mirroring the formatter in
/// `epg_time_axis.dart` and `epg_program_cell.dart` so all EPG
/// timestamps render identically.
String _formatRange(EpgProgram p) => '${_hhmm(p.start)} – ${_hhmm(p.end)}';

String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
