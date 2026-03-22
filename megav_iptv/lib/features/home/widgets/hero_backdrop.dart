import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

/// Hero background: avoids thumbnail "blink" on channel change by using
/// [Image.gaplessPlayback] — old image stays visible until the new one is decoded.
class HeroBackdrop extends StatelessWidget {
  final String? imageUrl;
  const HeroBackdrop({super.key, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _placeholder();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Stable base so we never flash to black while the first frame decodes.
        ColoredBox(color: AppColors.surface),
        Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: 800,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, _, _) => _placeholder(),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Icon(Icons.tv, size: 80.sp, color: AppColors.textHint.withValues(alpha: 0.3)),
      ),
    );
  }
}
