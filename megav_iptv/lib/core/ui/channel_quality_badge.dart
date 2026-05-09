import 'package:flutter/material.dart' hide Chip;

import '../playlist/channel_stream_quality.dart';
import 'atoms/atoms.dart';

/// Compact quality label (UHD/HD/SD) for channel cards. Backward-compat
/// shim — internally delegates to [Chip] atom from design-system-atoms.
///
/// Public API preserved: `ChannelQualityBadge({Key? key,
/// required ChannelStreamQuality quality, bool compact = false})`.
///
/// `compact: true` retains the original smaller padding via local Padding
/// adjustment (Chip atom doesn't expose a `compact` param yet).
class ChannelQualityBadge extends StatelessWidget {
  const ChannelQualityBadge({super.key, required this.quality, this.compact = false});

  final ChannelStreamQuality quality;
  final bool compact;

  String get _label {
    switch (quality) {
      case ChannelStreamQuality.uhd:
        return 'UHD';
      case ChannelStreamQuality.hd:
        return 'HD';
      case ChannelStreamQuality.sd:
        return 'SD';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chip = Chip(label: _label, variant: ChipVariant.brand);
    // compact mode: scale slightly. The original was ~85% size in compact.
    if (compact) {
      return Transform.scale(scale: 0.85, child: chip);
    }
    return chip;
  }
}
