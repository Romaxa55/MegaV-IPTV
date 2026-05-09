import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/ui/atoms/atoms.dart';

const List<List<Color>> _avatarPalettes = [
  [Color(0xFF6E56F7), Color(0xFFA88BFF)],
  [Color(0xFFE8B96A), Color(0xFFF2D58E)],
  [Color(0xFFFF3B5C), Color(0xFFFF7088)],
  [Color(0xFF22D3A8), Color(0xFF6EE5C0)],
  [Color(0xFF4FC3FF), Color(0xFF8FD8FF)],
  [Color(0xFFE5424A), Color(0xFFF77B81)],
];

/// Cast avatars row — gradient circles with names. Returns `SizedBox.shrink`
/// when cast is empty (Req 6.4). Wrapped in `ExcludeFocus` for
/// non-focusability (Req 6.5).
///
/// Maps to design.md §5, Req 6.1-6.6, 11.2.
class CastAvatars extends StatelessWidget {
  const CastAvatars({super.key, required this.cast});

  final List<String> cast;

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();
    return ExcludeFocus(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SectionTitle(title: 'В ролях'),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 18.w,
            runSpacing: 12.h,
            children: [
              for (int i = 0; i < cast.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GradientAvatar(index: i, size: 36),
                    SizedBox(width: 10.w),
                    Text(cast[i]),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GradientAvatar extends StatelessWidget {
  const _GradientAvatar({required this.index, required this.size});
  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = _avatarPalettes[index % _avatarPalettes.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: palette, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
    );
  }
}
