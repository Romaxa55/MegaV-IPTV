import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/detail/detail_screen.dart';
import 'features/detail/providers/detail_arguments.dart';
import 'features/epg/epg_screen.dart';
import 'features/home/cinematic/cinematic_home_screen.dart';
import 'features/home/editorial/editorial_home_screen.dart';
import 'features/home/home_screen.dart';
import 'features/player/player_screen.dart';
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
  initialLocation: '/home',
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
        GoRoute(path: '/', redirect: (context, state) => '/home'),
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/home-cinematic', builder: (context, state) => const CinematicHomeScreen()),
        GoRoute(path: '/home-editorial', builder: (context, state) => const EditorialHomeScreen()),
        GoRoute(
          path: '/channel/:id',
          builder: (context, state) {
            final idStr = state.pathParameters['id'] ?? '';
            final id = int.tryParse(idStr) ?? -1;
            final args = state.extra is DetailArgs ? state.extra as DetailArgs : null;
            return DetailScreen(channelId: id, args: args);
          },
        ),
        GoRoute(path: '/player', builder: (context, state) => const PlayerScreen()),
        GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
        GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        GoRoute(path: '/epg', builder: (context, state) => const EpgScreen()),
      ],
    ),
  ],
);

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
        );
      },
    );
  }
}
