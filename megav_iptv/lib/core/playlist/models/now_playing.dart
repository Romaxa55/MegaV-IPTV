import 'channel.dart';
import 'epg_program.dart';

class NowPlayingItem {
  final int channelId;
  final String channelName;
  final String groupTitle;
  final String? logoUrl;
  final String? thumbnailUrl;
  final EpgProgram program;

  const NowPlayingItem({
    required this.channelId,
    required this.channelName,
    this.groupTitle = '',
    this.logoUrl,
    this.thumbnailUrl,
    required this.program,
  });

  bool get isLive => program.isNow;

  String? get primaryCategory => groupTitle.isNotEmpty ? groupTitle : null;

  factory NowPlayingItem.fromChannel(Channel channel) {
    final now = DateTime.now();
    return NowPlayingItem(
      channelId: channel.id,
      channelName: channel.name,
      groupTitle: channel.groupTitle,
      logoUrl: channel.logoUrl,
      program: EpgProgram(
        id: 0,
        channelId: channel.id,
        title: channel.name,
        start: now,
        end: now.add(const Duration(hours: 1)),
      ),
    );
  }

  factory NowPlayingItem.fromJson(Map<String, dynamic> json) {
    return NowPlayingItem(
      channelId: json['channelId'] as int,
      channelName: json['channelName'] as String,
      groupTitle: json['groupTitle'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      program: EpgProgram.fromJson(json['program'] as Map<String, dynamic>),
    );
  }
}
