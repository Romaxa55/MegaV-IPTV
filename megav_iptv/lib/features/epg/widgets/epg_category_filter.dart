import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Category filter strip wrapping the [GenreTabs] atom with edge-fade
/// overlays.
///
/// Renders the list of available EPG programme categories as horizontal
/// tabs (with a synthesised «Все» tab prepended at index 0), and emits a
/// nullable category string to the caller — `null` for «Все», otherwise
/// the selected category — which the caller is expected to apply
/// **client-side** to the loaded `EpgProgram` list (Req 8.2 — no
/// re-fetch).
///
/// Edge-fade overlays on the left and right are pure
/// `DecoratedBox(LinearGradient)` layers placed inside `Positioned` slots
/// (Req 8.3). `ShaderMask` is forbidden by the spec and the
/// flutter-tv-perf.md performance contract (Req 13.1) — gradient overlays
/// avoid the saveLayer cost that `ShaderMask` would impose every frame.
/// Each fade is wrapped in [IgnorePointer] so taps fall through to the
/// underlying `GenreTabs` row.
///
/// The [GenreTabs] atom itself is not modified (Req 8.4) — this widget is
/// purely a composition layer that adapts the atom's index-based API
/// (`int activeIndex`, `ValueChanged<int> onTabChanged`) to the
/// category-string API expected by the EPG screen.
///
/// Performance contract (Req 13.1):
/// - No `BackdropFilter` / `ShaderMask` / `ImageFilter.blur` anywhere in
///   the build tree.
/// - No animated `width:` — the fade slots are static `width: 32.w`.
/// - No `BoxShadow` on the fade layers.
///
/// Maps to Requirements 8.1, 8.2, 8.3, 8.4, 8.5, 13.1.
class EpgCategoryFilter extends StatelessWidget {
  const EpgCategoryFilter({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  /// Categories surfaced from the loaded `EpgProgram` set. The «Все»
  /// (all) sentinel is prepended internally — callers pass only the
  /// real category names.
  final List<String> categories;

  /// Currently selected category, or `null` to indicate «Все» (no
  /// filter applied).
  final String? selectedCategory;

  /// Invoked with the newly-selected category, or `null` when the user
  /// taps the «Все» tab. The caller applies the filter client-side
  /// against the in-memory programme list (Req 8.2).
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final tabs = <String>['Все', ...categories];

    // Map nullable selection → atom's index. «Все» is index 0; missing
    // categories also fall back to «Все» so the UI never desynchronises
    // from a stale `selectedCategory` after the category list shrinks.
    int activeIndex = 0;
    if (selectedCategory != null) {
      final i = categories.indexOf(selectedCategory!);
      if (i >= 0) activeIndex = i + 1;
    }

    final bg = AppColors.background;

    return SizedBox(
      key: const Key('epg-category-filter'),
      height: 56.h,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // GenreTabs atom — unmodified (Req 8.4).
          Positioned.fill(
            child: GenreTabs(
              labels: tabs,
              activeIndex: activeIndex,
              onTabChanged: (i) {
                onCategorySelected(i == 0 ? null : categories[i - 1]);
              },
            ),
          ),
          // Left edge fade — opaque background → transparent (Req 8.3).
          // IgnorePointer keeps taps reaching the GenreTabs row.
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
                    colors: [bg, bg.withAlpha(0)],
                  ),
                ),
              ),
            ),
          ),
          // Right edge fade — mirrored: transparent → opaque background.
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 32.w,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [bg.withAlpha(0), bg],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
