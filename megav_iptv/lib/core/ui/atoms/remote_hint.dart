import 'package:flutter/material.dart';

import '../../theme/megav_text_styles.dart';
import 'mv_key.dart';

/// Single keycap-hint pair: glyph + label (e.g. "↑" + "Up", "OK" + "Confirm").
class RemoteHintEntry {
  const RemoteHintEntry({required this.glyph, required this.label});

  final String glyph;
  final String label;
}

/// Horizontal row of keycap pills + descriptive labels for TV remote hints
/// shown at the bottom of screens.
///
/// Maps to Requirements 9.1, 9.2, 9.3, 9.4.
class RemoteHint extends StatelessWidget {
  const RemoteHint({super.key, required this.hints, this.alignment = MainAxisAlignment.start});

  final List<RemoteHintEntry> hints;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.extension<MegaVTextStyles>()?.metaMono ?? theme.textTheme.labelSmall;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        for (int i = 0; i < hints.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MvKey(glyph: hints[i].glyph),
              const SizedBox(width: 6),
              Text(hints[i].label, style: labelStyle),
            ],
          ),
        ],
      ],
    );
  }
}
