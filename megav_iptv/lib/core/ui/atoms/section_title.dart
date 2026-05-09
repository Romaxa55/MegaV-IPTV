import 'package:flutter/material.dart' hide Chip;

import '../../theme/megav_text_styles.dart';
import 'chip.dart';
import 'mv_button.dart';

/// Section header — display H3 + optional italic emphasis + optional count
/// badge + optional «more →» action button.
///
/// Layout (left → right):
/// 1. Upright display title (`displayLarge`).
/// 2. Optional italic emphasis word (`displayItalic`) — used for editorial
///    accents like `Tonight, для тебя` where `для тебя` reads italic.
/// 3. Optional count badge rendered via [Chip] with `ChipVariant.ghost`.
/// 4. Spacer pushes the optional `more →` [MvButton.ghost] to the trailing
///    edge when `onMore != null`; otherwise the row ends at the count badge.
///
/// All sub-elements are optional except [title]; the row collapses cleanly
/// when only `title` is provided.
///
/// Maps to Requirements 8.1, 8.2, 8.3, 8.4.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.emphasis, this.count, this.onMore});

  /// Primary section heading (upright editorial display).
  final String title;

  /// Optional italic emphasis word rendered immediately after [title].
  final String? emphasis;

  /// Optional integer count rendered as a small ghost [Chip].
  final int? count;

  /// Optional «more →» action callback. When `null`, the trailing button is
  /// omitted entirely (no Spacer-only trailing whitespace).
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final titleStyle = styles?.displayLarge ?? theme.textTheme.headlineSmall;
    final emphasisStyle = styles?.displayItalic ?? theme.textTheme.headlineSmall?.copyWith(fontStyle: FontStyle.italic);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: titleStyle),
        if (emphasis != null) ...[const SizedBox(width: 6), Text(emphasis!, style: emphasisStyle)],
        if (count != null) ...[const SizedBox(width: 12), Chip(label: count.toString(), variant: ChipVariant.ghost)],
        const Spacer(),
        if (onMore != null) MvButton.ghost(label: 'more →', onPressed: onMore, size: MvButtonSize.small),
      ],
    );
  }
}
