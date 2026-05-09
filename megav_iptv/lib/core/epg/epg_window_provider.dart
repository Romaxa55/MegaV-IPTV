import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../playlist/models/epg_program.dart';
import '../providers/providers.dart' show apiClientProvider;
import 'epg_repository.dart';

@immutable
class EpgWindowKey {
  EpgWindowKey({required this.from, required this.to, required List<int> channelIds})
    : channelIds = (List.of(channelIds)..sort());

  final DateTime from;
  final DateTime to;
  final List<int> channelIds;

  @override
  bool operator ==(Object other) =>
      other is EpgWindowKey &&
      other.from == from &&
      other.to == to &&
      other.channelIds.length == channelIds.length &&
      _listEquals(other.channelIds, channelIds);

  @override
  int get hashCode => Object.hash(from, to, Object.hashAll(channelIds));

  static bool _listEquals(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final epgRepositoryProvider = Provider<EpgRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return EpgRepository(api);
});

final epgWindowProvider = FutureProvider.family<Map<int, List<EpgProgram>>, EpgWindowKey>((ref, key) async {
  final repo = ref.watch(epgRepositoryProvider);
  return repo.programmesInWindow(key.from, key.to, key.channelIds);
});
