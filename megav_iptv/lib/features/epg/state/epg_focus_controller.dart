import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../core/playlist/models/epg_program.dart';
import 'epg_screen_state.dart';

/// Pure D-pad focus controller for the EPG grid (Req 9).
///
/// This is a **pure Dart class** — it owns no widgets, no Riverpod providers,
/// and never reaches into other features' widget trees. In particular, per
/// Req 1.4 it MUST NOT call methods on `lib/features/player/widgets/epg_overlay.dart`
/// directly. Routing decisions (open the player, swap to overlay, etc.) are
/// surfaced via the [onSelect] callback the caller wires up.
///
/// Lifecycle:
/// - The caller creates one instance per `EpgScreen` and is responsible for
///   keeping it alive while the widget is mounted.
/// - The caller MUST invoke [dispose] from `State.dispose()` to cancel the
///   internal focus-stabilisation [Timer]; the class itself does not perform
///   any `mounted` checks.
///
/// State updates flow through [onTransition], which the caller routes into
/// the screen's single `_transition(EpgUiState)` entry point so all UI state
/// mutations stay funnelled through one path (Req 12.3, 12.4).
class EpgFocusController {
  EpgFocusController({
    required this.channelFocusNodes,
    required this.programmeFocusNodes,
    required this.verticalCtl,
    required this.horizontalCtl,
    this.onTransition,
    this.onSelect,
  });

  /// Per-row [FocusNode]s for the channel rail, keyed by channel index.
  final Map<int, FocusNode> channelFocusNodes;

  /// Per-cell [FocusNode]s for programme cells, keyed by `EpgProgram.id`.
  final Map<int, FocusNode> programmeFocusNodes;

  /// Vertical scroll controller for the channel/programme grid.
  final ScrollController verticalCtl;

  /// Horizontal scroll controller for the timeline (programme columns).
  final ScrollController horizontalCtl;

  /// Emitted when the controller derives a new [EpgReadyState] from a key
  /// event (row/column move, snap-to-live). Caller forwards this into the
  /// screen's `_transition` so all state changes go through one funnel.
  final ValueChanged<EpgReadyState>? onTransition;

  /// Emitted when the user presses OK/Enter on a focused programme cell.
  /// Caller decides routing (open player, show details overlay, etc.).
  /// Per Req 1.4, this controller MUST NOT call into `epg_overlay.dart`
  /// directly — routing belongs to the caller.
  final ValueChanged<EpgProgram>? onSelect;

  Timer? _focusDebounceTimer;
  bool _inFlight = false;

  /// Row height in logical pixels — kept in sync with `EpgGrid` row geometry.
  static const double _rowHeight = 88.0;

  /// Width of one 30-minute timeline slot — kept in sync with `EpgGrid`.
  static const double _slotWidth = 180.0;

  /// Distance from a viewport edge that triggers an `animateTo` nudge
  /// (Req 9.4: "if cell is within 80 px of edge").
  static const double _edgeThreshold = 80.0;

  /// Animation parameters for the viewport nudge.
  static const Duration _scrollDuration = Duration(milliseconds: 220);
  static const Curve _scrollCurve = Curves.easeOutCubic;

  /// Debounce window for `onFocusStabilised` (Req 9.5).
  static const Duration _focusStabilisationDelay = Duration(milliseconds: 400);

