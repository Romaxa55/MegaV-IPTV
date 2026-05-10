import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/core/providers/providers.dart';
import 'package:megav_iptv/features/home/mobile/home_mobile_screen.dart';

Widget _harness({required Widget child, required List<Override> overrides}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: child,
      ),
    ),
  );
}

void main() {
  group('HomeMobileScreen smoke', () {
    final mockChannels = <Channel>[
      const Channel(id: 1, name: 'Hero One'),
      const Channel(id: 2, name: 'Hero Two'),
      const Channel(id: 3, name: 'Hero Three'),
      const Channel(id: 4, name: 'Tile Four'),
      const Channel(id: 5, name: 'Tile Five'),
    ];

    testWidgets('renders without exception and exposes root key',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          overrides: [
            featuredChannelsProvider.overrideWith(
              (ref) => Future.value(mockChannels),
            ),
          ],
          child: const HomeMobileScreen(),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('home-mobile-root')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overlays MTabBar at the bottom', (tester) async {
      await tester.pumpWidget(
        _harness(
          overrides: [
            featuredChannelsProvider.overrideWith(
              (ref) => Future.value(mockChannels),
            ),
          ],
          child: const HomeMobileScreen(),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('m-tab-bar')), findsOneWidget);
    });
  });
}
