import 'dart:async';

import 'package:flutter/material.dart' hide Chip;

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/playlist/models/now_playing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Value-object describing a single bento cell — its source [item], the
/// number of grid columns and rows it spans (`cols`, `rows`), and whether
/// the live-pulse chip should be drawn over it.
///
/// The cell is intentionally orientation-agnostic: layout decisions live
/// in [EditorialBentoGrid]; this type only carries data.
class EditorialBentoCell {
  const EditorialBentoCell({required this.item, required this.cols, required this.rows, this.live = false});

  final NowPlayingItem item;
  final int cols;
  final int rows;
  final bool live;
}

/// Editorial bento card — a flat tile with a full-bleed cover image,
/// vertical darkening gradient, italic display title, mono year/genre
/// meta line and an optional live-pulse chip.
///
/// Title font scales with cell footprint:
/// - cells ≥ 2×2 → 36 sp italic display
/// - smaller cells → 20 sp italic display
///
/// **Perf contract**: NO `BackdropFilter`, NO `ShaderMask`, NO blur
/// radii beyond [kSafeShadowBlurMax]. The dark gradient is a plain
/// `LinearGradient` painted by `DecoratedBox` (Req 9.1, 9.2, 13.3).
///
/// Focus is debounced (400 ms) before notifying the caller — this
/// prevents focus-thrash from triggering remote network fetches in
/// parent screens that react to focus changes (see Req 6.4).
class EditorialBentoCard extends StatefulWidget {
  EditorialBentoCard({Key? key, required this.cell, this.onTap, this.onFocusChange})
    : super(key: key ?? Key('editorial-bento-card-${cell.item.channelId}'));

  final EditorialBentoCell cell;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<EditorialBentoCard> createState() => _EditorialBentoCardState();
}

class _EditorialBentoCardState extends State<EditorialBentoCard> {
  bool _focused = false;
  Timer? _focusDebounce;

  @override
  void dispose() {
    _focusDebounce?.cancel();
    super.dispose();
  }

  void _handleFocus(bool hasFocus) {
    if (_focused != hasFocus) {
      setState(() => _focused = hasFocus);
    }
    _focusDebounce?.cancel();
    if (hasFocus) {
      _focusDebounce = Timer(const Duration(milliseconds: 400), () {
        widget.onFocusChange?.call(true);
      });
    } else {
      // Sync — surrendering focus must not be debounced (Req 6.4).
      widget.onFocusChange?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final AppPalette palette = AppColors.activePalette;

    final displayItalic = styles?.displayItalic ?? theme.textTheme.headlineSmall ?? const TextStyle();
    final metaMono = styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle();

    final cell = widget.cell;
    final program = cell.item.program;

    final title = program?.title ?? cell.item.channelName;

    final year = program?.parsedYear ?? '';
    final genre = program?.category ?? cell.item.groupTitle;
    String metaLine;
    if (year.isEmpty) {
      metaLine = genre;
    } else if (genre.isEmpty) {
      metaLine = year;
    } else {
      metaLine = '$year · $genre';
    }

    final imageUrl = cell.item.thumbnailUrl ?? cell.item.logoUrl ?? '';

    final bool large = cell.cols >= 2 && cell.rows >= 2;
    final TextStyle titleStyle = large
        ? displayItalic.copyWith(fontSize: 36, fontStyle: FontStyle.italic, color: Colors.white)
        : displayItalic.copyWith(fontSize: 20, fontStyle: FontStyle.italic, color: Colors.white);

    return GestureDetector(
      onTap: widget.onTap,
      child: Focus(
        onFocusChange: _handleFocus,
        child: Transform.scale(
          scale: _focused ? 1.04 : 1.0,
          child: SafeFocusRing(
            isFocused: _focused,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: _focused
                    ? <BoxShadow>[BoxShadow(blurRadius: kSafeShadowBlurMax, color: palette.accentGlow)]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: imageUrl.isEmpty
                          ? ColoredBox(color: palette.surface2)
                          : Image(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => ColoredBox(color: palette.surface2),
                            ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x0D000000), Color(0xD9000000)],
                          ),
                        ),
                      ),
                    ),
                    if (cell.live)
                      const Positioned(
                        top: 12,
                        left: 12,
                        child: Chip(variant: ChipVariant.live, label: 'Live'),
                      ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title, style: titleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          if (metaLine.isNotEmpty)
                            Text(
                              metaLine,
                              style: metaMono.copyWith(color: Colors.white70, letterSpacing: 0.12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
