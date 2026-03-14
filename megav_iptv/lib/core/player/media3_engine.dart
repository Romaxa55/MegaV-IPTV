import 'package:flutter/widgets.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';

import '../playlist/models/channel.dart';

class Media3Engine {
  final FtvMedia3PlayerController _controller = FtvMedia3PlayerController();

  FtvMedia3PlayerController get controller => _controller;

  void openChannel({
    required BuildContext context,
    required Channel channel,
    required String streamUrl,
    List<Channel>? playlist,
    int initialIndex = 0,
  }) {
    final item = PlaylistMediaItem(
      id: channel.id,
      url: streamUrl,
      title: channel.name,
      subTitle: channel.groupTitle,
      mediaItemType: MediaItemType.tvStream,
      placeholderImg: channel.logoUrl,
      updateWatchTime: false,
    );

    _controller.openPlayer(context: context, playlist: [item], initialIndex: initialIndex);
  }

  void dispose() {
    _controller.close();
  }
}
