import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../state/active_mobile_tab_provider.dart';

/// Mobile bottom tab bar with frosted-glass background.
///
/// Renders 5 tabs (Home / TV / Search / Guide / Profile per Req 5.2),
/// reads the active index from [activeMobileTabProvider] (Req 5.3) and
/// dispatches selection mutations on tap (Req 5.6).
///
/// Visual treatment is a translucent surface behind a [BackdropFilter]
/// (Req 5.4). Raw `BackdropFilter` / `ImageFilter.blur` are PERMITTED here
/// because this widget lives under `lib/features/mobile/` — the mobile blur
/// boundary (Req 11.1).
///
/// Bottom padding adds the device's `viewPadding.bottom` so the bar clears
/// the home indicator on iOS and gesture nav on Android (Req 5.5).
class MTabBar extends ConsumerWidget {
  const MTabBar({super.key});

  /// 5-tab definition, fixed order — index → (icon, label).
  static const List<(IconData, String)> _tabs = [
    (Icons.home_outlined, 'Дом'),
    (Icons.tv_outlined, 'ТВ'),
    (Icons.search, 'Поиск'),
    (Icons.menu_book_outlined, 'Гид'),
    (Icons.person_outline, 'Профиль'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIdx = ref.watch(activeMobileTabProvider);
    final viewPaddingBottom = MediaQuery.viewPaddingOf(context).bottom;
    return ClipRRect(
      key: const Key('m-tab-bar'),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          color: AppColors.activePalette.surface2.withValues(alpha: 0.6),
          padding: EdgeInsets.only(bottom: viewPaddingBottom + 8, top: 8, left: 16, right: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final (icon, label) = _tabs[i];
              return MTab(
                icon: icon,
                label: label,
                active: i == activeIdx,
                onTap: () => ref.read(activeMobileTabProvider.notifier).state = i,
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Single tab cell rendered by [MTabBar].
///
/// Public (not `_`-prefixed) so widget tests can assert
/// `find.byType(MTab)` finds 5 tabs.
class MTab extends StatelessWidget {
  const MTab({super.key, required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.activePalette;
    final color = active ? palette.accent : palette.textDim;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
