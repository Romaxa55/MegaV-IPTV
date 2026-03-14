import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../epg/epg_repository.dart';
import '../player/decoder_config.dart';
import '../player/player_manager.dart';
import '../playlist/m3u_parser.dart';
import '../playlist/models/channel.dart';
import '../playlist/models/channel_group.dart';
import '../playlist/models/epg_program.dart';

final playerManagerProvider = Provider<PlayerManager>((ref) {
  final manager = PlayerManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

final decoderConfigProvider = StateProvider<DecoderConfig>((ref) => const DecoderConfig());

final playlistUrlProvider = StateProvider<String>((ref) => 'https://romaxa55.github.io/world_ip_tv/output/index.m3u');

final channelsProvider = FutureProvider.autoDispose<List<Channel>>((ref) async {
  final url = ref.watch(playlistUrlProvider);
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw Exception('Failed to load playlist: ${response.statusCode}');
  }
  final parser = M3uParser();
  return parser.parseChannels(response.body);
});

final groupsProvider = FutureProvider.autoDispose<List<ChannelGroup>>((ref) async {
  final channels = await ref.watch(channelsProvider.future);
  final parser = M3uParser();
  return parser.groupChannels(channels);
});

final selectedGroupProvider = StateProvider<String?>((ref) => null);

final filteredChannelsProvider = Provider.autoDispose<AsyncValue<List<Channel>>>((ref) {
  final selectedGroup = ref.watch(selectedGroupProvider);
  final channelsAsync = ref.watch(channelsProvider);

  return channelsAsync.whenData((channels) {
    if (selectedGroup == null) return channels;
    return channels.where((c) => c.groupTitle == selectedGroup).toList();
  });
});

final currentChannelProvider = StateProvider<Channel?>((ref) => null);
final currentChannelIndexProvider = StateProvider<int>((ref) => -1);

final featuredChannelsProvider = Provider.autoDispose<List<Channel>>((ref) {
  final channelsAsync = ref.watch(channelsProvider);
  return channelsAsync.when(data: (channels) => channels.take(8).toList(), loading: () => [], error: (e, st) => []);
});

final channelsByGroupProvider = Provider.autoDispose<Map<String, List<Channel>>>((ref) {
  final channelsAsync = ref.watch(channelsProvider);
  return channelsAsync.when(
    data: (channels) {
      final map = <String, List<Channel>>{};
      for (final ch in channels) {
        final group = ch.groupTitle ?? 'Uncategorized';
        map.putIfAbsent(group, () => []).add(ch);
      }
      return map;
    },
    loading: () => {},
    error: (e, st) => {},
  );
});

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

final currentProgramProvider = FutureProvider.family<EpgProgram?, String>((ref, tvgId) async {
  ref.watch(epgRefreshProvider);
  final repo = ref.watch(epgRepositoryProvider);
  return repo.getCurrentProgram(tvgId);
});

final nextProgramProvider = FutureProvider.family<EpgProgram?, String>((ref, tvgId) async {
  ref.watch(epgRefreshProvider);
  final repo = ref.watch(epgRepositoryProvider);
  return repo.getNextProgram(tvgId);
});

final epgLastUpdatedProvider = FutureProvider<DateTime?>((ref) async {
  ref.watch(epgRefreshProvider);
  final repo = ref.watch(epgRepositoryProvider);
  return repo.getLastUpdated();
});
