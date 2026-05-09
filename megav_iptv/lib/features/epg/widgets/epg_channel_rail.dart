import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/playlist/models/channel.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Vertical channel rail for the EPG screen.
///
/// Shares its [verticalCtl] with the time grid (Req 2.4) so that channel
/// rows and programme rows scroll together. Each cell renders a [Brand]
/// badge plus channel name (`titleMedium`) and group title
/// (`MegaVTextStyles.metaMono`) inside a [SafeFocusRing] wrapped by an
/// [AnimatedScale] (1.0 → 1.05 over 150 ms, `Curves.easeOutCubic`).
///
/// Performance contract (Req 13.1, 13.5):
/// - No GPU-blurring widgets (the perf-gate greps must remain at zero hits).
/// - `cacheExtent: 1500`, `addAutomaticKeepAlives: true`,
///   `addRepaintBoundaries: true`, `clipBehavior: Clip.none`.
/// - Focus ring is GPU-only via `SafeFocusRing` (BoxShadow, blurRadius=0).
///
/// Maps to Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 13.1, 13.2, 13.3, 13.5.
class EpgChannelRail extends ConsumerStatefulWidget {
  const EpgChannelRail({
    super.key,
    required this.channels,
    required this.verticalCtl,
    required this.focusedChannelIndex,
    required this.onFocusChanged,
  });

  /// Ordered channel list rendered top-to-bottom (Req 3.1).
  final List<Channel> channels;

  /// Shared vertical scroll controller — co-owned by [EpgChannelRail]
  /// and the programme grid (Req 2.4, 3.2). The caller owns the
  /// controller's lifecycle; this widget never disposes it.
  final ScrollController verticalCtl;

  /// Index of the channel currently focused by the parent screen, or
  /// `null` when focus is outside the rail. Drives the focus ring +
  /// scale animation (Req 3.3).
  final int? focusedChannelIndex;

  /// Invoked when a cell gains focus. Synchronous, not debounced — the
  /// parent screen decides how to react (Req 3.3).
  final ValueChanged<int> onFocusChanged;

  @override
  ConsumerState<EpgChannelRail> createState() => _EpgChannelRailState();
}

class _EpgChannelRailState extends ConsumerState<EpgChannelRail> {
  @override
  void dispose() {
    // No owned resources: `verticalCtl` is provided by the caller.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final megavText = theme.extension<MegaVTextStyles>();
    final titleStyle = theme.textTheme.titleMedium;
    final metaStyle = megavText?.metaMono ?? theme.textTheme.labelSmall;

    return SizedBox(
      key: const Key('epg-channel-rail'),
      child: ListView.builder(
        controller: widget.verticalCtl,
        scrollDirection: Axis.vertical,
        cacheExtent: 1500,
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
        clipBehavior: Clip.none,
        itemCount: widget.channels.length,
        itemBuilder: (ctx, i) {
          final channel = widget.channels[i];
          final focused = widget.focusedChannelIndex == i;
          return SizedBox(
            key: Key('epg-channel-cell-${channel.id}'),
            width: 240.w,
            height: 88.h,
            child: Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus) widget.onFocusChanged(i);
              },
              child: AnimatedScale(
                scale: focused ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                child: SafeFocusRing(
                  isFocused: focused,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Brand(size: 38, showWordmark: false),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(channel.name, style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                              SizedBox(height: 2.h),
                              Text(channel.groupTitle, style: metaStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
