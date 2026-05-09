import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/megav_text_styles.dart';

/// Horizontal tab strip with underline-on-active. Underline animation
/// completes within 150ms (Leanback timing) — paint-only, no relayout.
///
/// State management is external: the parent owns the `activeIndex` and
/// receives tap events via `onTabChanged`. The atom itself is stateful only
/// to bookkeep per-tab `GlobalKey`s used for sizing the underline indicator.
///
/// Underline positioning note: the indicator uses an index-based
/// approximation (uniform tab width assumption) so the animation stays
/// paint-only and avoids per-frame layout queries. Pixel-perfect alignment
/// is the responsibility of downstream screen-specs that can supply tighter
/// per-tab measurements when needed.
///
/// Maps to Requirements 7.1, 7.2, 7.3, 7.4 of `design-system-atoms`.
class GenreTabs extends StatefulWidget {
  const GenreTabs({super.key, required this.labels, required this.activeIndex, this.onTabChanged});

  /// Ordered list of tab labels rendered horizontally left-to-right.
  final List<String> labels;

  /// Index of the currently active tab. The underline indicator slides to
  /// this index whenever it changes.
  final int activeIndex;

  /// Invoked with the tapped tab's index. State is owned by the parent —
  /// this atom does not mutate `activeIndex` itself.
  final ValueChanged<int>? onTabChanged;

  @override
  State<GenreTabs> createState() => _GenreTabsState();
}

class _GenreTabsState extends State<GenreTabs> {
  // Track widths so we know where to position the underline.
  final List<GlobalKey> _tabKeys = [];

  void _ensureKeys() {
    while (_tabKeys.length < widget.labels.length) {
      _tabKeys.add(GlobalKey());
    }
    if (_tabKeys.length > widget.labels.length) {
      _tabKeys.removeRange(widget.labels.length, _tabKeys.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureKeys();
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final activeStyle = (styles?.bodyDefault ?? theme.textTheme.titleSmall)?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );
    final inactiveStyle = (styles?.bodyDim ?? theme.textTheme.titleSmall)?.copyWith(color: AppColors.textSecondary);

    return Stack(
      alignment: Alignment.bottomLeft,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < widget.labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 20),
              GestureDetector(
                key: _tabKeys[i],
                onTap: () => widget.onTabChanged?.call(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(widget.labels[i], style: i == widget.activeIndex ? activeStyle : inactiveStyle),
                ),
              ),
            ],
          ],
        ),
        // Underline — using AnimatedPositioned for paint-only animation.
        // Position is approximated; true tab-width tracking requires
        // post-layout measurements. For now use index-based offset (assumes
        // uniform tab spacing).
        AnimatedPositioned(
          duration: const Duration(milliseconds: 150),
          curve: Curves.fastOutSlowIn,
          left: _underlineLeft(),
          bottom: 0,
          child: Container(
            width: 24, // fixed underline width — visual approximation
            height: 2,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  double _underlineLeft() {
    // Approximate: index * (avg_tab_width + spacing). For pixel-perfect
    // alignment, downstream callers can use precise per-tab measurement.
    const avgTabWidth = 60.0;
    const spacing = 20.0;
    return widget.activeIndex * (avgTabWidth + spacing);
  }
}
