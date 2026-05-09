import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/providers/providers.dart';

/// Returns up to 8 sibling channels in the same `groupTitle`, excluding
/// the channel with [channelId] itself.
///
/// Uses `featuredChannelsProvider` (`FutureProvider<List<Channel>>`) as the
/// source. If still loading or empty, returns empty list — caller renders
/// empty rail without crash.
///
/// Maps to design.md §8 (Req 7.7, 8.6).
final relatedChannelsProvider = Provider.family<List<Channel>, int>((ref, channelId) {
  final featured = ref.watch(featuredChannelsProvider).valueOrNull ?? const <Channel>[];
  if (featured.isEmpty) return const <Channel>[];

  // Find the source channel
  final source = featured.cast<Channel?>().firstWhere((c) => c?.id == channelId, orElse: () => null);
  if (source == null) return const <Channel>[];

  // Filter siblings by groupTitle, exclude self
  return featured.where((c) => c.id != channelId && c.groupTitle == source.groupTitle).take(8).toList(growable: false);
});

/// Cast list for the channel detail page. Currently a stub returning empty
/// list — no metadata source available in current data layer. Future
/// enhancement: wire to a TMDB/external metadata lookup or extended EPG.
///
/// Maps to design.md §8 (Req 6.6).
final castListProvider = Provider.family<List<String>, int>((ref, channelId) {
  // Stub: no cast metadata source available yet.
  return const <String>[];
});
