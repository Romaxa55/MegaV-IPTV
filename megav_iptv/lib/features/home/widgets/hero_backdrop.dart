import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

class HeroBackdrop extends StatelessWidget {
  final String? imageUrl;
  const HeroBackdrop({super.key, this.imageUrl});

  @override
  Widget build(BuildContext context) {
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
      child: imageUrl == null || imageUrl!.isEmpty
          ? _placeholder(key: const ValueKey('empty'))
          : CachedNetworkImage(
              imageUrl: imageUrl!,
              key: ValueKey(imageUrl),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              memCacheWidth: 800,
              errorWidget: (ctx, _, _) => _placeholder(key: ValueKey('${imageUrl}_error')),
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
