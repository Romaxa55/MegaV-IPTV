import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../player/decoder_config.dart';
import '../player/player_manager.dart';
import '../playlist/models/channel.dart';
import '../playlist/models/epg_program.dart';
import '../playlist/models/now_playing.dart';

// --- API ---

final baseUrlProvider = StateProvider<String>((ref) => 'https://iptv.megav.app');

final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  final client = ApiClient(baseUrl: baseUrl);
  ref.onDispose(() => client.dispose());
  return client;
});

// --- Player ---

final playerManagerProvider = Provider<PlayerManager>((ref) {
  final manager = PlayerManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

final decoderConfigProvider = StateProvider<DecoderConfig>((ref) => const DecoderConfig());

// --- Channels & Categories (from Backend API) ---

/// All categories with channel counts.
final categoriesProvider = FutureProvider<List<({String name, int count})>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getCategories();
});

/// Paginated channels for a specific category.
/// Key format: "categoryName|offset|limit"
final categoryChannelsProvider = FutureProvider.family<({List<Channel> channels, int total}), String>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final parts = key.split('|');
  final categoryName = parts[0] == 'null' ? null : parts[0];
  final offset = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final limit = parts.length > 2 ? int.tryParse(parts[2]) ?? 20 : 20;

  return api.getChannels(category: categoryName, offset: offset, limit: limit);
});

String categoryChannelsKey(String? categoryName, {int offset = 0, int limit = 20}) {
  return '${categoryName ?? 'null'}|$offset|$limit';
}

/// Featured channels for HeroSection
final featuredChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getFeaturedChannels(limit: 8);
});

final selectedGroupProvider = StateProvider<String?>((ref) => null);
final currentChannelProvider = StateProvider<Channel?>((ref) => null);
final currentChannelIndexProvider = StateProvider<int>((ref) => -1);

// --- EPG Cinema Experience ---

/// Currently playing programs (capped at 60 to save memory)
final nowPlayingProvider = FutureProvider<List<NowPlayingItem>>((ref) async {
  ref.watch(epgProgressTickProvider);
  final api = ref.watch(apiClientProvider);
  final all = await api.getNowPlaying();
  if (all.length <= 60) return all;
  return all.sublist(0, 60);
});

/// Upcoming programs (next 3 hours)
final upcomingAllProvider = FutureProvider<List<NowPlayingItem>>((ref) async {
  ref.watch(epgProgressTickProvider);
  final api = ref.watch(apiClientProvider);
  return api.getUpcomingAll();
});

/// Featured now playing (hero carousel) with fallback to featured channels
final featuredNowPlayingProvider = FutureProvider<List<NowPlayingItem>>((ref) async {
  ref.watch(epgProgressTickProvider);
  final api = ref.watch(apiClientProvider);
  final featured = await api.getFeaturedNowPlaying(limit: 8);
  if (featured.isNotEmpty) return featured;

  var channels = await api.getFeaturedChannels(limit: 8);
  if (channels.isEmpty) {
    final result = await api.getChannels(limit: 8);
    channels = result.channels;
  }
  return channels.map((ch) => NowPlayingItem.fromChannel(ch)).toList();
});

/// Cinema categories built from now playing + upcoming data
final cinemaCategoriesProvider = FutureProvider<List<CinemaCategory>>((ref) async {
  final nowPlaying = await ref.watch(nowPlayingProvider.future);
  final upcoming = await ref.watch(upcomingAllProvider.future);

  const maxPerRow = 20;
  final categories = <CinemaCategory>[];

  final liveMovies = nowPlaying.where((i) => _isMovieCategory(i.program.category)).take(maxPerRow).toList();
  if (liveMovies.isNotEmpty) {
    categories.add(CinemaCategory(id: 'live-movies', name: '🔴  Фильмы в эфире', items: liveMovies));
  }

  final liveSport = nowPlaying.where((i) => _isSportCategory(i.program.category)).take(maxPerRow).toList();
  if (liveSport.isNotEmpty) {
    categories.add(CinemaCategory(id: 'live-sport', name: '⚽  Спорт в эфире', items: liveSport));
  }

  final liveShows = nowPlaying
      .where((i) => !_isMovieCategory(i.program.category) && !_isSportCategory(i.program.category))
      .take(maxPerRow)
      .toList();
  if (liveShows.isNotEmpty) {
    categories.add(CinemaCategory(id: 'live-shows', name: '📡  Сейчас в эфире', items: liveShows));
  }

  if (upcoming.isNotEmpty) {
    categories.add(CinemaCategory(id: 'upcoming', name: '⏰  Скоро начнётся', items: upcoming.take(maxPerRow).toList()));
  }

  return categories;
});

bool _isMovieCategory(String? cat) {
  if (cat == null) return false;
  final lower = cat.toLowerCase();
  return lower.contains('фильм') ||
      lower.contains('кино') ||
      lower.contains('movie') ||
      lower.contains('film') ||
      lower.contains('сериал') ||
      lower.contains('series') ||
      lower.contains('драма') ||
      lower.contains('комедия') ||
      lower.contains('боевик') ||
      lower.contains('триллер') ||
      lower.contains('ужас') ||
      lower.contains('фантаст');
}

bool _isSportCategory(String? cat) {
  if (cat == null) return false;
  final lower = cat.toLowerCase();
  return lower.contains('спорт') ||
      lower.contains('sport') ||
      lower.contains('футбол') ||
      lower.contains('хоккей') ||
      lower.contains('баскетбол') ||
      lower.contains('теннис');
}

class CinemaCategory {
  final String id;
  final String name;
  final List<NowPlayingItem> items;

  const CinemaCategory({required this.id, required this.name, required this.items});
}

// --- Per-channel EPG ---

final currentProgramProvider = FutureProvider.family<EpgProgram?, String>((ref, channelId) async {
  if (channelId.isEmpty) return null;
  final api = ref.watch(apiClientProvider);
  return api.getCurrentProgram(channelId);
});

final upcomingProgramsProvider = FutureProvider.family<List<EpgProgram>, String>((ref, channelId) async {
  if (channelId.isEmpty) return [];
  final api = ref.watch(apiClientProvider);
  return api.getUpcomingPrograms(channelId);
});

// --- UI Ticks ---

/// Ticks every minute to refresh progress bars and "now playing" data.
final epgProgressTickProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(minutes: 1), (i) => i);
});
