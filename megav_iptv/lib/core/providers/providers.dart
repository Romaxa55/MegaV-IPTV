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

final categoriesProvider = FutureProvider<List<({String name, int count})>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getCategories();
});

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

final featuredChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getFeaturedChannels(limit: 8);
});

final selectedGroupProvider = StateProvider<String?>((ref) => null);
final currentChannelProvider = StateProvider<Channel?>((ref) => null);
final currentChannelIndexProvider = StateProvider<int>((ref) => -1);

// --- EPG Cinema Experience ---

final nowPlayingProvider = FutureProvider<List<NowPlayingItem>>((ref) async {
  ref.watch(epgProgressTickProvider);
  final api = ref.watch(apiClientProvider);
  final all = await api.getNowPlaying();
  if (all.length <= 60) return all;
  return all.sublist(0, 60);
});

final upcomingAllProvider = FutureProvider<List<NowPlayingItem>>((ref) async {
  ref.watch(epgProgressTickProvider);
  final api = ref.watch(apiClientProvider);
  return api.getUpcomingAll();
});

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

final moviesNowPlayingProvider = FutureProvider<List<NowPlayingItem>>((ref) async {
  ref.watch(epgProgressTickProvider);
  final api = ref.watch(apiClientProvider);
  return api.getMoviesNowPlaying(limit: 20);
});

final cinemaCategoriesProvider = FutureProvider<List<CinemaCategory>>((ref) async {
  final movies = await ref.watch(moviesNowPlayingProvider.future);
  final nowPlaying = await ref.watch(nowPlayingProvider.future);
  final upcoming = await ref.watch(upcomingAllProvider.future);

  const maxPerRow = 20;
  final categories = <CinemaCategory>[];
  final seen = <int>{};

  List<NowPlayingItem> unique(Iterable<NowPlayingItem> items) {
    final result = <NowPlayingItem>[];
    for (final i in items) {
      if (seen.add(i.channelId)) result.add(i);
      if (result.length >= maxPerRow) break;
    }
    return result;
  }

  final liveMovies = unique(movies);
  if (liveMovies.isNotEmpty) {
    categories.add(CinemaCategory(id: 'live-movies', name: '🔴  Фильмы в эфире', items: liveMovies));
  }

  final liveSport = unique(nowPlaying.where((i) => _isSportCategory(i.program.category)));
  if (liveSport.isNotEmpty) {
    categories.add(CinemaCategory(id: 'live-sport', name: '⚽  Спорт в эфире', items: liveSport));
  }

  final liveKids = unique(nowPlaying.where((i) => _isKidsCategory(i.program.category)));
  if (liveKids.isNotEmpty) {
    categories.add(CinemaCategory(id: 'live-kids', name: '🧸  Детям', items: liveKids));
  }

  final liveDocs = unique(nowPlaying.where((i) => _isDocCategory(i.program.category)));
  if (liveDocs.isNotEmpty) {
    categories.add(CinemaCategory(id: 'live-docs', name: '🔬  Познавательное', items: liveDocs));
  }

  final liveOther = unique(
    nowPlaying.where(
      (i) =>
          !_isMovieCategory(i.program.category) &&
          !_isSportCategory(i.program.category) &&
          !_isKidsCategory(i.program.category) &&
          !_isDocCategory(i.program.category),
    ),
  );
  if (liveOther.isNotEmpty) {
    categories.add(CinemaCategory(id: 'live-other', name: '📡  Сейчас в эфире', items: liveOther));
  }

  if (upcoming.isNotEmpty) {
    final upcomingSeen = <int>{};
    final uniqueUpcoming = upcoming.where((i) => upcomingSeen.add(i.channelId)).take(maxPerRow).toList();
    if (uniqueUpcoming.isNotEmpty) {
      categories.add(CinemaCategory(id: 'upcoming', name: '⏰  Скоро начнётся', items: uniqueUpcoming));
    }
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
      lower.contains('фантаст') ||
      lower.contains('мелодрам') ||
      lower.contains('детектив') ||
      lower.contains('приключен');
}

bool _isSportCategory(String? cat) {
  if (cat == null) return false;
  final lower = cat.toLowerCase();
  return lower.contains('спорт') ||
      lower.contains('sport') ||
      lower.contains('футбол') ||
      lower.contains('хоккей') ||
      lower.contains('баскетбол') ||
      lower.contains('теннис') ||
      lower.contains('бокс') ||
      lower.contains('mma') ||
      lower.contains('борьб');
}

bool _isKidsCategory(String? cat) {
  if (cat == null) return false;
  final lower = cat.toLowerCase();
  return lower.contains('дет') ||
      lower.contains('kids') ||
      lower.contains('мульт') ||
      lower.contains('cartoon') ||
      lower.contains('аним');
}

bool _isDocCategory(String? cat) {
  if (cat == null) return false;
  final lower = cat.toLowerCase();
  return lower.contains('познав') ||
      lower.contains('документ') ||
      lower.contains('docum') ||
      lower.contains('наук') ||
      lower.contains('science') ||
      lower.contains('discovery') ||
      lower.contains('природ');
}

class CinemaCategory {
  final String id;
  final String name;
  final List<NowPlayingItem> items;

  const CinemaCategory({required this.id, required this.name, required this.items});
}

// --- Per-channel EPG ---

final currentProgramProvider = FutureProvider.family<EpgProgram?, int>((ref, channelId) async {
  if (channelId <= 0) return null;
  final api = ref.watch(apiClientProvider);
  return api.getCurrentProgram(channelId);
});

final upcomingProgramsProvider = FutureProvider.family<List<EpgProgram>, int>((ref, channelId) async {
  if (channelId <= 0) return [];
  final api = ref.watch(apiClientProvider);
  return api.getUpcomingPrograms(channelId);
});

// --- UI Ticks ---

final epgProgressTickProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(minutes: 1), (i) => i);
});
