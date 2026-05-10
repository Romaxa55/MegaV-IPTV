import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/features/home/mobile/widgets/m_hero_card.dart';

Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  group('MHeroCard', () {
    testWidgets('renders key + title + Смотреть button', (tester) async {
      final channels = const [
        Channel(id: 1, name: 'Hero One'),
        Channel(id: 2, name: 'Hero Two'),
        Channel(id: 3, name: 'Hero Three'),
      ];

      await tester.pumpWidget(_harness(child: MHeroCard(channels: channels)));
      await tester.pump();

      expect(find.byKey(const Key('m-hero-card')), findsOneWidget);
      expect(find.text('Hero One'), findsOneWidget);
      expect(find.text('Смотреть'), findsOneWidget);
    });

    testWidgets('renders nothing when channels is empty', (tester) async {
      await tester.pumpWidget(
        _harness(child: const MHeroCard(channels: <Channel>[])),
      );
      await tester.pump();

      expect(find.byKey(const Key('m-hero-card')), findsNothing);
      expect(find.text('Смотреть'), findsNothing);
    });
  });
}
