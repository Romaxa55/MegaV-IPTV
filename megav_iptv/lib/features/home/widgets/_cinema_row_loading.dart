// Extracted from cinema_row.dart to keep that file under the 600-line
// per-file size budget. Placeholder geometry mirrors a loaded row so the
// loading → loaded transition is jump-free (closed home-grid-optimization
// req 11.1, 11.2, 11.5).
//
// Owned visually by `home-grid-visual-polish` / `home-grid-optimization`
// (closed). Visible to other widgets via the leading-underscore name —
// only `cinema_row.dart` is meant to import it.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '_grid_tokens.dart';

/// Same vertical space as a loaded row — avoids layout jump; greys
/// instead of empty flash. Number of silhouettes matches
/// `pickColumns(screenW)`.
class CinemaRowLoadingPlaceholder extends StatelessWidget {
  final String title;
  const CinemaRowLoadingPlaceholder({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final n = pickColumns(screenW);
    final pad = GridTokens.horizontalPaddingDp.w;
    final gap = GridTokens.gapDp.w;
    final usable = screenW - 2 * pad - (n - 1) * gap;
    final cardW = usable > 0 ? usable / n : 200.0;

    // home-grid-stability-pass: harmonise placeholder geometry with the
    // new GridTokens.cardHeightDp = 720. Reserve a fixed 60 dp for the
    // title strip, leave the rest for tile silhouettes.
    final tileBandHeight = GridTokens.cardHeightDp.h - 60.h;
    return SizedBox(
      height: GridTokens.cardHeightDp.h,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 60.h,
            child: Padding(
              padding: EdgeInsets.fromLTRB(40.w, 16.h, 40.w, 12.h),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          SizedBox(
            height: tileBandHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: Row(
                children: List.generate(
                  n,
                  (i) => Padding(
                    padding: EdgeInsets.only(right: i == n - 1 ? 0 : gap),
                    child: Container(
                      width: cardW,
                      height: tileBandHeight,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
