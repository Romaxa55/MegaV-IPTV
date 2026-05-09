import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/playlist/models/channel.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Slide-in vertical channel deck overlay. Renders adjacent channels with
/// focus scale + SafeFocusRing.
///
/// Maps to Req 5, Req 9.3.
class ChannelDeck extends ConsumerWidget {
  const ChannelDeck({super.key, required this.isOpen, required this.channels, this.onChannelSelected, this.focusScope});

  final bool isOpen;
  final List<Channel> channels;
  final void Function(Channel channel)? onChannelSelected;
  final FocusScopeNode? focusScope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedSlide(
      offset: isOpen ? Offset.zero : const Offset(1, 0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      child: Visibility(
        visible: isOpen,
        maintainState: false,
        child: SizedBox(
          width: 320,
          child: ListView.builder(
            scrollDirection: Axis.vertical,
            cacheExtent: 1500,
            addAutomaticKeepAlives: true,
            addRepaintBoundaries: true,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: channels.length,
            itemBuilder: (context, i) {
              final channel = channels[i];
              return _ChannelCard(channel: channel, onTap: () => onChannelSelected?.call(channel));
            },
          ),
        ),
      ),
    );
  }
}

class _ChannelCard extends StatefulWidget {
  const _ChannelCard({required this.channel, this.onTap});

  final Channel channel;
  final VoidCallback? onTap;

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final titleStyle = styles?.bodyDefault ?? theme.textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Focus(
        onFocusChange: (has) => setState(() => _focused = has),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _focused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: SafeFocusRing(
              isFocused: _focused,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    const MMLogo(size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(widget.channel.name, style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
