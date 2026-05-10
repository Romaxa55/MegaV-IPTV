// SearchScreen — top-level route widget for `/search`.
//
// JSX reference: `search-v2.jsx` ScreenSearchV2.
//
// Layout:
//   HEADER (full-width): display title "Найти что-то стоящее" + filter tabs.
//   BODY: two-pane grid — left 360 lp (keyboard + recents), right (results).
//
// JSX header:
//   padding "32px 56px 20px", borderBottom "1px solid var(--line)".
//   Eyebrow: mono 10sp "ПОИСК · ПО ВСЕМУ КАТАЛОГУ".
//   Title: display w600 56sp "Найти" + dim w400 "что-то стоящее".
//
// Maps to Requirements 1.5, 10.5, 11.1–11.5.

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/megav_text_styles.dart';
import 'state/search_controller.dart';
import 'widgets/cyrillic_keyboard.dart';
import 'widgets/search_input.dart';
import 'widgets/search_results_grid.dart';

/// Search screen mounted at the `/search` route.
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.activePalette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────
            _SearchHeader(),
            // ── Body: keyboard (left) + results (right) ─────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SizedBox(width: 360, child: _LeftPane()),
                  Expanded(child: SearchResultsGrid()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final palette = AppColors.activePalette;

    // JSX: eyebrow mono 10sp, ls 0.22em, textMute, uppercase.
    final eyebrowStyle = (styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 10,
      letterSpacing: 0.22 * 10,
      color: palette.textMute,
    );
    // JSX: title display w600 56sp, ls -0.025em, lh 0.95.
    final titleStyle = (styles?.displayLarge ?? theme.textTheme.headlineMedium ?? const TextStyle()).copyWith(
      fontSize: 56,
      fontWeight: FontWeight.w600,
      height: 0.95,
      letterSpacing: -0.025 * 56,
      color: palette.text,
    );
    final dimStyle = titleStyle.copyWith(fontWeight: FontWeight.w400, color: palette.textDim);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: Padding(
        // JSX: padding "32px 56px 20px".
        padding: const EdgeInsets.fromLTRB(56, 32, 56, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ПОИСК · ПО ВСЕМУ КАТАЛОГУ', style: eyebrowStyle),
                    const SizedBox(height: 8),
                    // JSX: "Найти" bold + "что-то стоящее" dim w400.
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(text: 'Найти ', style: titleStyle),
                          TextSpan(text: 'что-то стоящее', style: dimStyle),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // JSX: filter tabs — Все / Фильмы / Сериалы / Каналы.
                _FilterTabs(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTabs extends ConsumerWidget {
  static const _tabs = ['Все', 'Фильмы', 'Сериалы', 'Каналы'];
  static const _activeIndex = 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.activePalette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: i == _activeIndex ? palette.accentSoft : Colors.transparent,
              border: Border.all(color: i == _activeIndex ? palette.accent : palette.line),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _tabs[i].toUpperCase(),
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10,
                letterSpacing: 0.18 * 10,
                color: i == _activeIndex ? palette.accent : palette.textMute,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LeftPane extends ConsumerWidget {
  const _LeftPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchControllerProvider);
    final notifier = ref.read(searchControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchInput(query: state.query),
          const SizedBox(height: 20),
          Expanded(
            child: CyrillicKeyboard(
              onKeyPressed: notifier.onKeyPressed,
              onExitRight: () => FocusScope.of(context).focusInDirection(TraversalDirection.right),
            ),
          ),
        ],
      ),
    );
  }
}
