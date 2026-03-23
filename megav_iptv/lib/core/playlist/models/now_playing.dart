import 'channel.dart';
import 'epg_program.dart';

class NowPlayingItem {
  final int channelId;
  final String channelName;
  final String groupTitle;
  final String? logoUrl;
  final String? thumbnailUrl;
  final EpgProgram? program;

  const NowPlayingItem({
    required this.channelId,
    required this.channelName,
    this.groupTitle = '',
    this.logoUrl,
    this.thumbnailUrl,
    this.program,
  });

  bool get isLive => program?.isNow ?? false;

  String? get primaryCategory => groupTitle.isNotEmpty ? groupTitle : null;

  factory NowPlayingItem.fromChannel(Channel channel) {
    return NowPlayingItem(
      channelId: channel.id,
      channelName: channel.name,
      groupTitle: channel.groupTitle,
      logoUrl: channel.logoUrl,
      program: null,
    );
  }

  factory NowPlayingItem.fromJson(Map<String, dynamic> json) {
    return NowPlayingItem(
      channelId: json['channelId'] as int,
      channelName: json['channelName'] as String,
      groupTitle: json['groupTitle'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      program: json['program'] != null ? EpgProgram.fromJson(json['program'] as Map<String, dynamic>) : null,
    );
  }
}
