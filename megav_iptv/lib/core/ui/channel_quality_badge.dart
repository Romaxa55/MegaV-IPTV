import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../playlist/channel_stream_quality.dart';

/// Компактный лейбл UHD / HD / SD для карточек и списков каналов.
class ChannelQualityBadge extends StatelessWidget {
  final ChannelStreamQuality quality;
  final bool compact;

  const ChannelQualityBadge({super.key, required this.quality, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final padH = compact ? 5.w : 7.w;
    final padV = compact ? 2.h : 3.h;
    final fontSize = compact ? 9.sp : 10.sp;

    final (bg, fg, border) = switch (quality) {
      ChannelStreamQuality.uhd => (
        const Color(0xFFB45309).withValues(alpha: 0.35),
        const Color(0xFFFBBF24),
        const Color(0xFFF59E0B).withValues(alpha: 0.45),
      ),
      ChannelStreamQuality.hd => (
        const Color(0xFF4F46E5).withValues(alpha: 0.35),
        const Color(0xFFC7D2FE),
        const Color(0xFF6366F1).withValues(alpha: 0.45),
      ),
      ChannelStreamQuality.sd => (
        Colors.white.withValues(alpha: 0.10),
        Colors.white.withValues(alpha: 0.55),
        Colors.white.withValues(alpha: 0.12),
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: border),
      ),
      child: Text(
        quality.label,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: fg, letterSpacing: 0.4, height: 1.0),
      ),
    );
  }
}
