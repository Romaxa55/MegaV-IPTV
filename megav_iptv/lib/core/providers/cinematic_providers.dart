/// Derived view-data providers for `player-cinematic-redesign` (issue #8).
///
/// These providers are **derived** from existing state (NOT new state) per
/// Task 0.2 of the player-cinematic spec. The closed `player-overlay-state-
/// machine` defines `ControlsState` minimally; cinematic render trees source
/// view-data from these providers instead of extending `ControlsState`.
///
/// Adding new state-mutating providers here is forbidden — every provider
/// in this file must be a `Provider<T>` derived from existing sources via
/// `ref.watch(...)`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player/player_engine.dart';
import '../playlist/models/channel.dart';
import '../playlist/models/epg_program.dart';
import 'providers.dart';

/// Current EPG program for the active channel, or `null` if no channel.
///
/// Derived from `currentChannelProvider` + EPG data layer. For now we return
/// `null` until EPG-screen spec (#9) extends `lib/core/epg/*` with a
/// per-channel "now playing program" provider. This keeps the API stable for
/// player-cinematic rendering: render tree treats `null` as "no program data".
final currentProgramProvider = Provider<EpgProgram?>((ref) {
  // EPG data layer integration is owned by epg-screen (#9) — once that lands,
  // wire this provider through `currentChannelProvider` → epg lookup.
  // For now: no EPG data flowing through this seam → null.
  return null;
});

/// Adjacent channels (current ± N) for the channel deck render.
///
/// Derived from `featuredChannelsProvider` + `currentChannelProvider` —
/// returns up to 5 channels surrounding the current channel index. If
/// `featuredChannelsProvider` hasn't resolved yet, returns empty list (caller
/// renders empty deck without crash).
final adjacentChannelsProvider = Provider<List<Channel>>((ref) {
  final featured = ref.watch(featuredChannelsProvider).valueOrNull ?? const [];
  if (featured.isEmpty) return const [];

  final current = ref.watch(currentChannelProvider);
  if (current == null) {
    // No active channel — return first N for browsing.
    return featured.take(5).toList(growable: false);
  }

  final idx = featured.indexWhere((c) => c.id == current.id);
  if (idx < 0) return featured.take(5).toList(growable: false);

  final start = (idx - 2).clamp(0, featured.length);
  final end = (idx + 3).clamp(0, featured.length);
  return featured.sublist(start, end);
});

/// Human-readable bitrate label for the current playback session.
///
/// Currently returns `null` — `PlayerManager` does not yet expose a public
/// bitrate getter. When media engine adds it, derive via:
/// `ref.watch(playerManagerProvider).bitrateBps?.toLabel()`.
final playerBitrateLabelProvider = Provider<String?>((ref) {
  // Player engine bitrate API not yet exposed — null is the safe default;
  // CinematicTopBar elides bitrate row when null.
  return null;
});

/// Whether playback is currently in `PlayerState.playing`.
///
/// Derived from `playerManagerProvider.stateStream`. Defaults to `false`
/// while the stream hasn't emitted (initial loading).
final isPlayingProvider = StreamProvider<bool>((ref) {
  final manager = ref.watch(playerManagerProvider);
  return manager.stateStream.map((state) => state == PlayerState.playing);
});

/// Whether a video texture is currently active (i.e., decoder is producing
/// frames). Used by `KenBurnsBackdrop` to decide whether to show the static
/// fallback artwork.
///
/// Derived from `playerManagerProvider` — returns `true` when state is
/// `PlayerState.playing` (most reliable signal that a texture is active).
final hasActiveTextureProvider = StreamProvider<bool>((ref) {
  final manager = ref.watch(playerManagerProvider);
  return manager.stateStream.map((state) => state == PlayerState.playing || state == PlayerState.paused);
});
