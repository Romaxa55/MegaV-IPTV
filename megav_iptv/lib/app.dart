import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/detail/detail_root.dart';
import 'features/detail/providers/detail_arguments.dart';
import 'features/epg/epg_screen.dart';
import 'features/home/editorial/editorial_home_screen.dart';
import 'features/home/home_root.dart';
import 'features/player/player_root.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';

Future<void> _onRootBackPressed(BuildContext context) async {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
    return;
  }
  if (!context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Выйти из приложения?'),
        content: const Text('Вы точно хотите выйти?'),
        actions: [FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('OK'))],
      );
    },
  );
  if (confirmed == true && context.mounted) {
    await SystemNavigator.pop();
  }
}

final _router = GoRouter(
  // home-unified-grid-scroll (Wave 5): Cinematic — основной экран.
  // Legacy /home остаётся доступен по explicit path для regression
  // и debug switcher, но новые сессии запускают cinematic.
  initialLocation: '/home-cinematic',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            unawaited(_onRootBackPressed(context));
          },
          child: child,
        );
      },
      routes: [
        GoRoute(path: '/', redirect: (context, state) => '/home-cinematic'),
        // Legacy /home → cinematic. HomeScreen widget удалён в Wave 5
        // (home-unified-grid-scroll). Любая старая ссылка переходит
        // на новый главный экран.
        GoRoute(path: '/home', redirect: (context, state) => '/home-cinematic'),
        GoRoute(path: '/home-cinematic', builder: (context, state) => const HomeRootScreen()),
        GoRoute(path: '/home-editorial', builder: (context, state) => const EditorialHomeScreen()),
        GoRoute(
          path: '/channel/:id',
          builder: (context, state) {
            final idStr = state.pathParameters['id'] ?? '';
            final id = int.tryParse(idStr) ?? -1;
            final args = state.extra is DetailArgs ? state.extra as DetailArgs : null;
            return DetailRootScreen(channelId: id, args: args);
          },
        ),
        GoRoute(path: '/player', builder: (context, state) => const PlayerRootScreen()),
        GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
        GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        GoRoute(path: '/epg', builder: (context, state) => const EpgScreen()),
      ],
    ),
  ],
);

/// Wraps the app tree in a [ResponsiveScaledBox] whose virtual design
/// width depends on the active breakpoint:
/// * `4K`     → 1920 (TV native, no scaling)
/// * `DESKTOP`→ 1280 (mid-density mid-window)
/// * `TABLET` → 1024
/// * `MOBILE` → no wrapping (native px so touch targets stay 48dp)
///
/// Reads [ResponsiveBreakpoints.of] which the parent
/// [ResponsiveBreakpoints.builder] supplies. The atoms designed against
/// the 1920×1080 spec stay pixel-perfect at every breakpoint without any
/// per-widget LayoutBuilder.
class _AdaptiveScaledRoot extends StatelessWidget {
  const _AdaptiveScaledRoot({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bp = ResponsiveBreakpoints.of(context);
    if (bp.isMobile) return child;
    final double designWidth = bp.equals('4K')
        ? 1920
        : bp.equals(DESKTOP)
        ? 1280
        : 1024; // TABLET fallback
    return ResponsiveScaledBox(width: designWidth, child: child);
  }
}

class _DebugRouteSwitcher extends StatelessWidget {
  const _DebugRouteSwitcher();

  static const _routes = <(String, String)>[
    ('/home-cinematic', 'Cinematic'),
    ('/home-editorial', 'Editorial'),
    ('/epg', 'EPG'),
    ('/search', 'Search'),
    ('/settings', 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Wrap(
          spacing: 4,
          children: [
            for (final (path, label) in _routes)
              FilledButton(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                onPressed: () => _router.go(path),
                child: Text(label),
              ),
          ],
        ),
      ),
    );
  }
}

class MegaVApp extends ConsumerWidget {
  const MegaVApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paletteName = ref.watch(themeProvider);
    return ScreenUtilInit(
      designSize: const Size(1920, 1080),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'MegaV IPTV',
          debugShowCheckedModeBanner: false,
          theme: appTheme(paletteName.palette),
          routerConfig: _router,
          builder: (context, child) {
            // Responsive auto-scaling: tree always renders as if viewport
            // matches the breakpoint name's design width, then Flutter scales
            // to the actual window. Atoms designed for 1920×1080 stay
            // pixel-perfect on any size without manual LayoutBuilder.
            return ResponsiveBreakpoints.builder(
              breakpoints: const [
                Breakpoint(start: 0, end: 599, name: MOBILE),
                Breakpoint(start: 600, end: 1023, name: TABLET),
                Breakpoint(start: 1024, end: 1919, name: DESKTOP),
                Breakpoint(start: 1920, end: double.infinity, name: '4K'),
              ],
              // Legacy /home uses the default WidgetsApp focus traversal
              // (no custom Shortcuts/Actions) and arrow-key navigation works
              // correctly. Custom global Shortcuts overrode the
              // FocusTraversalGroup behaviour inside `cinema_row` rails on
              // the new screens, so we removed them.
              child: _AdaptiveScaledRoot(
                child: Stack(
                  children: [
                    ?child,
                    const Positioned(top: 8, right: 8, child: _DebugRouteSwitcher()),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
