import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/playlist/models/channel.dart';
import '../../../core/providers/providers.dart';
import '../widgets/keyboard_key.dart';
import '../widgets/search_state.dart';

/// StateNotifier that owns the search screen's UI state machine.
///
/// Single mutation point is [_transition]; every callback funnels through it
/// so we have one place to drop state changes after [dispose] (mounted check)
/// and to reason about transitions when reading the file.
///
/// API call delegates to [ApiClient.searchChannels] (added in task 9.1), which
/// returns a `({List<Channel> channels, int total})` record. The controller
/// stores them under its internal naming (`_items`).
///
/// Maps to Req 1.x (debounce), 6.x (state machine), 7.x (pagination), 10.x
/// (lifecycle) of the `search-screen` spec.
class SearchController extends StateNotifier<SearchUiState> {
  SearchController(this._api) : super(const Idle());

  final ApiClient _api;

  static const Duration _debounceDuration = Duration(milliseconds: 350);
  static const int _pageSize = 20;

  Timer? _debounce;
  bool _inFlight = false;
  String _query = '';
  int _offset = 0;
  int _total = 0;
  List<Channel> _items = const [];

  /// Process one keypress from the on-screen keyboard.
  ///
  /// `LocaleToggle` is a layout-only signal handled by the keyboard widget
  /// itself; the controller intentionally ignores it (no query mutation, no
  /// debounce reset).
  void onKeyPressed(KeyboardKey key) {
    switch (key) {
      case Char(:final glyph):
        _query += glyph;
      case Space():
        _query += ' ';
      case Backspace():
        if (_query.isEmpty) return;
        _query = _query.substring(0, _query.length - 1);
      case LocaleToggle():
        return;
    }
    _scheduleSearch();
  }

  /// Public retry hook for the error-state UI (Req 6.6).
  ///
  /// Forwards to the private [_scheduleSearch] so `_ErrorRetry` (in
  /// `widgets/search_results_grid.dart`) can re-enqueue the current `_query`
  /// with the standard 350 ms debounce, without exposing `_scheduleSearch`
  /// itself to the rest of the codebase.
  void retry() => _scheduleSearch();

  void _scheduleSearch() {
    _debounce?.cancel();
    if (_query.isEmpty) {
      _transition(const Idle());
      return;
    }
    _debounce = Timer(_debounceDuration, _runSearch);
  }

  Future<void> _runSearch() async {
    if (_inFlight) return;
    _inFlight = true;
    final q = _query;
    _transition(Loading(q));
    try {
      final result = await _api.searchChannels(query: q, limit: _pageSize, offset: 0);
      _items = result.channels;
      _total = result.total;
      _offset = result.channels.length;
      if (result.channels.isEmpty) {
        _transition(Empty(q));
      } else {
        _transition(Results(items: _items, total: _total, query: q, hasMore: _offset < _total));
      }
    } catch (e) {
      _transition(SearchError(message: e.toString(), lastQuery: q));
    } finally {
      _inFlight = false;
    }
  }

  /// Append the next page of results. No-op while a request is in flight or
  /// once we have already consumed every server-side row (`_offset >= _total`).
  /// On failure, current items remain on screen (Req 7.5).
  Future<void> requestNextPage() async {
    if (_inFlight || _offset >= _total) return;
    _inFlight = true;
    try {
      final result = await _api.searchChannels(query: _query, limit: _pageSize, offset: _offset);
      _items = [..._items, ...result.channels];
      _total = result.total;
      _offset += result.channels.length;
      _transition(Results(items: _items, total: _total, query: _query, hasMore: _offset < _total));
    } catch (_) {
      // Pagination failure must not clobber the visible results — keep state.
    } finally {
      _inFlight = false;
    }
  }

  void _transition(SearchUiState next) {
    if (!mounted) return;
    state = next;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

/// Auto-disposed: when the search screen is popped, the controller's debounce
/// timer is cancelled and any in-flight Future is allowed to complete without
/// touching state (`_transition` no-ops once `mounted == false`).
final searchControllerProvider = StateNotifierProvider.autoDispose<SearchController, SearchUiState>(
  (ref) => SearchController(ref.watch(apiClientProvider)),
);
