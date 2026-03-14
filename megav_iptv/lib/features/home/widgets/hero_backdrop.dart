import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/playlist/models/channel.dart';

class HeroBackdrop extends StatelessWidget {
  final Channel channel;
  const HeroBackdrop({super.key, required this.channel});

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
      child: channel.logoUrl != null && channel.logoUrl!.isNotEmpty
          ? Image.network(
              channel.logoUrl!,
              key: ValueKey(channel.url),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (ctx, err, st) => _placeholder(),
            )
          : _placeholder(key: ValueKey(channel.url)),
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
