import 'package:flutter/material.dart' hide Chip;

import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Top bar for cinematic player: back button + Brand + LIVE chip +
/// program title + optional bitrate chip.
///
/// Maps to Req 1, Req 12.
class CinematicTopBar extends StatelessWidget {
  const CinematicTopBar({
    super.key,
    required this.channelName,
    required this.programTitle,
    this.bitrateLabel,
    required this.onBack,
    this.focusNode,
  });

  final String channelName;
  final String programTitle;
  final String? bitrateLabel;
  final VoidCallback onBack;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final titleStyle = styles?.bodyDefault ?? theme.textTheme.titleMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          MvIconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
          const SizedBox(width: 12),
          const Brand(size: 28),
          const SizedBox(width: 12),
          const Chip(label: 'LIVE', variant: ChipVariant.live),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              programTitle.isEmpty ? channelName : programTitle,
              style: titleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (bitrateLabel != null) ...[
            const SizedBox(width: 12),
            Chip(label: bitrateLabel!, variant: ChipVariant.brand),
          ],
        ],
      ),
    );
  }
}
