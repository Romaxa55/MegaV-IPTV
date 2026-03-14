import 'package:flutter/widgets.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';

import '../playlist/models/channel.dart';

class Media3Engine {
  final FtvMedia3PlayerController _controller = FtvMedia3PlayerController();

  FtvMedia3PlayerController get controller => _controller;

  void openChannel({
    required BuildContext context,
    required Channel channel,
    List<Channel>? playlist,
    int initialIndex = 0,
  }) {
    final items = (playlist ?? [channel]).map(_toMediaItem).toList();

    _controller.openPlayer(context: context, playlist: items, initialIndex: initialIndex);
  }

  static PlaylistMediaItem _toMediaItem(Channel channel) {
    return PlaylistMediaItem(
      id: channel.tvgId ?? channel.url.hashCode.toString(),
      url: channel.url,
      title: channel.name,
      subTitle: channel.groupTitle,
      mediaItemType: MediaItemType.tvStream,
      placeholderImg: channel.logoUrl,
      updateWatchTime: false,
    );
  }

  void dispose() {
    _controller.close();
  }
}
