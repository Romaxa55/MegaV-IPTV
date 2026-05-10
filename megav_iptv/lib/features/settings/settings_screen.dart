import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/perf/perf_safe_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/megav_text_styles.dart';
import 'widgets/section_about.dart';
import 'widgets/section_appearance.dart';
import 'widgets/section_network.dart';
import 'widgets/section_performance.dart';
import 'widgets/section_player.dart';
import 'widgets/section_reset.dart';
import 'widgets/sidebar_nav.dart';

/// Settings shell — header + (left sidebar + animated body).
///
/// JSX reference (`settings-v2.jsx` ScreenSettingsV2):
/// ```jsx
/// HEADER: padding "32px 56px 28px", borderBottom "1px solid var(--line)".
///   eyebrow: mono 10sp "НАСТРОЙКИ · MEGAV IPTV".
///   title: display w600 56sp "Под" + dim w400 "себя".
/// BODY: gridTemplateColumns "300px 1fr".
///   Sidebar: width 300, borderRight, padding "32px 0".
///   Content: padding "32px 56px 56px".
/// ```
///
/// Performance contract: no per-frame gaussian blur, no shader masks,
/// no BoxShadow.blurRadius > 12 (Req 12.1–12.3).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedIndex = 0;
  final FocusNode _bodyFocus = FocusNode(debugLabel: 'SettingsBody');

  @override
  void dispose() {
    _bodyFocus.dispose();
    super.dispose();
  }

  Widget _bodyForIndex(int i) {
    switch (i) {
      case 0:
        return const SectionAppearance();
      case 1:
        return const SectionPlayer();
      case 2:
        return const SectionNetwork();
      case 3:
        return const SectionPerformance();
      case 4:
        return const SectionAbout();
      case 5:
        return const SectionReset();
      default:
        return const SectionAppearance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.activePalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeFilmGrain(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────
            _SettingsHeader(),
            // ── Body: sidebar + content ──────────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SidebarNav(
                    selectedIndex: _selectedIndex,
                    onSelected: (i) => setState(() => _selectedIndex = i),
                    onTraverseRight: () => _bodyFocus.requestFocus(),
                  ),
                  Expanded(
                    child: Focus(
                      focusNode: _bodyFocus,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: KeyedSubtree(key: ValueKey<int>(_selectedIndex), child: _bodyForIndex(_selectedIndex)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings screen header — eyebrow + display title.
///
/// JSX: `padding "32px 56px 28px"`, `borderBottom "1px solid var(--line)"`.
/// Title: display w600 56sp "Под" + dim w400 "себя".
class _SettingsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final palette = AppColors.activePalette;

    final eyebrowStyle = (styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 10,
      letterSpacing: 0.22 * 10,
      color: palette.textMute,
    );
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
        padding: const EdgeInsets.fromLTRB(56, 32, 56, 28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('НАСТРОЙКИ · MEGAV IPTV', style: eyebrowStyle),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(text: 'Под ', style: titleStyle),
                      TextSpan(text: 'себя', style: dimStyle),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Build info — JSX: mono 10sp, textMute.
            Flexible(child: _BuildInfo(eyebrowStyle: eyebrowStyle)),
          ],
        ),
      ),
    );
  }
}

class _BuildInfo extends StatelessWidget {
  const _BuildInfo({required this.eyebrowStyle});
  final TextStyle eyebrowStyle;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.activePalette;
    final dimStyle = eyebrowStyle.copyWith(color: palette.textDim);
    final textStyle = eyebrowStyle.copyWith(color: palette.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              TextSpan(text: 'сборка ', style: dimStyle),
              TextSpan(text: '2.6.0', style: textStyle),
            ],
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              TextSpan(text: 'flutter ', style: dimStyle),
              TextSpan(text: '3.x · Impeller', style: textStyle),
            ],
          ),
        ),
      ],
    );
  }
}
