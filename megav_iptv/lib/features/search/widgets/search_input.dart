// Single-line "input field" rendered in a hero-display style with a
// blinking caret bar.
//
// `SearchInput` is purely presentational — it receives the current `query`
// string and a `placeholder`, and shows whichever one is non-empty. The
// caret is animated via an `AnimationController(repeat: reverse: true)`
// wrapped in a `RepaintBoundary` (Req 4.3, 9.3) so the per-tick repaints
// don't bubble up to the parent widget tree.
//
// No text editing happens here — input comes exclusively from the on-screen
// `CyrillicKeyboard` via the search controller (Req 4.5).
//
// Maps to Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 9.3.

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';

/// Renders the current search [query] in the editorial display style.
///
/// When [query] is empty, the [placeholder] is shown in a dimmed color
/// (Req 4.2). A blinking accent caret is appended to the right (Req 4.3).
class SearchInput extends StatefulWidget {
  const SearchInput({super.key, required this.query, this.placeholder = 'Найти что-то стоящее'});

  /// Current query string from the search controller. Empty string renders
  /// the [placeholder] in a dimmed color.
  final String query;

  /// Placeholder shown when [query] is empty.
  final String placeholder;

  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> with SingleTickerProviderStateMixin {
  late final AnimationController _caret;

  @override
  void initState() {
    super.initState();
    _caret = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _caret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Defensive lookup: tests sometimes pump screens without registering the
    // `MegaVTextStyles` extension, so we fall back to the raw `textTheme`
    // entry rather than throwing.
    final TextStyle? extStyle = theme.extension<MegaVTextStyles>()?.displayLarge;
    final TextStyle? textStyle = extStyle ?? theme.textTheme.displayLarge;
    final hasQuery = widget.query.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            hasQuery ? widget.query : widget.placeholder,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (textStyle ?? const TextStyle()).copyWith(
              color: hasQuery ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        RepaintBoundary(
          child: FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.2).animate(_caret),
            child: Container(width: 3.w, height: 36.h, color: AppColors.accent),
          ),
        ),
      ],
    );
  }
}
