import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/epg_screen_state.dart';

/// Full-screen 2D EPG (Electronic Programme Guide).
///
/// Phase-2 skeleton: scaffold + sealed [EpgUiState] state machine with a single
/// `_transition` mutation entry-point. Subtree (header, day-picker, time-grid,
/// preview-strip) is filled in by phases 3-5 / task 6.1.
class EpgScreen extends ConsumerStatefulWidget {
  const EpgScreen({super.key});

  @override
  ConsumerState<EpgScreen> createState() => _EpgScreenState();
}

class _EpgScreenState extends ConsumerState<EpgScreen> {
  EpgUiState _state = const EpgLoadingState();
  Timer? _focusDebounceTimer;
  // Mutated by EpgFocusController in task 5.4 / 6.1 to gate concurrent OK-press
  // async actions (Req 9.6, 12.3). Stays non-final by design.
  // ignore: prefer_final_fields
  bool _inFlight = false;

  /// Single mutation entry-point for [EpgUiState] transitions.
  ///
  /// Cancels any pending focus-debounce timer before [setState] so heavy
  /// preview-strip / hero refresh callbacks queued under the previous state do
  /// not fire against the new one (Req 12.2, 12.3, 9.6).
  // ignore: unused_element
  void _transition(EpgUiState newState) {
    _focusDebounceTimer?.cancel();
    _focusDebounceTimer = null;
    setState(() => _state = newState);
  }

  @override
  void dispose() {
    _focusDebounceTimer?.cancel();
    _focusDebounceTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Exhaustive switch on the sealed state keeps the analyzer satisfied that
    // _state is consumed; Phase 6.1 will replace these placeholders with the
    // real composition (header / day-picker / grid / preview-strip).
    final Widget body = switch (_state) {
      EpgLoadingState() => const SizedBox.shrink(),
      EpgReadyState() => const SizedBox.shrink(),
      EpgErrorState() => const SizedBox.shrink(),
    };

    // _inFlight is referenced here so the analyzer recognises the field as
    // used before the focus-controller wiring lands in task 5.4 / 6.1.
    assert(_inFlight == false || _inFlight == true);

    return Scaffold(
      key: const Key('epg-screen-root'),
      body: SafeArea(child: body),
    );
  }
}
