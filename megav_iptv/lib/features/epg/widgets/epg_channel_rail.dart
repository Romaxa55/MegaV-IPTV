import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/playlist/models/channel.dart';
import '../../../core/theme/megav_text_styles.dart';

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
    // JSX ChannelCell: name fontSize 14, fontWeight 600, letterSpacing -0.005em.
    final titleStyle = (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.005 * 14,
    );
    // JSX: category mono 11sp, ls=0.14em, uppercase, textMute.
    final metaStyle = (megavText?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 11,
      letterSpacing: 0.14 * 11,
    );

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
            // JSX: CH_W = 240, ROW_H = 88.
            width: 240,
            height: 88,
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
                    // JSX ChannelCell: padding "12px 18px".
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // JSX: 38×38 gradient badge with channel index.
                        _ChannelBadge(index: i),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(channel.name, style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(
                                channel.groupTitle.toUpperCase(),
                                style: metaStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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

/// JSX ChannelCell badge: 38×38, borderRadius 8, gradient, mono index text.
///
/// JSX: `background: linear-gradient(135deg, palette[1], palette[2])`.
/// Uses a fixed accent-based gradient since we don't have per-channel
/// palettes in Flutter. Maps to the JSX visual intent.
class _ChannelBadge extends StatelessWidget {
  const _ChannelBadge({required this.index});

  final int index;

  // Simplified palette rotation matching JSX POSTER_PALETTES structure.
  static const List<List<Color>> _palettes = [
    [Color(0xFF6E56F7), Color(0xFF5A40E8)],
    [Color(0xFFE5424A), Color(0xFF8A1820)],
    [Color(0xFF22D3A8), Color(0xFF16A885)],
    [Color(0xFFE8B96A), Color(0xFFB5843A)],
    [Color(0xFF3D5DFF), Color(0xFF2540D8)],
    [Color(0xFFFF3B5C), Color(0xFFCC1A38)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _palettes[index % _palettes.length];
    final label = (index + 1).toString().padLeft(2, '0');
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: Colors.white,
          letterSpacing: 0.04 * 11,
        ),
      ),
    );
  }
}
