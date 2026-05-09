import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/megav_text_styles.dart';

/// Five visual flavours for the [Chip] atom.
///
/// `defaultVariant` is named (instead of `default`) because `default` is a
/// reserved keyword in Dart switch-statements.
enum ChipVariant { live, brand, gold, ghost, defaultVariant }

/// Unified chip / badge atom with 5 variants.
///
/// `live` variant has an animated pulse dot wrapped in [RepaintBoundary] to
/// isolate repaints from parent widgets (Req 4.3, 16.5).
///
/// Background mapping (per design.md § 3 Chip):
/// - `live` → `AppPalette.live` + animated 6×6 white dot
/// - `brand` → `AppPalette.accentSoft` + accent text + accent border
/// - `gold` → `AppPalette.goldSoft` + gold text + gold border
/// - `ghost` → transparent + `AppPalette.textDim`
/// - `defaultVariant` → `AppPalette.surface2` + `AppPalette.text`
///
/// Maps to Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 16.5.
class Chip extends StatefulWidget {
  const Chip({super.key, required this.label, this.variant = ChipVariant.defaultVariant, this.icon});

  /// Visible text label rendered inside the pill.
  final String label;

  /// Visual flavour — drives background, foreground and (optionally) the
  /// animated live-pulse dot.
  final ChipVariant variant;

  /// Optional leading widget (typically a small [Icon]). Ignored for
  /// `live` variant since that slot is taken by the animated pulse dot.
  final Widget? icon;

  @override
  State<Chip> createState() => _ChipState();
}

class _ChipState extends State<Chip> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.variant == ChipVariant.live) {
      _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(Chip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variant != widget.variant) {
      if (widget.variant == ChipVariant.live && _controller == null) {
        _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
          ..repeat(reverse: true);
      } else if (widget.variant != ChipVariant.live && _controller != null) {
        _controller!.dispose();
        _controller = null;
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  ({Color bg, Color fg, Color? border}) _resolveColors(AppPalette p) {
    switch (widget.variant) {
      case ChipVariant.live:
        return (bg: p.live, fg: Colors.white, border: null);
      case ChipVariant.brand:
        return (bg: p.accentSoft, fg: p.accent, border: p.accentSoft);
      case ChipVariant.gold:
        return (bg: p.goldSoft, fg: p.gold, border: p.goldSoft);
      case ChipVariant.ghost:
        return (bg: Colors.transparent, fg: p.textDim, border: null);
      case ChipVariant.defaultVariant:
        return (bg: p.surface2, fg: p.text, border: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.activePalette;
    final colors = _resolveColors(palette);
    final theme = Theme.of(context);
    final labelStyle = (theme.extension<MegaVTextStyles>()?.metaMono ?? theme.textTheme.labelSmall)?.copyWith(
      color: colors.fg,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
        border: colors.border != null ? Border.all(color: colors.border!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.variant == ChipVariant.live) ...[
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller!,
                builder: (_, _) {
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5 + 0.5 * _controller!.value),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
            ),
          ] else if (widget.icon != null) ...[
            widget.icon!,
            const SizedBox(width: 6),
          ],
          Text(widget.label, style: labelStyle),
        ],
      ),
    );
  }
}
