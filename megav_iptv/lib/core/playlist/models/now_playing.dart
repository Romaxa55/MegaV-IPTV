import 'channel.dart';
import 'epg_program.dart';

class NowPlayingItem {
  final String channelId;
  final String channelName;
  final String? logoUrl;
  final String? thumbnailUrl;
  final String? country;
  final List<String> categories;
  final EpgProgram program;

  const NowPlayingItem({
    required this.channelId,
    required this.channelName,
    this.logoUrl,
    this.thumbnailUrl,
    this.country,
    this.categories = const [],
    required this.program,
  });

  bool get isLive => program.isNow;

  String? get primaryCategory => categories.isNotEmpty ? categories.first : null;

  factory NowPlayingItem.fromChannel(Channel channel) {
    final now = DateTime.now();
    return NowPlayingItem(
      channelId: channel.id,
      channelName: channel.name,
      logoUrl: channel.logoUrl,
      country: channel.country,
      categories: channel.categories,
      program: EpgProgram(
        id: '',
        channelId: channel.id,
        title: channel.name,
        start: now,
        end: now.add(const Duration(hours: 1)),
      ),
    );
  }

  factory NowPlayingItem.fromJson(Map<String, dynamic> json) {
    final cats = json['categories'];
    return NowPlayingItem(
      channelId: json['channelId'] as String,
      channelName: json['channelName'] as String,
      logoUrl: json['logoUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      country: json['country'] as String?,
      categories: cats is List ? cats.cast<String>() : const [],
      program: EpgProgram.fromJson(json['program'] as Map<String, dynamic>),
    );
  }
}
