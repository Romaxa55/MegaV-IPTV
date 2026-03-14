import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../player/decoder_config.dart';
import '../player/player_manager.dart';
import '../playlist/m3u_parser.dart';
import '../playlist/models/channel.dart';
import '../playlist/models/channel_group.dart';

final playerManagerProvider = Provider<PlayerManager>((ref) {
  final manager = PlayerManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

final decoderConfigProvider =
    StateProvider<DecoderConfig>((ref) => const DecoderConfig());

final playlistUrlProvider = StateProvider<String>(
    (ref) => 'https://romaxa55.github.io/world_ip_tv/output/index.m3u');

final channelsProvider =
    FutureProvider.autoDispose<List<Channel>>((ref) async {
  final url = ref.watch(playlistUrlProvider);
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw Exception('Failed to load playlist: ${response.statusCode}');
  }
  final parser = M3uParser();
  return parser.parseChannels(response.body);
});

final groupsProvider =
    FutureProvider.autoDispose<List<ChannelGroup>>((ref) async {
  final channels = await ref.watch(channelsProvider.future);
  final parser = M3uParser();
  return parser.groupChannels(channels);
});

final selectedGroupProvider = StateProvider<String?>((ref) => null);

final filteredChannelsProvider =
    Provider.autoDispose<AsyncValue<List<Channel>>>((ref) {
  final selectedGroup = ref.watch(selectedGroupProvider);
  final channelsAsync = ref.watch(channelsProvider);

  return channelsAsync.whenData((channels) {
    if (selectedGroup == null) return channels;
    return channels
        .where((c) => c.groupTitle == selectedGroup)
        .toList();
  });
});

final currentChannelProvider = StateProvider<Channel?>((ref) => null);
final currentChannelIndexProvider = StateProvider<int>((ref) => -1);
