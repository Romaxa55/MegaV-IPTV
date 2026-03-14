import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/theme/app_colors.dart';

class ChannelSwitchPreview extends StatelessWidget {
  final Channel channel;

  const ChannelSwitchPreview({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.8), Colors.black.withValues(alpha: 0.5), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.fromLTRB(32.w, 24.h, 32.w, 64.h),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                width: 96.w,
                height: 64.h,
                color: Colors.white.withValues(alpha: 0.1),
                child: channel.logoUrl != null && channel.logoUrl!.isNotEmpty
                    ? Image.network(channel.logoUrl!, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => _placeholder())
                    : _placeholder(),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    channel.name,
                    style: TextStyle(fontSize: 18.sp, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    channel.groupTitle,
                    style: TextStyle(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                ),
                SizedBox(width: 6.w),
                Text(
                  'переключение...',
                  style: TextStyle(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.2)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Center(
    child: Icon(Icons.tv, size: 24.sp, color: Colors.white.withValues(alpha: 0.2)),
  );
}

class BriefChannelOSD extends StatelessWidget {
  final Channel channel;

  const BriefChannelOSD({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 24.h,
      left: 24.w,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Container(
                width: 40.w,
                height: 40.w,
                color: Colors.white.withValues(alpha: 0.1),
                child: channel.logoUrl != null && channel.logoUrl!.isNotEmpty
                    ? Image.network(channel.logoUrl!, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => _ph())
                    : _ph(),
              ),
            ),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  channel.name,
                  style: TextStyle(fontSize: 14.sp, color: Colors.white),
                ),
                Text(
                  channel.groupTitle,
                  style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.3)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ph() => Center(
    child: Icon(Icons.tv, size: 16.sp, color: Colors.white.withValues(alpha: 0.2)),
  );
}
