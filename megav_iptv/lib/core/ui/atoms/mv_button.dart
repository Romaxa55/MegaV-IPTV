import 'package:flutter/material.dart';

import '../../perf/perf_safe_widgets.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/megav_text_styles.dart';

/// Two height presets for [MvButton].
///
/// `small` → 32 px height, `medium` → 44 px height. Sizes match design.md
/// § 9 MvButton spec; horizontal padding scales accordingly (12 / 18 px).
enum MvButtonSize { small, medium }

/// Internal flavour discriminator selected by the public named ctors.
enum _MvButtonVariant { primary, ghost, accent }

/// Unified button atom with 3 variants (primary / ghost / accent) and 2 sizes.
///
/// Variants:
/// - `primary` → solid `palette.text` background with `palette.background`
///   foreground (high-emphasis CTA).
/// - `ghost` → transparent background with `palette.lineStrong` outline and
///   `palette.text` foreground (secondary action, e.g. «more →» in
///   [SectionTitle]).
/// - `accent` → solid `palette.accent` background with white foreground
///   (focus-emphasis or destructive CTA).
///
/// Wrapped in [SafeFocusRing] when `isFocused == true` so the focus ring
/// renders via `BoxShadow(blurRadius: 0)` — no per-frame `BackdropFilter`,
/// no `Color.lerp` runtime computation in build (Req 10.8, 16.3).
///
/// Maps to Requirements 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 16.3.
class MvButton extends StatelessWidget {
  /// Solid CTA: `palette.text` fill, `palette.background` foreground.
  const MvButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = MvButtonSize.medium,
    this.isFocused = false,
  }) : _variant = _MvButtonVariant.primary;

  /// Transparent fill with `palette.lineStrong` outline.
  const MvButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = MvButtonSize.medium,
    this.isFocused = false,
  }) : _variant = _MvButtonVariant.ghost;

  /// Solid accent CTA: `palette.accent` fill, white foreground.
  const MvButton.accent({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = MvButtonSize.medium,
    this.isFocused = false,
  }) : _variant = _MvButtonVariant.accent;

  /// Visible button label.
  final String label;

  /// Tap callback. `null` → button is rendered but inert (no ripple).
  final VoidCallback? onPressed;

  /// Optional leading widget (typically a small [Icon]).
  final Widget? icon;

  /// Height preset (32 px small / 44 px medium).
  final MvButtonSize size;

  /// Draws the [SafeFocusRing] outline outside the button when `true`.
  final bool isFocused;

  final _MvButtonVariant _variant;

  ({Color bg, Color fg, Color? border}) _resolveColors() {
    final palette = AppColors.activePalette;
    switch (_variant) {
      case _MvButtonVariant.primary:
        return (bg: palette.text, fg: palette.background, border: null);
      case _MvButtonVariant.ghost:
        return (bg: Colors.transparent, fg: palette.text, border: palette.lineStrong);
      case _MvButtonVariant.accent:
        return (bg: palette.accent, fg: Colors.white, border: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors();
    final theme = Theme.of(context);
    final labelStyle = (theme.extension<MegaVTextStyles>()?.bodyDefault ?? theme.textTheme.labelLarge)?.copyWith(
      color: colors.fg,
    );

    final height = size == MvButtonSize.small ? 32.0 : 44.0;
    final paddingH = size == MvButtonSize.small ? 12.0 : 18.0;

    final btn = Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: paddingH),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: AppRadius.brSm,
        border: colors.border != null ? Border.all(color: colors.border!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 8)],
          Text(label, style: labelStyle),
        ],
      ),
    );

    final tappable = Material(
      color: Colors.transparent,
      child: InkWell(onTap: onPressed, borderRadius: AppRadius.brSm, child: btn),
    );

    return SafeFocusRing(isFocused: isFocused, child: tappable);
  }
}
