import '../../../core/playlist/models/channel.dart';
import '../../../core/playlist/models/epg_program.dart';

/// Sealed UI state for the EPG screen (Req 12.1, 12.4).
///
/// Mutated only via the screen's single `_transition(EpgUiState)` entry point;
/// `EpgReadyState.copyWith` produces transitional snapshots without aliasing.
sealed class EpgUiState {
  const EpgUiState();
}

/// Initial / refetch-in-progress state — no channels or programmes yet.
final class EpgLoadingState extends EpgUiState {
  const EpgLoadingState();
}

/// Loaded state with channels, programmes window, and current focus context.
final class EpgReadyState extends EpgUiState {
  /// Visible channels in the rail (already filtered/ordered by upstream).
  final List<Channel> channels;

  /// Programme rows keyed by `Channel.id`. Missing keys mean "no EPG for that
  /// channel in the current window".
  final Map<int, List<EpgProgram>> programmes;

  /// Inclusive lower bound of the currently fetched EPG window.
  final DateTime windowFrom;

  /// Exclusive upper bound of the currently fetched EPG window.
  final DateTime windowTo;

  /// Active client-side category filter; `null` means "all categories".
  final String? selectedCategory;

  /// Index into [channels] of the row that currently owns D-pad focus, or
  /// `null` when focus is outside the grid (header / category filter).
  final int? focusedChannelIndex;

  /// `EpgProgram.id` of the focused cell within the focused row, or `null`
  /// when the row has no programme highlighted yet.
  final int? focusedProgrammeId;

  const EpgReadyState({
    required this.channels,
    required this.programmes,
    required this.windowFrom,
    required this.windowTo,
    this.selectedCategory,
    this.focusedChannelIndex,
    this.focusedProgrammeId,
  });

  /// Returns a new [EpgReadyState] with the provided fields overridden.
  ///
  /// Nullable fields (`selectedCategory`, `focusedChannelIndex`,
  /// `focusedProgrammeId`) use a private sentinel so callers can distinguish
  /// "not provided — keep current" from "explicitly clear to null".
  EpgReadyState copyWith({
    List<Channel>? channels,
    Map<int, List<EpgProgram>>? programmes,
    DateTime? windowFrom,
    DateTime? windowTo,
    Object? selectedCategory = _sentinel,
    Object? focusedChannelIndex = _sentinel,
    Object? focusedProgrammeId = _sentinel,
  }) {
    return EpgReadyState(
      channels: channels ?? this.channels,
      programmes: programmes ?? this.programmes,
      windowFrom: windowFrom ?? this.windowFrom,
      windowTo: windowTo ?? this.windowTo,
      selectedCategory: identical(selectedCategory, _sentinel) ? this.selectedCategory : selectedCategory as String?,
      focusedChannelIndex: identical(focusedChannelIndex, _sentinel)
          ? this.focusedChannelIndex
          : focusedChannelIndex as int?,
      focusedProgrammeId: identical(focusedProgrammeId, _sentinel)
          ? this.focusedProgrammeId
          : focusedProgrammeId as int?,
    );
  }
}

/// Terminal failure state — repository / network / parse error surfaced to UI.
final class EpgErrorState extends EpgUiState {
  final Object error;
  final StackTrace stackTrace;

  const EpgErrorState({required this.error, required this.stackTrace});
}

/// Sentinel for `copyWith` to differentiate "argument omitted" from
/// "argument explicitly set to null". Module-private — never leaks to callers.
const Object _sentinel = Object();
