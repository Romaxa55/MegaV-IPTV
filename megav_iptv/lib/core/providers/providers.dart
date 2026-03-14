import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../epg/epg_database.dart';
import '../epg/epg_repository.dart';
import '../player/decoder_config.dart';
import '../player/player_manager.dart';
import '../playlist/models/channel.dart';
import '../playlist/models/epg_program.dart';
import '../playlist/playlist_repository.dart';
import '../thumbnail/thumbnail_service.dart';

final playerManagerProvider = Provider<PlayerManager>((ref) {
  final manager = PlayerManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

final decoderConfigProvider = StateProvider<DecoderConfig>((ref) => const DecoderConfig());

final playlistUrlProvider = StateProvider<String>((ref) => 'https://romaxa55.github.io/world_ip_tv/output/index.m3u');

// --- Playlist (DB-backed) ---

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  final repo = PlaylistRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// Triggers playlist download + DB save. Awaiting this means DB is ready.
final playlistLoadProvider = FutureProvider<void>((ref) async {
  final repo = ref.watch(playlistRepositoryProvider);
  final url = ref.watch(playlistUrlProvider);
  await repo.loadPlaylist(url);
});

/// All group names with channel counts, loaded from DB lazily.
final groupsProvider = FutureProvider<List<({String name, int count})>>((ref) async {
  await ref.watch(playlistLoadProvider.future);
  final repo = ref.watch(playlistRepositoryProvider);
  return repo.getGroups();
});

/// Paginated channels for a specific group.
/// Key: "groupName|offset|limit"
final groupChannelsProvider = FutureProvider.family<List<Channel>, String>((ref, key) async {
  await ref.watch(playlistLoadProvider.future);
  final parts = key.split('|');
  final groupName = parts[0];
  final offset = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final limit = parts.length > 2 ? int.tryParse(parts[2]) ?? 20 : 20;
  final repo = ref.watch(playlistRepositoryProvider);
  return repo.getChannelsByGroup(groupName, limit: limit, offset: offset);
});

/// Build group channels key for the provider.
String groupChannelsKey(String groupName, {int offset = 0, int limit = 20}) {
  return '$groupName|$offset|$limit';
}

/// Featured channels for HeroSection.
final featuredChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  await ref.watch(playlistLoadProvider.future);
  final repo = ref.watch(playlistRepositoryProvider);
  return repo.getFeaturedChannels(limit: 8);
});

/// Total channel count.
final totalChannelCountProvider = FutureProvider<int>((ref) async {
  await ref.watch(playlistLoadProvider.future);
  final repo = ref.watch(playlistRepositoryProvider);
  return repo.getTotalChannelCount();
});

final selectedGroupProvider = StateProvider<String?>((ref) => null);
final currentChannelProvider = StateProvider<Channel?>((ref) => null);
final currentChannelIndexProvider = StateProvider<int>((ref) => -1);

// --- EPG ---

final epgRepositoryProvider = Provider<EpgRepository>((ref) {
  final repo = EpgRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});

final epgSourceUrlProvider = StateProvider<String>((ref) => 'https://iptvx.one/epg/epg.xml.gz');

final epgRefreshProvider = FutureProvider<void>((ref) async {
  final repo = ref.watch(epgRepositoryProvider);
  final url = ref.watch(epgSourceUrlProvider);
  repo.sourceUrl = url;
  await repo.refresh();
  repo.startPeriodicRefresh();
});

/// Build EPG lookup key: "tvgId|channelName". Either part may be empty.
String epgKey({String? tvgId, required String channelName}) {
  return '${tvgId ?? ''}|$channelName';
}

/// Caches resolved EPG channel IDs to avoid repeated DB queries.
final _resolvedEpgIdProvider = FutureProvider.family<String?, String>((ref, key) async {
  ref.watch(epgRefreshProvider);
  final repo = ref.watch(epgRepositoryProvider);
  final parts = key.split('|');
  final tvgId = parts[0].isNotEmpty ? parts[0] : null;
  final channelName = parts.length > 1 ? parts[1] : null;
  return repo.resolveChannelId(tvgId: tvgId, channelName: channelName);
});

final currentProgramProvider = FutureProvider.family<EpgProgram?, String>((ref, key) async {
  final resolvedId = await ref.watch(_resolvedEpgIdProvider(key).future);
  if (resolvedId == null) return null;
  final repo = ref.watch(epgRepositoryProvider);
  return repo.getCurrentProgram(resolvedId);
});

final nextProgramProvider = FutureProvider.family<EpgProgram?, String>((ref, key) async {
  final resolvedId = await ref.watch(_resolvedEpgIdProvider(key).future);
  if (resolvedId == null) return null;
  final repo = ref.watch(epgRepositoryProvider);
  return repo.getNextProgram(resolvedId);
});

final epgLastUpdatedProvider = FutureProvider<DateTime?>((ref) async {
  ref.watch(epgRefreshProvider);
  final repo = ref.watch(epgRepositoryProvider);
  return repo.getLastUpdated();
});

// --- Thumbnails ---

final epgDatabaseProvider = Provider<EpgDatabase>((ref) {
  final repo = ref.watch(epgRepositoryProvider);
  return repo.database;
});

final thumbnailServiceProvider = Provider<ThumbnailService>((ref) {
  final db = ref.watch(epgDatabaseProvider);
  final service = ThumbnailService(epgDb: db);
  ref.onDispose(() => service.dispose());
  return service;
});

final channelThumbnailProvider = FutureProvider.family<ThumbnailResult?, Channel>((ref, channel) async {
  final service = ref.watch(thumbnailServiceProvider);
  return service.requestThumbnail(channel);
});
