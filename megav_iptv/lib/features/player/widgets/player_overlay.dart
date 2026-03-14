import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

class PlayerOverlay extends StatelessWidget {
  final String channelName;
  final String? groupName;
  final VoidCallback onBack;
  final VoidCallback onChannelUp;
  final VoidCallback onChannelDown;

  const PlayerOverlay({
    super.key,
    required this.channelName,
    this.groupName,
    required this.onBack,
    required this.onChannelUp,
    required this.onChannelDown,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 24.w, vertical: 12.h),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: Colors.white, size: 28.sp),
                      onPressed: onBack,
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            channelName,
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (groupName != null)
                            Text(
                              groupName!,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(Icons.keyboard_arrow_up,
                              color: Colors.white, size: 32.sp),
                          onPressed: onChannelUp,
                        ),
                        Text(
                          'CH',
                          style: TextStyle(
                              fontSize: 10.sp, color: AppColors.textHint),
                        ),
                        IconButton(
                          icon: Icon(Icons.keyboard_arrow_down,
                              color: Colors.white, size: 32.sp),
                          onPressed: onChannelDown,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
