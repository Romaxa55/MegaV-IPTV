import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/atoms/atoms.dart';

/// Mobile home top bar — left meta column (city/temp/time stubs) + trailing
/// [Brand] mark.
///
/// Lives under `lib/features/home/mobile/widgets/` (mobile boundary —
/// task 3.2). Uses the [Brand] atom for the wordmark; meta values are static
/// stubs for Phase 3 and are wired to live data in a follow-up task.
///
/// Maps to Requirements 7.1, 7.2.
class MTopBar extends ConsumerWidget {
  const MTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.activePalette;
    return Padding(
      key: const Key('m-top-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Москва', style: TextStyle(fontSize: 14, color: palette.text)),
              Text('—7°', style: TextStyle(fontSize: 12, color: palette.textDim)),
              Text('21:14', style: TextStyle(fontSize: 11, color: palette.textMute)),
            ],
          ),
          const Spacer(),
          const Brand(),
        ],
      ),
    );
  }
}
