import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../player/decoder_config.dart';
import '../player/player_manager.dart';
import '../playlist/models/channel.dart';
import '../playlist/models/epg_program.dart';

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

// --- Channels & Playlists (from Backend API) ---

/// All group names with channel counts.
final groupsProvider = FutureProvider<List<({String name, int count})>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getGroups();
});

/// Paginated channels for a specific group.
/// Key format: "groupName|offset|limit"
final groupChannelsProvider = FutureProvider.family<List<Channel>, String>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final parts = key.split('|');
  final groupName = parts[0] == 'null' ? null : parts[0];
  final offset = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final limit = parts.length > 2 ? int.tryParse(parts[2]) ?? 20 : 20;

  return api.getChannels(group: groupName, offset: offset, limit: limit);
});

/// Helper to build group channels cache key
String groupChannelsKey(String? groupName, {int offset = 0, int limit = 20}) {
  return '${groupName ?? 'null'}|$offset|$limit';
}

/// Featured channels for HeroSection (e.g. popular or recently added)
final featuredChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getFeaturedChannels(limit: 8);
});

final selectedGroupProvider = StateProvider<String?>((ref) => null);
final currentChannelProvider = StateProvider<Channel?>((ref) => null);
final currentChannelIndexProvider = StateProvider<int>((ref) => -1);

// --- EPG (from Backend API) ---

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
