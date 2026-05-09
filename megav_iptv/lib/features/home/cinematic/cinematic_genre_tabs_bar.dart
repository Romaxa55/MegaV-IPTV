import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Horizontal genre-tabs bar wrapping atom [GenreTabs] with edge-fade
/// gradients (left/right 32px) drawn via `DecoratedBox + LinearGradient`
/// — never via runtime shader masking (Req 3.4, 9.1).
///
/// Maps to Requirements 3.1-3.5, 9.1-9.2, 13.1.
class CinematicGenreTabsBar extends ConsumerWidget {
  const CinematicGenreTabsBar({
    super.key,
    required this.labels,
    required this.activeIndex,
    this.onTabChanged,
    this.height = 56,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int>? onTabChanged;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.activePalette;
    final bgOpaque = palette.background;
    final bgTransparent = palette.background.withValues(alpha: 0);

    return SizedBox(
      key: const Key('cinematic-genre-tabs'),
      height: height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Tabs row (atom)
          Positioned.fill(
            child: GenreTabs(labels: labels, activeIndex: activeIndex, onTabChanged: onTabChanged),
          ),
          // Left fade
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 32,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [bgOpaque, bgTransparent],
                  ),
                ),
              ),
            ),
          ),
          // Right fade (mirrored)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 32,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [bgOpaque, bgTransparent],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
