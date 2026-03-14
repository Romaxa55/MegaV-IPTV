import 'models/channel.dart';
import 'models/channel_group.dart';

class M3uParser {
  static final _extInfRegex = RegExp(r'#EXTINF:\s*-?\d+\s*(.*)');
  static final _attrRegex = RegExp(r'(\w[\w-]*)="([^"]*)"');

  List<Channel> parseChannels(String content) {
    final lines = content.split('\n');
    final channels = <Channel>[];

    String? currentName;
    String? currentLogo;
    String? currentGroup;
    String? currentTvgId;
    String? currentTvgName;
    String? currentLanguage;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.startsWith('#EXTINF:')) {
        final match = _extInfRegex.firstMatch(line);
        if (match != null) {
          final attrs = match.group(1) ?? '';
          final attrMap = <String, String>{};
          for (final m in _attrRegex.allMatches(attrs)) {
            attrMap[m.group(1)!.toLowerCase()] = m.group(2)!;
          }

          currentTvgId = attrMap['tvg-id'];
          currentTvgName = attrMap['tvg-name'];
          currentLogo = attrMap['tvg-logo'];
          currentGroup = attrMap['group-title'];
          currentLanguage = attrMap['tvg-language'];

          final commaIndex = attrs.lastIndexOf(',');
          currentName = commaIndex >= 0 ? attrs.substring(commaIndex + 1).trim() : '';
        }
      } else if (line.isNotEmpty && !line.startsWith('#') && currentName != null) {
        channels.add(
          Channel(
            name: currentName.isNotEmpty ? currentName : 'Unknown',
            url: line,
            logoUrl: currentLogo,
            groupTitle: currentGroup,
            tvgId: currentTvgId,
            tvgName: currentTvgName,
            language: currentLanguage,
          ),
        );
        currentName = null;
        currentLogo = null;
        currentGroup = null;
        currentTvgId = null;
        currentTvgName = null;
        currentLanguage = null;
      }
    }

    return channels;
  }

  List<ChannelGroup> groupChannels(List<Channel> channels) {
    final groupMap = <String, List<Channel>>{};

    for (final channel in channels) {
      final groupName = channel.groupTitle ?? 'Uncategorized';
      groupMap.putIfAbsent(groupName, () => []).add(channel);
    }

    return groupMap.entries.map((e) => ChannelGroup(name: e.key, channels: e.value)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }
}
