import 'package:flutter/material.dart' hide Chip;

import '../../../core/playlist/models/now_playing.dart';
import 'editorial_bento_card.dart';

/// Editorial bento grid — flat 6-column layout with variable-span cells.
///
/// Layout primitive: a `LayoutBuilder` measures the available width,
/// computes a single column width from `(maxWidth − 5 × gap) / 6`, and
/// a fixed 220-lp row height. Each cell is wrapped in a `SizedBox`
/// sized to its `(cols, rows)` span and placed inside a `Wrap`.
///
/// This implementation does **not** introduce any new package
/// (`flutter_staggered_grid_view` is explicitly forbidden by Req 13.4).
/// `Wrap` flows cells row-by-row in declaration order — callers are
/// expected to order `cells` so larger spans appear early in a row.
///
/// **Perf contract**: NO `BackdropFilter`, NO `ShaderMask`, NO blur
/// (Req 9.1, 9.2, 13.3). The grid carries no scroll of its own — it
/// shrinks to its intrinsic height (Req 5.6); the embedding screen
/// owns the outer scroll view.
///
/// Maps to Requirements 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 9.1, 9.2, 9.7
/// and 13.1.
class EditorialBentoGrid extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  EditorialBentoGrid({Key? key, required this.cells, this.onItemTap, this.onItemFocus})
    : super(key: key ?? const Key('editorial-bento-grid'));

  /// Cell descriptors in flow order. The grid does not sort or reflow
  /// — the caller owns ordering.
  final List<EditorialBentoCell> cells;

  /// Tap dispatcher — invoked with the [EditorialBentoCell.item] of the
  /// activated card.
  final ValueChanged<NowPlayingItem>? onItemTap;

  /// Focus dispatcher — invoked with the focused item, or `null` when
  /// focus leaves the grid.
  final ValueChanged<NowPlayingItem?>? onItemFocus;

  static const double _gap = 16;
  static const double _rowHeight = 220;
  static const int _columns = 6;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Single column width — sized so 6 cols + 5 gaps fill the row.
        final double colWidth = (constraints.maxWidth - _gap * (_columns - 1)) / _columns;

        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final cell in cells)
              SizedBox(
                width: cell.cols * colWidth + (cell.cols - 1) * _gap,
                height: cell.rows * _rowHeight + (cell.rows - 1) * _gap,
                child: EditorialBentoCard(
                  cell: cell,
                  onTap: onItemTap == null ? null : () => onItemTap!(cell.item),
                  onFocusChange: onItemFocus == null
                      ? null
                      : (focused) {
                          onItemFocus!(focused ? cell.item : null);
                        },
                ),
              ),
          ],
        );
      },
    );
  }
}