  /// Handles a key event delivered by Flutter focus traversal.
  ///
  /// - Arrow Up/Down → move row, snap column to live programme of new row
  ///   via [_snapToLive] (Req 9.1, 9.2).
  /// - Arrow Left/Right → move within current programme row (Req 9.1).
  /// - OK/Select/Enter → [_handleSelect] (Req 9.3, guarded against double-fire
  ///   by `_inFlight`, Req 9.6).
  KeyEventResult onKey(FocusNode node, KeyEvent event, EpgReadyState state) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) return _moveRow(-1, state);
    if (key == LogicalKeyboardKey.arrowDown) return _moveRow(1, state);
    if (key == LogicalKeyboardKey.arrowLeft) return _moveColumn(-1, state);
    if (key == LogicalKeyboardKey.arrowRight) return _moveColumn(1, state);
    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _handleSelect(state);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Moves the focused row by [delta] (clamped to channel range) and snaps
  /// the column to the live programme of the new row (Req 9.2).
  KeyEventResult _moveRow(int delta, EpgReadyState state) {
    if (state.channels.isEmpty) return KeyEventResult.ignored;
    final cur = state.focusedChannelIndex ?? 0;
    final newRow = (cur + delta).clamp(0, state.channels.length - 1);
    if (newRow == cur) return KeyEventResult.ignored;
    _snapToLive(newRow, state);
    return KeyEventResult.handled;
  }

  /// Moves the focused programme within the current row by [delta].
  KeyEventResult _moveColumn(int delta, EpgReadyState state) {
    if (state.channels.isEmpty) return KeyEventResult.ignored;
    final rowIdx = state.focusedChannelIndex ?? 0;
    if (rowIdx < 0 || rowIdx >= state.channels.length) {
      return KeyEventResult.ignored;
    }
    final progs = state.programmes[state.channels[rowIdx].id] ?? const [];
    if (progs.isEmpty) return KeyEventResult.ignored;
    final curId = state.focusedProgrammeId;
    final curIdx = curId == null ? -1 : progs.indexWhere((p) => p.id == curId);
    final base = curIdx < 0 ? 0 : curIdx;
    final newIdx = (base + delta).clamp(0, progs.length - 1);
    if (newIdx == base && curIdx >= 0) return KeyEventResult.ignored;
    final newProg = progs[newIdx];
    onTransition?.call(state.copyWith(focusedChannelIndex: rowIdx, focusedProgrammeId: newProg.id));
    _ensureFocusInViewport(rowIdx, newIdx, state);
    return KeyEventResult.handled;
  }

  /// Snaps the focused programme of [newRowIdx] to the live programme
  /// (or the first programme if none is live) — Req 9.2.
  void _snapToLive(int newRowIdx, EpgReadyState state) {
    if (newRowIdx < 0 || newRowIdx >= state.channels.length) return;
    final progs = state.programmes[state.channels[newRowIdx].id] ?? const [];
    if (progs.isEmpty) {
      onTransition?.call(state.copyWith(focusedChannelIndex: newRowIdx, focusedProgrammeId: null));
      _ensureFocusInViewport(newRowIdx, 0, state);
      return;
    }
    final liveIdx = progs.indexWhere((p) => p.isNow);
    final targetIdx = liveIdx >= 0 ? liveIdx : 0;
    final target = progs[targetIdx];
    onTransition?.call(state.copyWith(focusedChannelIndex: newRowIdx, focusedProgrammeId: target.id));
    _ensureFocusInViewport(newRowIdx, targetIdx, state);
  }

  /// Nudges the vertical and horizontal scroll views so that the focused
  /// cell is not within [_edgeThreshold] pixels of a viewport edge (Req 9.4).
  ///
  /// Cell vertical position is derived from `channelIdx * rowHeight`.
  /// Cell horizontal position is summed from per-programme widths, where each
  /// programme occupies `ceil(durationMinutes / 30) * slotWidth` pixels — this
  /// matches the timeline layout used by `EpgGrid`.
  void _ensureFocusInViewport(int channelIdx, int programmeIdx, EpgReadyState state) {
    // Vertical axis — channel row.
    if (verticalCtl.hasClients) {
      final pos = verticalCtl.position;
      final cellTop = channelIdx * _rowHeight;
      final cellBottom = cellTop + _rowHeight;
      final viewTop = pos.pixels;
      final viewBottom = viewTop + pos.viewportDimension;
      double? targetV;
      if (cellBottom > viewBottom - _edgeThreshold) {
        targetV = (cellBottom - pos.viewportDimension + _edgeThreshold).clamp(0.0, pos.maxScrollExtent);
      } else if (cellTop < viewTop + _edgeThreshold) {
        targetV = (cellTop - _edgeThreshold).clamp(0.0, pos.maxScrollExtent);
      }
      if (targetV != null && targetV != pos.pixels) {
        verticalCtl.animateTo(targetV, duration: _scrollDuration, curve: _scrollCurve);
      }
    }

    // Horizontal axis — programme cell on the timeline.
    if (horizontalCtl.hasClients) {
      final pos = horizontalCtl.position;
      final progs = (channelIdx >= 0 && channelIdx < state.channels.length)
          ? (state.programmes[state.channels[channelIdx].id] ?? const [])
          : const <EpgProgram>[];
      double xStart = 0;
      for (var i = 0; i < programmeIdx && i < progs.length; i++) {
        xStart += _slotsFor(progs[i]) * _slotWidth;
      }
      final cellWidth = (programmeIdx >= 0 && programmeIdx < progs.length)
          ? _slotsFor(progs[programmeIdx]) * _slotWidth
          : _slotWidth;
      final xEnd = xStart + cellWidth;
      final viewLeft = pos.pixels;
      final viewRight = viewLeft + pos.viewportDimension;
      double? targetH;
      if (xEnd > viewRight - _edgeThreshold) {
        targetH = (xEnd - pos.viewportDimension + _edgeThreshold).clamp(0.0, pos.maxScrollExtent);
      } else if (xStart < viewLeft + _edgeThreshold) {
        targetH = (xStart - _edgeThreshold).clamp(0.0, pos.maxScrollExtent);
      }
      if (targetH != null && targetH != pos.pixels) {
        horizontalCtl.animateTo(targetH, duration: _scrollDuration, curve: _scrollCurve);
      }
    }
  }

  /// Number of 30-minute slots a programme occupies on the timeline.
  /// Always at least 1 (covers zero-/sub-minute programmes defensively).
  double _slotsFor(EpgProgram prog) {
    final minutes = prog.duration.inMinutes;
    if (minutes <= 0) return 1;
    return (minutes / 30.0).ceil().toDouble();
  }

  /// Debounces a heavy callback (e.g. EPG window prefetch) until D-pad focus
  /// has been stable for [_focusStabilisationDelay] (Req 9.5).
  ///
  /// The class does not perform `mounted` checks — the caller must guard
  /// [heavy] itself or ensure the controller is disposed before the widget
  /// goes away (see [dispose]).
  void onFocusStabilised(VoidCallback heavy) {
    _focusDebounceTimer?.cancel();
    _focusDebounceTimer = Timer(_focusStabilisationDelay, heavy);
  }

  /// Handles OK/Enter on the focused programme cell (Req 9.3, 9.6).
  ///
  /// Re-entry is blocked by `_inFlight` so that holding Enter or rapid double
  /// presses don't fire [onSelect] multiple times before the caller routes
  /// the event.
  Future<void> _handleSelect(EpgReadyState state) async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final rowIdx = state.focusedChannelIndex;
      final progId = state.focusedProgrammeId;
      if (rowIdx == null || progId == null) return;
      if (rowIdx < 0 || rowIdx >= state.channels.length) return;
      final progs = state.programmes[state.channels[rowIdx].id] ?? const [];
      if (progs.isEmpty) return;
      final idx = progs.indexWhere((p) => p.id == progId);
      if (idx < 0) return;
      onSelect?.call(progs[idx]);
    } finally {
      _inFlight = false;
    }
  }

  /// Cancels the focus-stabilisation timer. MUST be called from the owning
  /// widget's `State.dispose()` to avoid a leaked [Timer] firing after the
  /// widget tree is gone.
  void dispose() {
    _focusDebounceTimer?.cancel();
    _focusDebounceTimer = null;
  }
}
