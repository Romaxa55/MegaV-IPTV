import 'package:flutter/material.dart' hide Chip;

import '../../../core/ui/atoms/atoms.dart';

/// Cinematic section title — thin wrapper over the [SectionTitle] atom.
/// Forwards label / italic em / count / onMoreTap.
///
/// Maps to Requirements 5.1-5.5.
class CinematicSectionTitle extends StatelessWidget {
  const CinematicSectionTitle({super.key, required this.label, this.emphasis, this.count, this.onMoreTap});

  final String label;
  final String? emphasis;
  final int? count;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    return SectionTitle(title: label, emphasis: emphasis, count: count, onMore: onMoreTap);
  }
}
