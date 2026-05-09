import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Breadcrumb row at the top of detail screen — back-icon + breadcrumb trail.
///
/// Maps to design.md §7, Req 8.3.
class DetailBreadcrumb extends StatelessWidget {
  const DetailBreadcrumb({super.key, required this.trail});

  final String trail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.extension<MegaVTextStyles>()?.metaMono ?? theme.textTheme.labelSmall;
    return Row(
      children: [
        MvIconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        SizedBox(width: 14.w),
        Text(trail, style: style),
      ],
    );
  }
}
