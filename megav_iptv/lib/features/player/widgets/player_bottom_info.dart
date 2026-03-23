import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/channel_stream_quality.dart';
import '../../../core/playlist/models/channel.dart';
import '../../../core/playlist/models/epg_program.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/channel_quality_badge.dart';

class PlayerBottomInfo extends ConsumerWidget {
  final Channel channel;
  final bool isSwitching;

  const PlayerBottomInfo({super.key, required this.channel, this.isSwitching = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programAsync = ref.watch(currentProgramProvider(channel.id));

    // Must NOT wrap root in [Positioned] — parent [Stack] may wrap this in
    // [AnimatedOpacity] etc.; [Positioned] must be a direct child of [Stack].
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.9),
            Colors.black.withValues(alpha: 0.7),
            Colors.black.withValues(alpha: 0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 0.8, 1.0],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(40.w, 80.h, 40.w, 32.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Left side: Content Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBadges(programAsync.valueOrNull),
                  SizedBox(height: 12.h),
                  Text(
                    programAsync.valueOrNull?.title ?? channel.name,
                    style: TextStyle(fontSize: 36.sp, fontWeight: FontWeight.w600, color: Colors.white, height: 1.1),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8.h),
                  if (programAsync.valueOrNull != null) _buildMetaRow(programAsync.value!),
                  if (programAsync.valueOrNull?.synopsis != null) ...[
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: 672.w,
                      child: Text(
                        programAsync.value!.synopsis!,
                        style: TextStyle(fontSize: 16.sp, color: Colors.white.withValues(alpha: 0.50), height: 1.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (programAsync.valueOrNull != null) ...[
                    SizedBox(height: 16.h),
                    _buildProgressBar(programAsync.value!),
                  ],
                ],
              ),
            ),
            // Right side: "Switching..." text if needed
            if (isSwitching)
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'переключение...',
                      style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadges(EpgProgram? prog) {
    final streamQ = detectChannelStreamQuality(channel.name, groupTitle: channel.groupTitle);
    return Row(
      children: [
        if (prog != null && prog.isNow) ...[
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFB2C36).withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.70), shape: BoxShape.circle),
                ),
                SizedBox(width: 6.w),
                Text(
                  'В ЭФИРЕ',
                  style: TextStyle(fontSize: 12.sp, color: Colors.white, letterSpacing: 0.3),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
        ],
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildChannelLogo(14.w),
              SizedBox(width: 6.w),
              Text(
                channel.name,
                style: TextStyle(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.90)),
              ),
            ],
          ),
        ),
        if (prog?.category != null || channel.groupTitle.isNotEmpty) ...[
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              prog?.category ?? channel.groupTitle,
              style: TextStyle(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.60)),
            ),
          ),
        ],
        if (streamQ != null) ...[SizedBox(width: 8.w), ChannelQualityBadge(quality: streamQ)],
      ],
    );
  }

  Widget _buildMetaRow(EpgProgram prog) {
    final hash = prog.title.hashCode.abs();
    final rating = 6.0 + (hash % 40) / 10.0;
    final year = prog.parsedYear;

    return Row(
      children: [
        Icon(Icons.star_rounded, size: 20.sp, color: const Color(0xFF22C55E)),
        SizedBox(width: 6.w),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(fontSize: 18.sp, color: const Color(0xFF22C55E)),
        ),
        if (year != null) ...[
          _dot(),
          Text(
            year,
            style: TextStyle(fontSize: 16.sp, color: Colors.white.withValues(alpha: 0.60)),
          ),
        ],
        if (prog.category != null) ...[
          _dot(),
          Text(
            prog.category!,
            style: TextStyle(fontSize: 16.sp, color: Colors.white.withValues(alpha: 0.60)),
          ),
        ],
        _dot(),
        Text(
          _formatDuration(prog.duration),
          style: TextStyle(fontSize: 16.sp, color: Colors.white.withValues(alpha: 0.60)),
        ),
      ],
    );
  }

  Widget _dot() => Padding(
    padding: EdgeInsets.symmetric(horizontal: 8.w),
    child: Text(
      '•',
      style: TextStyle(fontSize: 16.sp, color: Colors.white.withValues(alpha: 0.20)),
    ),
  );

  Widget _buildProgressBar(EpgProgram prog) {
    return SizedBox(
      width: 448.w,
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16.sp, color: Colors.white.withValues(alpha: 0.40)),
              SizedBox(width: 12.w),
              Text(
                _fmtTime(prog.start),
                style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.50)),
              ),
              SizedBox(width: 12.w),
              Text(
                '—',
                style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.25)),
              ),
              SizedBox(width: 12.w),
              Text(
                _fmtTime(prog.end),
                style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.50)),
              ),
              const Spacer(),
              Text(
                'ещё ${_formatDuration(prog.remaining)}',
                style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.60)),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: SizedBox(
              height: 8.h,
              child: Stack(
                children: [
                  Container(color: Colors.white.withValues(alpha: 0.10)),
                  FractionallySizedBox(
                    widthFactor: prog.duration.inSeconds <= 0 ? 0.0 : prog.progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA78BFA)]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelLogo(double size) {
    final logoUrl = channel.logoUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4.r),
        child: Image.network(
          logoUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          cacheWidth: 64,
          cacheHeight: 64,
          errorBuilder: (_, _, _) => Icon(Icons.tv_rounded, size: size, color: Colors.white.withValues(alpha: 0.60)),
        ),
      );
    }
    return Icon(Icons.tv_rounded, size: size, color: Colors.white.withValues(alpha: 0.60));
  }

  String _fmtTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours} ч ${d.inMinutes.remainder(60)} мин';
    return '${d.inMinutes} мин';
  }
}
