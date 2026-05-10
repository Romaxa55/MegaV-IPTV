import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Editorial genre tabs bar — a horizontal [GenreTabs] strip flanked by
/// two `DecoratedBox` edge fades that taper into the page background.
///
/// **No `ShaderMask`** — the design handoff originally proposed a
/// shader-driven fade but Req 8.4 / 9.1 prohibit any shader effect on
/// the editorial home screen. Edge fades are therefore implemented as
/// two pure-paint [DecoratedBox] overlays carrying [LinearGradient]s
/// that animate from the opaque background to fully-transparent
/// background. Both overlays are wrapped in [IgnorePointer] so they do
/// not steal D-pad focus from the underlying [GenreTabs].
///
/// **Perf contract**: NO [BackdropFilter], NO [ShaderMask], NO blur
/// (Req 9.1, 9.2, 13.3).
///
/// Maps to Requirements 8.4, 8.5, 9.1, 9.2 and 13.1 of
/// `home-editorial-redesign`.
class EditorialGenreTabsBar extends ConsumerWidget {
  // ignore: prefer_const_constructors_in_immutables
  EditorialGenreTabsBar({Key? key, required this.tabs, required this.activeIndex, required this.onSelected})
    : super(key: key ?? const Key('editorial-genre-tabs'));

  /// Ordered list of genre tab labels.
  final List<String> tabs;

  /// Currently active tab index.
  final int activeIndex;

  /// Tap callback — receives the tapped tab's index.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.activePalette;
    final bg = palette.background;
    final transparent = bg.withAlpha(0);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        SizedBox(
          height: 56.h,
          child: GenreTabs(labels: tabs, activeIndex: activeIndex, onTabChanged: onSelected),
        ),
        // Left edge fade — opaque background → transparent.
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 32.w,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [bg, transparent],
                ),
              ),
            ),
          ),
        ),
        // Right edge fade — opaque background → transparent (mirrored).
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 32.w,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [bg, transparent],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
