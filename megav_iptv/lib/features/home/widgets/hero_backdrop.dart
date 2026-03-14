import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';

class HeroBackdrop extends ConsumerWidget {
  final Channel channel;
  const HeroBackdrop({super.key, required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbAsync = ref.watch(channelThumbnailProvider(channel));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1200),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 1.05,
              end: 1.0,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
      child: thumbAsync.when(
        loading: () => _placeholder(key: ValueKey('${channel.url}_loading')),
        error: (e, st) => _placeholder(key: ValueKey('${channel.url}_error')),
        data: (result) {
          if (result == null) {
            return _placeholder(key: ValueKey(channel.url));
          }
          if (result.isNetwork) {
            return Image.network(
              result.url!,
              key: ValueKey(result.url),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (ctx, err, st) => _placeholder(),
            );
          }
          if (result.isFile) {
            return Image.file(
              File(result.filePath!),
              key: ValueKey(result.filePath),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (ctx, err, st) => _placeholder(),
            );
          }
          return _placeholder(key: ValueKey(channel.url));
        },
      ),
    );
  }

  Widget _placeholder({Key? key}) {
    return Container(
      key: key,
      color: AppColors.surface,
      child: Center(
        child: Icon(Icons.tv, size: 80.sp, color: AppColors.textHint.withValues(alpha: 0.3)),
      ),
    );
  }
}
