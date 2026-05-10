import 'package:flutter/material.dart' hide Chip;

import '../../../core/ui/atoms/atoms.dart';

/// Editorial section title — thin wrapper over the design-system
/// [SectionTitle] atom. Forwards the upright `label`, the italic
/// emphasis fragment, the optional count badge and the optional
/// «more →» tap callback to the underlying atom.
///
/// The atom itself owns the italic styling (via [MegaVTextStyles])
/// and the trailing «more →» button rendering — this wrapper exists
/// purely to scope the editorial home screen's section headings under
/// a stable widget type and a deterministic root [Key], which the
/// home screen smoke test relies on.
///
/// **Perf contract**: NO [BackdropFilter], NO [ShaderMask], NO blur
/// (Req 9.1, 9.2).
///
/// Maps to Requirements 8.1, 8.2, 8.3, 8.5, 9.1, 9.2 of
/// `home-editorial-redesign`.
class EditorialSectionTitle extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  EditorialSectionTitle({Key? key, required this.label, required this.emphasis, this.count, this.onMoreTap})
    : super(key: key ?? Key('editorial-section-title-$label'));

  /// Upright section heading (e.g. `Кино`).
  final String label;

  /// Italic emphasis fragment appended after the label (e.g. `без расписания`).
  final String emphasis;

  /// Optional count rendered as a small ghost chip by the atom.
  final int? count;

  /// Optional «more →» tap callback. When non-null, the atom renders a
  /// trailing ghost button.
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    return SectionTitle(title: label, emphasis: emphasis, count: count, onMore: onMoreTap);
  }
}
