import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/ui/atoms/atoms.dart';
import '../providers/detail_arguments.dart';
import '../providers/detail_data_provider.dart';

/// Horizontal rail of related channels (siblings by groupTitle).
/// Returns `SizedBox.shrink` when no related channels.
///
/// Maps to design.md §6, Req 7.1-7.7, 9.3, 9.5, 11.3.
class RelatedRail extends ConsumerWidget {
  const RelatedRail({super.key, required this.currentChannelId});

  final int currentChannelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(relatedChannelsProvider(currentChannelId));
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionTitle(title: 'Похожие', emphasis: 'по настроению', count: list.length),
        SizedBox(height: 12.h),
        SizedBox(
          height: 290.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            cacheExtent: 1500,
            addAutomaticKeepAlives: true,
            addRepaintBoundaries: true,
            clipBehavior: Clip.none,
            itemCount: list.length,
            itemBuilder: (context, i) => _RelatedItem(channel: list[i]),
          ),
        ),
      ],
    );
  }
}

class _RelatedItem extends StatefulWidget {
  const _RelatedItem({required this.channel});
  final Channel channel;

  @override
  State<_RelatedItem> createState() => _RelatedItemState();
}

class _RelatedItemState extends State<_RelatedItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Focus(
        onFocusChange: (has) => setState(() => _focused = has),
        child: GestureDetector(
          onTap: () =>
              context.pushReplacement('/channel/${widget.channel.id}', extra: DetailArgs(channelId: widget.channel.id)),
          child: Transform.scale(
            scale: _focused ? 1.08 : 1.0,
            child: SizedBox(
              width: 200.w,
              child: Poster(
                image: widget.channel.thumbnailUrl != null && widget.channel.thumbnailUrl!.isNotEmpty
                    ? NetworkImage(widget.channel.thumbnailUrl!)
                    : const AssetImage('assets/grain_overlay.png'),
                orientation: PosterOrientation.portrait,
                title: widget.channel.name,
                isFocused: _focused,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
