import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../player/decoder_config.dart';
import '../player/player_manager.dart';
import '../playlist/models/channel.dart';
import '../playlist/models/epg_program.dart';
import '../playlist/models/now_playing.dart';

/// When EPG refetches, keep previous [NowPlayingItem] instances if the same channel still has
/// the same program — avoids Image.network resetting and visible poster "blinks".
List<NowPlayingItem> mergeNowPlayingPreserveInstances(List<NowPlayingItem>? previous, List<NowPlayingItem> incoming) {
  if (previous == null || previous.isEmpty) return incoming;
  final byChannel = <int, NowPlayingItem>{for (final p in previous) p.channelId: p};
  return incoming.map((nw) {
    final old = byChannel[nw.channelId];
    if (old == null) return nw;
    if (!_sameEpgSlot(old, nw)) return nw;
    return old;
  }).toList();
}

bool _sameEpgSlot(NowPlayingItem a, NowPlayingItem b) {
  if (a.channelId != b.channelId) return false;
  final pa = a.program;
  final pb = b.program;
  if (pa.id != 0 && pb.id != 0 && pa.id == pb.id) return true;
  return pa.start == pb.start && pa.end == pb.end && pa.title == pb.title;
}

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
  final api = ref.watch(apiClientProvider);
  return api.getNowPlaying();
});

final upcomingAllProvider = FutureProvider<List<NowPlayingItem>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getUpcomingAll(limit: 200);
});

final featuredNowPlayingProvider = FutureProvider<List<NowPlayingItem>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final featured = await api.getFeaturedNowPlaying(limit: 8);
  if (featured.isNotEmpty) return featured;

  var channels = await api.getFeaturedChannels(limit: 8);
  if (channels.isEmpty) {
    final result = await api.getChannels(limit: 8);
    channels = result.channels;
  }
  return channels.map((ch) {
    final item = NowPlayingItem.fromChannel(ch);
    return NowPlayingItem(
      channelId: item.channelId,
      channelName: item.channelName,
      groupTitle: item.groupTitle,
      logoUrl: item.logoUrl,
      thumbnailUrl: api.thumbnailUrl(item.channelId),
      program: item.program,
    );
  }).toList();
});

class CategoryNotifier extends StateNotifier<AsyncValue<List<NowPlayingItem>>> {
  final ApiClient _api;
  final String _category;
  int _total = 0;
  int _offset = 0;
  bool _loading = false;
  static const _pageSize = 30;
  Future<void>? _initFuture;

  CategoryNotifier(this._api, this._category) : super(const AsyncValue.loading()) {
    _initFuture = _loadInitial();
  }

  int get total => _total;
  bool get hasMore => _offset < _total;

  Future<void> waitForInit() => _initFuture ?? Future.value();

  Future<void> _loadInitial() async {
    try {
      final result = await _api.getCategoryNowPlaying(_category, limit: _pageSize, offset: 0);
      _total = result.total;
      _offset = result.items.length;
      final merged = mergeNowPlayingPreserveInstances(state.valueOrNull, result.items);
      state = AsyncValue.data(merged);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (_loading || !hasMore) return;
    _loading = true;
    try {
      final result = await _api.getCategoryNowPlaying(_category, limit: _pageSize, offset: _offset);
      _total = result.total;
      _offset += result.items.length;
      final current = state.value ?? [];
      state = AsyncValue.data([...current, ...result.items]);
    } catch (_) {}
    _loading = false;
  }

  /// Silent refresh: keep current posters on screen while new data loads (no loading → empty flash).
  Future<void> refresh() async {
    _offset = 0;
    _total = 0;
    try {
      final result = await _api.getCategoryNowPlaying(_category, limit: _pageSize, offset: 0);
      _total = result.total;
      _offset = result.items.length;
      final merged = mergeNowPlayingPreserveInstances(state.valueOrNull, result.items);
      state = AsyncValue.data(merged);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final categoryNotifierProvider =
    StateNotifierProvider.family<CategoryNotifier, AsyncValue<List<NowPlayingItem>>, String>((ref, category) {
      final api = ref.watch(apiClientProvider);
      return CategoryNotifier(api, category);
    });

class MoviesNotifier extends StateNotifier<AsyncValue<List<NowPlayingItem>>> {
  final ApiClient _api;
  int _total = 0;
  int _offset = 0;
  bool _loading = false;
  static const _pageSize = 50;
  Future<void>? _initFuture;

  MoviesNotifier(this._api) : super(const AsyncValue.loading()) {
    _initFuture = _loadInitial();
  }

  int get total => _total;
  bool get hasMore => _offset < _total;

  Future<void> waitForInit() => _initFuture ?? Future.value();

  Future<void> _loadInitial() async {
    try {
      final result = await _api.getMoviesNowPlaying(limit: _pageSize, offset: 0);
      _total = result.total;
      _offset = result.items.length;
      final merged = mergeNowPlayingPreserveInstances(state.valueOrNull, result.items);
      state = AsyncValue.data(merged);
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
    try {
      final result = await _api.getMoviesNowPlaying(limit: _pageSize, offset: 0);
      _total = result.total;
      _offset = result.items.length;
      final merged = mergeNowPlayingPreserveInstances(state.valueOrNull, result.items);
      state = AsyncValue.data(merged);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final moviesNotifierProvider = StateNotifierProvider<MoviesNotifier, AsyncValue<List<NowPlayingItem>>>((ref) {
  final api = ref.watch(apiClientProvider);
  return MoviesNotifier(api);
});

final cinemaCategoriesProvider = FutureProvider<List<CinemaCategory>>((ref) async {
  final allCategories = await ref.watch(categoriesProvider.future);
  final categories = <CinemaCategory>[];
  for (final cat in allCategories) {
    if (cat.count > 0) {
      final id = 'group-${cat.name.toLowerCase().replaceAll(' ', '-')}';
      categories.add(CinemaCategory(id: id, name: cat.name));
    }
  }
  return categories;
});

class CinemaCategory {
  final String id;
  final String name;

  const CinemaCategory({required this.id, required this.name});
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
