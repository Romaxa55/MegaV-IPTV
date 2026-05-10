import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/core/providers/providers.dart';
import 'package:megav_iptv/features/detail/mobile/detail_mobile_screen.dart';

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
  group('DetailMobileScreen smoke', () {
    final mockChannels = <Channel>[
      const Channel(id: 42, name: 'Detail Channel', groupTitle: 'News'),
      const Channel(id: 43, name: 'Other'),
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
          child: const DetailMobileScreen(channelId: 42),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('detail-mobile-root')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('title text uses headline-equivalent size (22)',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          overrides: [
            featuredChannelsProvider.overrideWith(
              (ref) => Future.value(mockChannels),
            ),
          ],
          child: const DetailMobileScreen(channelId: 42),
        ),
      );
      await tester.pump();

      final titleFinder = find.text('Detail Channel');
      expect(titleFinder, findsOneWidget);
      final titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.style?.fontSize, 22);
      expect(titleWidget.style?.fontWeight, FontWeight.w600);
    });
  });
}
