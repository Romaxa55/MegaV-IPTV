import 'channel.dart';

class ChannelGroup {
  final String name;
  final List<Channel> channels;

  const ChannelGroup({
    required this.name,
    required this.channels,
  });

  int get channelCount => channels.length;

  @override
  String toString() => 'ChannelGroup(name: $name, channels: $channelCount)';
}
