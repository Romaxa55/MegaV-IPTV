import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/playlist/models/channel.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/atoms/atoms.dart';

/// Tall mobile hero card — large poster image + scrim + title + primary CTA,
/// followed by a row of carousel dots indicating slide count.
///
/// Lives under `lib/features/home/mobile/widgets/` (mobile boundary —
/// task 3.3). Image fallback is implemented via [Image.errorBuilder] so we
/// never have to construct an empty/placeholder byte buffer.
///
/// Maps to Requirements 7.3.
class MHeroCard extends ConsumerWidget {
  const MHeroCard({super.key, required this.channels});

  /// Featured channels driving the card. The first entry is rendered as the
  /// hero; the full list determines the dot-row count below the card.
  final List<Channel> channels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (channels.isEmpty) {
      return const SizedBox.shrink();
    }
    final hero = channels.first;
    final palette = AppColors.activePalette;
    final logoUrl = hero.logoUrl ?? '';

    return Column(
      key: const Key('m-hero-card'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 380,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: logoUrl.isEmpty
                        ? ColoredBox(color: palette.surface2)
                        : Image(
                            image: NetworkImage(logoUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(color: palette.surface2),
                          ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hero.name,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        MvButton.primary(label: 'Смотреть', onPressed: () {}),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            channels.length,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: i == 0 ? palette.accent : palette.textDim),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
