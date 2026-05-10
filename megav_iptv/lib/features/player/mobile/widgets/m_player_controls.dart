import 'dart:ui';

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../mobile/widgets/m_icon_btn.dart';

/// Mobile player control bar — frosted glass row with previous / play /
/// next icon buttons and a placeholder volume track.
///
/// Lives inside the mobile boundary (`features/player/mobile/`) where
/// [BackdropFilter] is permitted (mobile-adaptive-layout Phase 5 task 5.2).
class MPlayerControls extends ConsumerWidget {
  const MPlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.activePalette;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        key: const Key('m-player-controls'),
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            color: palette.surface2.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: const [
                MIconBtn(icon: Icons.skip_previous),
                MIconBtn(icon: Icons.play_arrow),
                MIconBtn(icon: Icons.skip_next),
                SizedBox(width: 16),
                Expanded(
                  child: SizedBox(height: 4, child: ColoredBox(color: Colors.white24)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
