import '../../../core/playlist/models/channel.dart';

/// Sealed UI state for the search screen.
///
/// Each subclass represents a single, immutable state. The `query` getter is
/// the canonical visible query string in the search bar — it must be derivable
/// from every state so widgets can render the input field consistently.
sealed class SearchUiState {
  const SearchUiState();

  /// Current search query that the UI should display.
  String get query;
}

/// No query has been entered yet. Initial / cleared state.
class Idle extends SearchUiState {
  const Idle();

  @override
  String get query => '';
}

/// A query is in flight; results have not yet arrived.
class Loading extends SearchUiState {
  @override
  final String query;

  const Loading(this.query);
}

/// Backend returned zero matches for [query].
class Empty extends SearchUiState {
  @override
  final String query;

  const Empty(this.query);
}

/// Network or backend failure for [lastQuery].
///
/// Renamed from `Error` to avoid collision with `dart:core`'s [Error] type.
class SearchError extends SearchUiState {
  final String message;
  final String lastQuery;

  const SearchError({required this.message, required this.lastQuery});

  @override
  String get query => lastQuery;
}

/// Successful results page (initial or accumulated after pagination).
class Results extends SearchUiState {
  final List<Channel> items;
  final int total;
  @override
  final String query;
  final bool hasMore;

  const Results({required this.items, required this.total, required this.query, required this.hasMore});
}
