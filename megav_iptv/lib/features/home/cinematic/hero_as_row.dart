// home-unified-grid-scroll spec — Wave 5
//
// Stateless обёртка над hero content для использования в роли row-0
// внутри [UnifiedHomeGridScroller]. Фиксирует высоту hero в
// [GridTokens.heroRowHeightDp] и не добавляет никакой focus / state
// логики — это чисто layout-обёртка.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../widgets/_grid_tokens.dart';

/// Hero как row-0 для `UnifiedHomeGridScroller`. Принимает произвольный
/// `child` (обычно `CinematicHeroBlock`) и оборачивает его в `SizedBox`
/// ровно `GridTokens.heroRowHeightDp` высотой.
///
/// В отличие от прежнего `HeroTileMorph`, не делает morph и не имеет
/// геометрической анимации — hero просто едет вверх/вниз вместе с
/// остальным гридом через родительский `ScrollController`.
///
/// Требования: 1.3, 5.1, 5.3, 5.5.
class HeroAsRow extends StatelessWidget {
  const HeroAsRow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: GridTokens.heroRowHeightDp.h, width: double.infinity, child: child);
  }
}
