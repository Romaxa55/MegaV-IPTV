import 'package:flutter/material.dart' hide Chip;

import '../../../core/ui/atoms/atoms.dart';
import 'cinematic_rail.dart';

/// Façade over [CinematicRail] with named constructors for landscape and
/// portrait orientations. Renders ONE rail per instance — the dual-rail
/// composition (landscape over portrait) happens at the caller (Phase 5
/// CinematicHomeScreen).
///
/// Maps to Requirements 4.1-4.5, 13.1.
class CinematicDualRail extends StatelessWidget {
  const CinematicDualRail.landscape({super.key, required this.items, this.onItemTap, this.onItemFocus})
    : orientation = PosterOrientation.landscape;

  const CinematicDualRail.portrait({super.key, required this.items, this.onItemTap, this.onItemFocus})
    : orientation = PosterOrientation.portrait;

  final List<CinematicRailItem> items;
  final PosterOrientation orientation;
  final void Function(CinematicRailItem item)? onItemTap;
  final void Function(CinematicRailItem item)? onItemFocus;

  Key get _railKey => orientation == PosterOrientation.landscape
      ? const Key('cinematic-dual-rail-landscape')
      : const Key('cinematic-dual-rail-portrait');

  @override
  Widget build(BuildContext context) {
    return CinematicRail(
      key: _railKey,
      items: items,
      orientation: orientation,
      onItemTap: onItemTap,
      onItemFocus: onItemFocus,
    );
  }
}
