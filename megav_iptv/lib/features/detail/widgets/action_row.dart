import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/ui/atoms/atoms.dart';

/// Action row — primary Play button + optional ghost actions (favorite,
/// trailer, share, EPG). Doesn't navigate directly — only invokes
/// callbacks supplied by screen (Req 4.7).
///
/// Maps to design.md §4, Req 4.1-4.4, 4.6, 4.7.
class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.playFocusNode,
    required this.onPlay,
    this.onFavorite,
    this.onTrailer,
    this.onShare,
    this.onEpg,
  });

  final FocusNode playFocusNode;
  final VoidCallback onPlay;
  final VoidCallback? onFavorite;
  final VoidCallback? onTrailer;
  final VoidCallback? onShare;
  final VoidCallback? onEpg;

  @override
  Widget build(BuildContext context) {
    final ghosts = <Widget>[];
    if (onFavorite != null) ghosts.add(MvButton.ghost(label: 'В избранное', onPressed: onFavorite));
    if (onTrailer != null) ghosts.add(MvButton.ghost(label: 'Трейлер', onPressed: onTrailer));
    if (onShare != null) ghosts.add(MvButton.ghost(label: 'Поделиться', onPressed: onShare));
    if (onEpg != null) ghosts.add(MvButton.ghost(label: 'Программа', onPressed: onEpg));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Focus(
          focusNode: playFocusNode,
          child: MvButton.primary(label: 'Смотреть', icon: const Icon(Icons.play_arrow), onPressed: onPlay),
        ),
        for (final btn in ghosts) ...[SizedBox(width: 12.w), btn],
      ],
    );
  }
}
