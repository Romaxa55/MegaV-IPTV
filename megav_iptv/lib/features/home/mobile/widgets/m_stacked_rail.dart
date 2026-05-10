import 'package:flutter/material.dart' hide Chip;

import '../../../../core/playlist/models/channel.dart';
import '../../../../core/ui/atoms/atoms.dart';

/// Mobile two-column stacked rail — [SectionTitle] header + a non-scrollable
/// 2-column [GridView] of portrait [Poster] tiles.
///
/// Lives under `lib/features/home/mobile/widgets/` (mobile boundary —
/// task 3.4). The grid is `shrinkWrap: true` + `NeverScrollableScrollPhysics`
/// so the rail composes with the parent [ListView] without nested-scroll
/// fights.
///
/// Maps to Requirements 7.4.
class MStackedRail extends StatelessWidget {
  const MStackedRail({super.key, required this.title, required this.emphasis, required this.items});

  /// Upright section heading (e.g. «Кино»).
  final String title;

  /// Italic emphasis word rendered after [title] (e.g. «для вечера»).
  final String emphasis;

  /// Channels rendered as portrait posters in a 2-column grid.
  final List<Channel> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('m-stacked-rail'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionTitle(title: title, emphasis: emphasis, count: items.length),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2 / 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: items
                .map((c) => Poster(image: NetworkImage(c.logoUrl ?? ''), orientation: PosterOrientation.portrait))
                .toList(),
          ),
        ),
      ],
    );
  }
}
