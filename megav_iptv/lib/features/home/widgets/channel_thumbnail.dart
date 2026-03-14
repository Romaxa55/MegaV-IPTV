import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/theme/app_colors.dart';

/// Simple network image widget that loads the thumbnail or logo URL from the backend.
class ChannelThumbnail extends StatelessWidget {
  final Channel channel;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;

  const ChannelThumbnail({
    super.key,
    required this.channel,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    // Prefer the backend-generated live thumbnail over the static logo
    final url = channel.thumbnailUrl ?? channel.logoUrl;

    if (url == null || url.isEmpty) {
      return _buildPlaceholder();
    }

    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (ctx, err, st) => _buildPlaceholder(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _buildLoadingPlaceholder();
      },
    );
  }

  Widget _buildLoadingPlaceholder() {
    return placeholder ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFF12121E),
          child: Center(
            child: SizedBox(
              width: 20.sp,
              height: 20.sp,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.textHint.withValues(alpha: 0.2)),
              ),
            ),
          ),
        );
  }

  Widget _buildPlaceholder() {
    return placeholder ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFF12121E),
          child: Center(
            child: Icon(Icons.tv, size: 36.sp, color: AppColors.textHint.withValues(alpha: 0.3)),
          ),
        );
  }
}
