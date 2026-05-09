import 'package:flutter/widgets.dart';

import '../../../core/playlist/models/now_playing.dart';

/// Arguments passed when navigating to `DetailScreen`. Immutable.
///
/// Maps to design.md §1.
@immutable
class DetailArgs {
  const DetailArgs({required this.channelId, this.preloadedNowPlaying, this.posterImageProvider});

  /// Channel ID owning this detail page.
  final int channelId;

  /// Optional preloaded NowPlayingItem so detail screen can render
  /// instantly without re-fetching.
  final NowPlayingItem? preloadedNowPlaying;

  /// Optional ImageProvider for poster (used when navigating from a card
  /// that already has the image loaded — saves a re-fetch).
  final ImageProvider? posterImageProvider;
}
