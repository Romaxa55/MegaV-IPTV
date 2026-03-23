import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/player/player_screen.dart';
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
        GoRoute(path: '/player', builder: (context, state) => const PlayerScreen()),
        GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      ],
    ),
  ],
);

class MegaVApp extends StatelessWidget {
  const MegaVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1920, 1080),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'MegaV IPTV',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          routerConfig: _router,
        );
      },
    );
  }
}
