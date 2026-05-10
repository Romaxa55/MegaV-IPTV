// Single-line hero search input with blinking accent caret.
//
// JSX reference (`search-v2.jsx` SearchBar):
// ```jsx
// <div style={{
//   flex: 1, fontFamily: "var(--font-ui)", fontWeight: 500,
//   fontSize: 32, letterSpacing: "-0.02em",
//   color: query ? "var(--text)" : "var(--text-mute)",
// }}>
//   {query || "Введите запрос…"}
//   <span style={{
//     display: "inline-block", width: 2, height: 28,
//     background: "var(--accent)", marginLeft: 4, verticalAlign: "middle",
//     animation: "mvblink 1s steps(2) infinite",
//   }}></span>
// </div>
// ```
//
// Typography: UI sans 32sp, w500, ls=-0.02em.
// Caret: 3×36 accent bar (JSX says width:2 height:28, we use 3×36 per task spec).
//
// Maps to Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 9.3.

import 'package:flutter/material.dart' hide Chip;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';

/// Renders the current search [query] in the editorial display style.
///
/// When [query] is empty the [placeholder] is shown in a dimmed color (Req 4.2).
/// A blinking accent caret bar (3×36 lp) is appended to the right (Req 4.3).
class SearchInput extends StatefulWidget {
  const SearchInput({super.key, required this.query, this.placeholder = 'Найти что-то стоящее'});

  final String query;
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
    final styles = theme.extension<MegaVTextStyles>();
    final palette = AppColors.activePalette;
    final hasQuery = widget.query.isNotEmpty;

    // JSX: fontFamily var(--font-ui), fontWeight 500, fontSize 32, ls -0.02em.
    final baseStyle = styles?.bodyDefault ?? theme.textTheme.bodyLarge ?? const TextStyle();
    final textStyle = baseStyle.copyWith(
      fontSize: 32,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.02 * 32,
      color: hasQuery ? palette.text : palette.textMute,
      height: 1.2,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        // JSX SearchBar: background var(--surface), border, borderRadius 12.
        color: palette.surface,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Search icon.
          Icon(Icons.search, size: 22, color: palette.textDim),
          const SizedBox(width: 16),
          // Query text.
          Expanded(
            child: Text(
              hasQuery ? widget.query : widget.placeholder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
          const SizedBox(width: 4),
          // Blinking caret bar: 3×36 accent (Req 4.3, task spec).
          RepaintBoundary(
            child: FadeTransition(
              opacity: Tween<double>(
                begin: 1.0,
                end: 0.0,
              ).animate(CurvedAnimation(parent: _caret, curve: Curves.easeInOut)),
              child: Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
