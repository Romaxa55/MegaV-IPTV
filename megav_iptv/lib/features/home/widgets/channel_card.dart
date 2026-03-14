import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/theme/app_colors.dart';

class ChannelCard extends StatefulWidget {
  final Channel channel;
  final VoidCallback? onTap;
  final bool isGrid;

  const ChannelCard({
    super.key,
    required this.channel,
    this.onTap,
    this.isGrid = false,
  });

  @override
  State<ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<ChannelCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isFocused
            ? (Matrix4.identity()..scaleByDouble(1.05, 1.05, 1.05, 1.0))
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        child: Card(
          color: _isFocused ? AppColors.surfaceLight : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side: BorderSide(
              color: _isFocused ? AppColors.focusBorder : AppColors.cardBorder,
              width: _isFocused ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                children: [
                  _buildLogo(),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.channel.name,
                          style: TextStyle(
                            fontSize: widget.isGrid ? 13.sp : 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.channel.groupTitle != null) ...[
                          SizedBox(height: 4.h),
                          Text(
                            widget.channel.groupTitle!,
                            style: TextStyle(
                              fontSize: widget.isGrid ? 10.sp : 12.sp,
                              color: AppColors.textHint,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.play_circle_outline,
                    color: _isFocused
                        ? AppColors.primary
                        : AppColors.textHint,
                    size: 24.sp,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    final size = widget.isGrid ? 36.w : 44.w;
    if (widget.channel.logoUrl != null &&
        widget.channel.logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: Image.network(
          widget.channel.logoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
                _buildPlaceholder(size),
        ),
      );
    }
    return _buildPlaceholder(size);
  }

  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Icon(
        Icons.tv,
        color: AppColors.primaryLight,
        size: size * 0.5,
      ),
    );
  }
}
