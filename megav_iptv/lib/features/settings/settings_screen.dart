import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/perf/perf_safe_widgets.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/section_about.dart';
import 'widgets/section_appearance.dart';
import 'widgets/section_network.dart';
import 'widgets/section_performance.dart';
import 'widgets/section_player.dart';
import 'widgets/section_reset.dart';
import 'widgets/sidebar_nav.dart';

/// Settings shell — left sidebar (6 items) + animated body switcher.
///
/// Sections (index → widget):
///  0 — Тема (palette + font pair)
///  1 — Плеер (decoder pickers + ABR/passthrough)
///  2 — Сеть (backend URL + cache reset)
///  3 — Производительность (perf metrics + toggles)
///  4 — О приложении (version + device info)
///  5 — Сброс (reset palette + decoder)
///
/// Performance contract: no per-frame gaussian blur layers, no
/// shader masks, and no `BoxShadow.blurRadius > 12` (Req 12.1, 12.2, 12.3).
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
      body: Stack(
        children: [
          SafeFilmGrain(
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
    );
  }
}
