import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Cinematic live strip — LIVE chip + MMLogo + current/next program text +
/// progress track. Stream-consumer (progress) is isolated in private
/// [_LiveProgress] under [RepaintBoundary] (Req 6.3, 9.6).
///
/// Maps to Requirements 6.1-6.5, 9.1-9.2, 9.6, 13.1.
class CinematicLiveStrip extends ConsumerWidget {
  const CinematicLiveStrip({super.key, this.currentTitle, this.nextLabel, this.progress});

  final String? currentTitle;
  final String? nextLabel;
  final double? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final headlineStyle = styles?.bodyDefault ?? theme.textTheme.titleSmall;
    final metaStyle = styles?.metaMono ?? theme.textTheme.labelSmall;

    return Container(
      key: const Key('cinematic-live-strip'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Chip(label: 'LIVE', variant: ChipVariant.live),
          const SizedBox(width: 12),
          const MMLogo(size: 32),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (currentTitle != null && currentTitle!.isNotEmpty)
                  Text(currentTitle!, style: headlineStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (nextLabel != null && nextLabel!.isNotEmpty)
                  Text(nextLabel!, style: metaStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: _LiveProgress(progress: progress ?? 0)),
        ],
      ),
    );
  }
}

/// Private RepaintBoundary-isolated progress consumer. Const ctor on parent
/// = no rebuild on parent state change (Req 9.6).
class _LiveProgress extends StatelessWidget {
  const _LiveProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: MvTrack(progress: progress));
  }
}
