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
  return api.getNowPlaying();
});

final upcomingAllProvider = FutureProvider<List<NowPlayingItem>>((ref) async {
  ref.watch(epgProgressTickProvider);
  final api = ref.watch(apiClientProvider);
  return api.getUpcomingAll(limit: 200);
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

class MoviesNotifier extends StateNotifier<AsyncValue<List<NowPlayingItem>>> {
  final ApiClient _api;
  int _total = 0;
  int _offset = 0;
  bool _loading = false;
  static const _pageSize = 20;

  MoviesNotifier(this._api) : super(const AsyncValue.loading()) {
    _loadInitial();
  }

  int get total => _total;
  bool get hasMore => _offset < _total;

  Future<void> _loadInitial() async {
    try {
      final result = await _api.getMoviesNowPlaying(limit: _pageSize, offset: 0);
      _total = result.total;
      _offset = result.items.length;
      state = AsyncValue.data(result.items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (_loading || !hasMore) return;
    _loading = true;
    try {
      final result = await _api.getMoviesNowPlaying(limit: _pageSize, offset: _offset);
      _total = result.total;
      _offset += result.items.length;
      final current = state.value ?? [];
      state = AsyncValue.data([...current, ...result.items]);
    } catch (_) {}
    _loading = false;
  }

  Future<void> refresh() async {
    _offset = 0;
    _total = 0;
    state = const AsyncValue.loading();
    await _loadInitial();
  }
}

final moviesNotifierProvider = StateNotifierProvider<MoviesNotifier, AsyncValue<List<NowPlayingItem>>>((ref) {
  ref.watch(epgProgressTickProvider);
  final api = ref.watch(apiClientProvider);
  return MoviesNotifier(api);
});

final cinemaCategoriesProvider = FutureProvider<List<CinemaCategory>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final moviesAsync = ref.watch(moviesNotifierProvider);
  final movies = moviesAsync.value ?? [];

  final results = await Future.wait([
    ref.watch(nowPlayingProvider.future),
    ref.watch(upcomingAllProvider.future),
    ref.watch(categoriesProvider.future),
  ]);

  final nowPlaying = results[0] as List<NowPlayingItem>;
  final upcoming = results[1] as List<NowPlayingItem>;
  final allCategories = results[2] as List<({String name, int count})>;

  final categories = <CinemaCategory>[];

  if (movies.isNotEmpty) {
    categories.add(CinemaCategory(id: 'live-movies', name: '🔴  Фильмы в эфире', items: movies));
  }

  if (upcoming.isNotEmpty) {
    final movieUpcoming = upcoming.where((i) => _isMovieCategory(i.program.category)).toList();
    if (movieUpcoming.isNotEmpty) {
      categories.add(CinemaCategory(id: 'upcoming-movies', name: '⏰  Скоро начнётся', items: movieUpcoming));
    }
  }

  final byGroup = <String, List<NowPlayingItem>>{};
  for (final item in nowPlaying) {
    (byGroup[item.groupTitle] ??= []).add(item);
  }

  final coveredGroups = <String>{};
  final missingGroupNames = <String>[];

  for (final cat in allCategories) {
    final epgItems = byGroup[cat.name];
    if (epgItems != null && epgItems.isNotEmpty) {
      final id = 'group-${cat.name.toLowerCase().replaceAll(' ', '-')}';
      categories.add(CinemaCategory(id: id, name: cat.name, items: epgItems));
      coveredGroups.add(cat.name);
    } else if (cat.count > 0) {
      missingGroupNames.add(cat.name);
    }
  }

  if (missingGroupNames.isNotEmpty) {
    final futures = missingGroupNames.map((g) => api.getChannels(category: g, limit: 50));
    final results = await Future.wait(futures);
    for (var i = 0; i < missingGroupNames.length; i++) {
      final channels = results[i].channels;
      if (channels.isEmpty) continue;
      final items = channels.map((ch) => NowPlayingItem.fromChannel(ch)).toList();
      final name = missingGroupNames[i];
      final id = 'group-${name.toLowerCase().replaceAll(' ', '-')}';
      categories.add(CinemaCategory(id: id, name: name, items: items));
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
