import 'package:flutter/material.dart' hide Chip;

import '../../../core/ui/atoms/atoms.dart';

/// Editorial home brand header — Brand mark + trailing StatusBar pill.
///
/// JSX reference (`atoms.jsx` Header):
/// ```jsx
/// const Header = (props) => (
///   <div className="mv-header">  /* align: center, justify: space-between */
///     <Brand />
///     <StatusBar {...props} />
///   </div>
/// );
/// ```
///
/// [scale] is retained for backward-compatibility with existing widget tests
/// that pass `scale: 1.6`. When supplied, it applies a [Transform.scale]
/// anchored at `Alignment.centerLeft` — matching the previous behaviour.
/// Default is `1.0` (no scaling), which matches the JSX where no scale
/// transform is applied to the editorial header Brand mark.
class EditorialBrandHeader extends StatelessWidget {
  const EditorialBrandHeader({super.key, this.scale = 1.0});

  /// Multiplier applied to the [Brand] atom via [Transform.scale].
  /// Default `1.0` = no scaling (JSX-accurate). Tests may pass `1.6` to
  /// verify the transform path.
  final double scale;

  @override
  Widget build(BuildContext context) {
    Widget brand = const Brand();
    if (scale != 1.0) {
      brand = Transform.scale(scale: scale, alignment: Alignment.centerLeft, child: brand);
    }

    return Row(
      key: const Key('editorial-brand-header'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [brand, const Spacer(), const StatusBar()],
    );
  }
}
