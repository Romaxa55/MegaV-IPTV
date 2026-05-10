import 'package:flutter/material.dart' hide Chip;

import '../../../core/ui/atoms/atoms.dart';

/// Editorial home brand header — left-aligned scaled `Brand` mark and a
/// trailing `StatusBar` pill, separated by a flexible spacer.
///
/// Used as the topmost row of `EditorialHomeScreen`. The `scale` parameter
/// uplifts the visual weight of the brand mark to match the print-magazine
/// editorial display tier (default 1.4×). Both atoms come from the design-
/// system atoms barrel (`core/ui/atoms/atoms.dart`).
///
/// Maps to `home-editorial-redesign` Requirement 13.1 (root `Key`).
class EditorialBrandHeader extends StatelessWidget {
  const EditorialBrandHeader({super.key, this.scale = 1.4});

  /// Multiplier applied to the `Brand` atom via `Transform.scale`. The
  /// transform anchors at `Alignment.centerLeft` so the scaled mark grows
  /// to the right and does not push the wordmark off-screen.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('editorial-brand-header'),
      children: [
        Transform.scale(scale: scale, alignment: Alignment.centerLeft, child: const Brand()),
        const Spacer(),
        const StatusBar(),
      ],
    );
  }
}
