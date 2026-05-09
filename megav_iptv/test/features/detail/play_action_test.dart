import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/core/providers/providers.dart';
import 'package:megav_iptv/features/detail/detail_screen.dart';

void main() {
  testWidgets('Tap on Play navigates to /player', (tester) async {
    const testChannelId = 1;
    final testChannel = Channel(id: testChannelId, name: 'Test', groupTitle: 'X');
    var playerOpened = false;

    final router = GoRouter(
      initialLocation: '/channel/1',
      routes: [
        GoRoute(
          path: '/channel/:id',
          builder: (context, state) => const DetailScreen(channelId: testChannelId),
        ),
        GoRoute(
          path: '/player',
          builder: (context, state) {
            playerOpened = true;
            return const Scaffold(body: Text('Player Stub'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1920, 1080)),
        child: ProviderScope(
          overrides: [
            featuredChannelsProvider.overrideWith((ref) => Future.value([testChannel])),
          ],
          child: ScreenUtilInit(
            designSize: const Size(1920, 1080),
            builder: (context, _) => MaterialApp.router(
              debugShowCheckedModeBanner: false,
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Смотреть'));
    await tester.pumpAndSettle();

    expect(playerOpened, isTrue);
  });
}
