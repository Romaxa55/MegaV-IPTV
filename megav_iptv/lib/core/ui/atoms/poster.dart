import 'package:flutter/material.dart';

import '../../perf/perf_safe_widgets.dart';
import '../../theme/app_colors.dart';
import '../../theme/megav_text_styles.dart';
import 'mv_track.dart';

/// Two orientations for [Poster].
///
/// `landscape` → 16/9 aspect ratio (used for hero rails, channel cards).
/// `portrait`  → 2/3 aspect ratio (used for VOD/movie posters).
enum PosterOrientation { landscape, portrait }

/// Poster widget with landscape/portrait orientation, optional title overlay,
/// badge slots TL/TR, and optional progress bar.
///
/// Wraps content in [SafeFocusRing] when [isFocused] (Req 16.3).
///
/// Maps to Requirements 5.1-5.7, 16.3.
class Poster extends StatelessWidget {
  const Poster({
    super.key,
    required this.image,
    this.orientation = PosterOrientation.landscape,
    this.title,
    this.subtitle,
    this.hideText = false,
    this.badgeTL,
    this.badgeTR,
    this.progress,
    this.isFocused = false,
  });

  final ImageProvider image;
  final PosterOrientation orientation;
  final String? title;
  final String? subtitle;
  final bool hideText;
  final Widget? badgeTL;
  final Widget? badgeTR;
  final double? progress;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final aspect = orientation == PosterOrientation.landscape ? 16 / 9 : 2 / 3;
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final titleStyle = (styles?.bodyDefault ?? theme.textTheme.titleSmall)?.copyWith(color: Colors.white);
    final subtitleStyle = (styles?.bodyDim ?? theme.textTheme.bodySmall)?.copyWith(
      color: Colors.white.withValues(alpha: 0.75),
    );

    final content = AspectRatio(
      aspectRatio: aspect,
      child: Stack(
        children: [
          // Image (with fallback on error)
          Positioned.fill(
            child: Image(
              image: image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(color: AppColors.cardBg),
            ),
          ),
          // Optional bottom scrim + title/subtitle
          if (!hideText && (title != null || subtitle != null))
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 24, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null) Text(title!, style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (subtitle != null)
                        Text(subtitle!, style: subtitleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ),
          // Badge slots
          if (badgeTL != null) Positioned(top: 8, left: 8, child: badgeTL!),
          if (badgeTR != null) Positioned(top: 8, right: 8, child: badgeTR!),
          // Progress bar
          if (progress != null) Positioned(left: 0, right: 0, bottom: 0, child: MvTrack(progress: progress!)),
        ],
      ),
    );

    return SafeFocusRing(isFocused: isFocused, child: content);
  }
}
