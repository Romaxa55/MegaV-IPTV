import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';

/// Displays a channel thumbnail with automatic resolution:
/// EPG picon → M3U logo → disk-cached snapshot → live snapshot.
/// Shows a placeholder while loading, with a fade-in animation.
class ChannelThumbnail extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbAsync = ref.watch(channelThumbnailProvider(channel));

    return thumbAsync.when(
      loading: () => _buildPlaceholder(),
      error: (e, st) => _buildPlaceholder(),
      data: (result) {
        if (result == null) return _buildPlaceholder();

        Widget image;
        if (result.isNetwork) {
          image = Image.network(
            result.url!,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (ctx, err, st) => _buildPlaceholder(),
          );
        } else if (result.isFile) {
          image = Image.file(
            File(result.filePath!),
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (ctx, err, st) => _buildPlaceholder(),
          );
        } else {
          return _buildPlaceholder();
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: SizedBox(key: ValueKey(result.url ?? result.filePath), width: width, height: height, child: image),
        );
      },
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
