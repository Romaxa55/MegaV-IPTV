import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/playlist/models/epg_program.dart';
import 'epg_program_cell.dart';

/// Virtualised 2-axis programme grid for the EPG screen.
///
/// Renders one [ListView] (vertical, controlled by [verticalCtl]) where each
/// row is itself a horizontal [ListView] of [EpgProgramCell]s. The horizontal
/// axis is shared with [EpgTimeAxis] via [horizontalCtl] (Req 2.4, 5.1, 5.2).
///
/// ## Horizontal sync — single-master pattern
///
/// All inner ListViews use [NeverScrollableScrollPhysics] and are driven
/// purely as offset mirrors of [horizontalCtl]. The user can only pan
/// horizontally via focus-traversal driven `animateTo` / `jumpTo` calls on
/// the master controller from the parent screen — never by gesture on a
/// row directly. This matches the [EpgTimeAxis] contract (also
/// `NeverScrollable`) and avoids a real `LinkedScrollControllerGroup`
/// implementation, which would require an extra package.
///
/// Implementation:
/// - One private `ScrollController` per visible channel row, owned by
///   `_EpgTimeGridState` (`_rowControllers`). Lifecycle:
///   - `initState`: build N controllers from `widget.channels.length` and
///     subscribe `_syncRows` to the master.
///   - `didUpdateWidget`: if `channels.length` changed, dispose the old
///     controllers and rebuild. If the master `horizontalCtl` instance
///     itself changed, move the listener subscription.
///   - `dispose`: detach the listener and dispose every owned controller.
/// - `_syncRows`: reads `widget.horizontalCtl.offset` and forwards it via
///   `jumpTo` to every attached row controller, guarded by
///   `if (c.hasClients && c.offset != offset)` to prevent feedback loops
///   and unnecessary work.
/// - Vertical sync is trivial: [verticalCtl] is shared with
///   [EpgChannelRail] and provided by the caller.
///
/// ## Performance contract (Req 13.1, 13.2, 13.5)
///
/// - No GPU-blurring widgets in the build tree (perf-gate greps for the
///   forbidden APIs must stay at zero hits).
/// - No animated `width:` on any implicit-animation container; only
///   `decoration` may animate inside child cells.
/// - Virtualisation: outer + inner `ListView.builder` with
///   `cacheExtent: 1500`, `addAutomaticKeepAlives: true`,
///   `addRepaintBoundaries: true`, `clipBehavior: Clip.none`.
///
/// Maps to Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 13.1, 13.2, 13.5.
class EpgTimeGrid extends StatefulWidget {
  const EpgTimeGrid({
    super.key,
    required this.channels,
    required this.programmes,
    required this.windowFrom,
    required this.slotCount,
    required this.verticalCtl,
    required this.horizontalCtl,
    this.focusedChannelIndex,
    this.focusedProgrammeId,
    this.onCellFocusChanged,
    this.onCellTap,
  });

  /// Ordered channel list rendered top-to-bottom (Req 2.1).
  final List<Channel> channels;

  /// Programmes keyed by channel id. Each list MUST be ordered by
  /// `start` ascending (Req 2.2). Channels with no programmes render an
  /// empty horizontal row.
  final Map<int, List<EpgProgram>> programmes;

  /// Start of the visible time window (used by callers for slot maths,
  /// kept here to keep the public API symmetric with [EpgTimeAxis]).
  final DateTime windowFrom;

  /// Number of half-hour slots in the visible window (mirrors
  /// [EpgTimeAxis.slotCount]). Kept for API symmetry / future use.
  final int slotCount;

  /// Shared vertical scroll controller — co-owned with [EpgChannelRail]
  /// (Req 2.4). Caller owns the controller's lifecycle.
  final ScrollController verticalCtl;

  /// Master horizontal scroll controller — co-owned with [EpgTimeAxis]
  /// (Req 2.4). Every inner row mirrors this controller's offset. Caller
  /// owns the controller's lifecycle.
  final ScrollController horizontalCtl;

  /// Channel index currently focused by the parent, or `null` when focus
  /// is outside the grid (Req 2.5).
  final int? focusedChannelIndex;

  /// Programme id currently focused by the parent, or `null` when focus
  /// is outside the grid (Req 2.5).
  final int? focusedProgrammeId;

  /// Invoked when a cell gains focus. Reports `(channelIdx, programmeId)`
  /// (Req 2.6).
  final ValueChanged<({int channelIdx, int programmeId})>? onCellFocusChanged;

  /// Invoked on cell tap / select (Req 2.7).
  final ValueChanged<EpgProgram>? onCellTap;

  @override
  State<EpgTimeGrid> createState() => _EpgTimeGridState();
}

class _EpgTimeGridState extends State<EpgTimeGrid> {
  /// One private controller per channel row. All rows are pure
  /// offset-mirrors of [EpgTimeGrid.horizontalCtl] — see class doc for
  /// the sync rationale.
  late List<ScrollController> _rowControllers;

  @override
  void initState() {
    super.initState();
    _rowControllers = List.generate(widget.channels.length, (_) => ScrollController());
    widget.horizontalCtl.addListener(_syncRows);
  }

  @override
  void didUpdateWidget(covariant EpgTimeGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Re-attach the master listener if the controller instance changed.
    if (!identical(oldWidget.horizontalCtl, widget.horizontalCtl)) {
      oldWidget.horizontalCtl.removeListener(_syncRows);
      widget.horizontalCtl.addListener(_syncRows);
    }

    // Resize the row-controller pool when the channel set changes.
    if (oldWidget.channels.length != widget.channels.length) {
      for (final c in _rowControllers) {
        c.dispose();
      }
      _rowControllers = List.generate(widget.channels.length, (_) => ScrollController());
    }
  }

  @override
  void dispose() {
    widget.horizontalCtl.removeListener(_syncRows);
    for (final c in _rowControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Mirrors the master horizontal offset onto every attached row
  /// controller. Guards against detached controllers (`hasClients`) and
  /// no-op writes (`c.offset != offset`) to avoid listener feedback and
  /// wasted work.
  void _syncRows() {
    final offset = widget.horizontalCtl.offset;
    for (final c in _rowControllers) {
      if (c.hasClients && c.offset != offset) {
        c.jumpTo(offset);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('epg-time-grid'),
      child: ListView.builder(
        controller: widget.verticalCtl,
        scrollDirection: Axis.vertical,
        cacheExtent: 1500,
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
        clipBehavior: Clip.none,
        itemCount: widget.channels.length,
        itemBuilder: (ctx, i) {
          final channel = widget.channels[i];
          final rowProgrammes = widget.programmes[channel.id] ?? const <EpgProgram>[];
          return SizedBox(
            height: 88.h,
            child: ListView.builder(
              controller: _rowControllers[i],
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              cacheExtent: 1500,
              addAutomaticKeepAlives: true,
              addRepaintBoundaries: true,
              clipBehavior: Clip.none,
              itemCount: rowProgrammes.length,
              itemBuilder: (ctx, j) {
                final prog = rowProgrammes[j];
                final cellFocused = widget.focusedChannelIndex == i && widget.focusedProgrammeId == prog.id;
                return EpgProgramCell(
                  program: prog,
                  focused: cellFocused,
                  onTap: widget.onCellTap == null ? null : () => widget.onCellTap!(prog),
                  onFocusChange: widget.onCellFocusChanged == null
                      ? null
                      : () => widget.onCellFocusChanged!((channelIdx: i, programmeId: prog.id)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
