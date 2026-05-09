import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/perf/perf_safe_widgets.dart';
import '../../core/playlist/models/channel.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/atoms/atoms.dart';
import 'providers/detail_arguments.dart';
import 'providers/detail_data_provider.dart';
import 'widgets/action_row.dart';
import 'widgets/cast_avatars.dart';
import 'widgets/detail_breadcrumb.dart';
import 'widgets/hero_meta.dart';
import 'widgets/related_rail.dart';

/// Full-bleed channel detail screen — hero artwork via [SafeBackdrop] +
/// scrollable content (breadcrumb + portrait poster Hero + meta + actions
/// + cast + related rail).
///
/// Three-layer Stack composition (design.md §2):
///  1. [SafeBackdrop] (pre-rendered cached blur of poster).
///  2. Single [combinedHeroGradient] overlay (one render pass, Req 2.3).
///  3. Scrollable content (breadcrumb / poster / meta / actions / cast / related).
///
/// Maps to Req 1.5, 2.x, 5.2, 8.1, 8.2, 8.6, 9.1-9.4, 9.7, 11.5, 11.6.
class DetailScreen extends ConsumerStatefulWidget {
  const DetailScreen({super.key, required this.channelId, this.args});

  final int channelId;
  final DetailArgs? args;

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  late final FocusNode _playFocusNode;

  @override
  void initState() {
    super.initState();
    _playFocusNode = FocusNode(debugLabel: 'DetailScreen.play');
    // Defer focus request to after first frame so the action row is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _playFocusNode.dispose();
    super.dispose();
  }

  /// Resolve the [Channel] from the existing `featuredChannelsProvider`.
  /// Returns `null` when not found — caller renders graceful fallback (Req 11.6).
  Channel? _resolveChannel() {
    final featured = ref.watch(featuredChannelsProvider).valueOrNull ?? const <Channel>[];
    if (featured.isEmpty) return null;
    for (final c in featured) {
      if (c.id == widget.channelId) return c;
    }
    return null;
  }

  void _handlePlay(Channel channel) {
    // Update player state then navigate — ActionRow itself does NOT push (Req 4.7).
    ref.read(currentChannelProvider.notifier).state = channel;
    context.push('/player');
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.activePalette;
    final channel = _resolveChannel();
    final cast = ref.watch(castListProvider(widget.channelId));

    if (channel == null) {
      // Graceful degradation — channel not found / playlist still loading.
      return Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DetailBreadcrumb(trail: 'Канал не найден'),
                SizedBox(height: 24.h),
                Text(
                  'Канал #${widget.channelId} не найден',
                  style: TextStyle(color: palette.text, fontSize: 24.sp),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Resolve poster ImageProvider — prefer pre-loaded from DetailArgs.
    final ImageProvider? posterImage =
        widget.args?.posterImageProvider ??
        ((channel.thumbnailUrl != null && channel.thumbnailUrl!.isNotEmpty)
            ? NetworkImage(channel.thumbnailUrl!)
            : null);

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1 — SafeBackdrop (pre-rendered blurred hero artwork).
          // Wrapped in RepaintBoundary to isolate hero repaints (Req 2.5, 9.4).
          RepaintBoundary(
            child: SafeBackdrop(imageProvider: posterImage, fallbackBackground: palette.background),
          ),
          // Layer 2 — single combinedHeroGradient overlay (Req 2.3, 9.3).
          Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: combinedHeroGradient(palette))),
          ),
          // Layer 3 — scrollable content.
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DetailBreadcrumb(trail: '${channel.groupTitle} → ${channel.name}'),
                  SizedBox(height: 32.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Portrait poster wrapped in Hero shared element (Req 5.2).
                      Hero(
                        tag: 'channel-poster-${widget.channelId}',
                        child: SizedBox(
                          width: 460.w,
                          height: 680.h,
                          child: posterImage != null
                              ? Poster(image: posterImage, orientation: PosterOrientation.portrait, hideText: true)
                              : ColoredBox(color: palette.surface1),
                        ),
                      ),
                      SizedBox(width: 32.w),
                      // Hero meta + actions.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HeroMeta(
                              title: channel.name,
                              metaItems: [
                                if (channel.groupTitle.isNotEmpty)
                                  HeroMetaItem(label: channel.groupTitle, isAccent: true),
                              ],
                            ),
                            SizedBox(height: 24.h),
                            ActionRow(playFocusNode: _playFocusNode, onPlay: () => _handlePlay(channel)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 48.h),
                  CastAvatars(cast: cast),
                  SizedBox(height: 32.h),
                  RelatedRail(currentChannelId: widget.channelId),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
