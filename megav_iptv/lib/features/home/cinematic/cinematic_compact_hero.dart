import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/now_playing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Compact hero bar shown when focus leaves the hero area on TV.
///
/// TV-standard collapse pattern: when D-pad navigates down into a rail the
/// hero shrinks to a narrow strip so rail cards get maximum vertical space.
///
/// Layout (single Row, no gradients, no backdrop):
///   [LIVE chip] [MMLogo] [title 18sp italic] [·] [channelName] [★ rating]
///
/// Height is fixed to [kCompactHeroHeight] and matches the AnimatedContainer
/// target in [_CinematicHomeScreenState].
///
/// Kept in a separate file so cinematic_home_screen.dart stays ≤ 600 lines.
class CinematicCompactHero extends StatelessWidget {
  const CinematicCompactHero({super.key, required this.item});

  final NowPlayingItem item;

  /// The collapsed height the AnimatedContainer targets.
  static const double kCompactHeroHeight = 110;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.activePalette;

    final program = item.program;
    final title = program?.title.isNotEmpty == true ? program!.title : item.channelName;
    final genre = program?.category ?? item.groupTitle;

    final titleStyle = TextStyle(
      fontSize: 18.sp,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w500,
      color: palette.text,
      height: 1.2,
      overflow: TextOverflow.ellipsis,
    );
    final dimStyle = TextStyle(fontSize: 13.sp, color: palette.textDim, overflow: TextOverflow.ellipsis);
    final goldStyle = TextStyle(fontSize: 13.sp, color: palette.gold);

    return Container(
      height: kCompactHeroHeight,
      color: palette.background.withValues(alpha: 0.92),
      padding: EdgeInsets.symmetric(horizontal: 56.w, vertical: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Chip(label: 'В эфире', variant: ChipVariant.live),
          SizedBox(width: 12.w),
          const MMLogo(size: 22),
          SizedBox(width: 14.w),

          // Title — flexible, takes available space.
          Flexible(child: Text(title, style: titleStyle, maxLines: 1)),

          // Separator dot.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: Text('·', style: dimStyle),
          ),

          // Channel name (if different from title).
          if (item.channelName.isNotEmpty && item.channelName != title)
            Flexible(
              flex: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 200.w),
                child: Text(item.channelName, style: dimStyle, maxLines: 1),
              ),
            ),

          // Genre label.
          if (genre.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: Text('·', style: dimStyle),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 160.w),
              child: Text(genre, style: dimStyle, maxLines: 1),
            ),
          ],

          const Spacer(),

          // Rating chip — static placeholder (same as expanded hero).
          Text('★ 8.4', style: goldStyle),
        ],
      ),
    );
  }
}
