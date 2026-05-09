import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Generic option-pill row using [MvButton.accent] for the active value
/// and [MvButton.ghost] for inactive options. Optionally renders a
/// disabled hint underneath when [enabled] is `false` and [disabledHint]
/// is non-null (Req 11.x).
class MvPicker<T> extends StatelessWidget {
  const MvPicker({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.enabled = true,
    this.disabledHint,
  });

  /// All selectable values, in display order.
  final List<T> options;

  /// Currently selected value. Must be present in [options].
  final T value;

  /// Selection callback.
  final ValueChanged<T> onChanged;

  /// Label resolver — used to produce the visible string for an option.
  final String Function(T) labelOf;

  /// When `false`, all option buttons render with `onPressed: null`.
  final bool enabled;

  /// Optional sub-text rendered when [enabled] is `false`.
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final hintStyle = styles?.bodyDim ?? theme.textTheme.bodySmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: options
              .map((opt) {
                final label = labelOf(opt);
                if (opt == value) {
                  return MvButton.accent(label: label, onPressed: enabled ? () => onChanged(opt) : null);
                }
                return MvButton.ghost(label: label, onPressed: enabled ? () => onChanged(opt) : null);
              })
              .toList(growable: false),
        ),
        if (!enabled && disabledHint != null) ...[SizedBox(height: 6.h), Text(disabledHint!, style: hintStyle)],
      ],
    );
  }
}
