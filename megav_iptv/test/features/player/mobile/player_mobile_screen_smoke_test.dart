import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/player/mobile/player_mobile_screen.dart';

Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: child,
      ),
    ),
  );
}

void main() {
  group('PlayerMobileScreen smoke', () {
    testWidgets('renders root, controls and live-dot keys', (tester) async {
      await tester.pumpWidget(_harness(child: const PlayerMobileScreen()));
      await tester.pump();

      expect(find.byKey(const Key('player-mobile-root')), findsOneWidget);
      expect(find.byKey(const Key('m-player-controls')), findsOneWidget);
      expect(find.byKey(const Key('m-live-dot')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('exposes a horizontal-swipe GestureDetector', (tester) async {
      await tester.pumpWidget(_harness(child: const PlayerMobileScreen()));
      await tester.pump();

      expect(find.byType(GestureDetector), findsAtLeastNWidgets(1));
    });

    testWidgets('mobile blur boundary — BackdropFilter is reachable',
        (tester) async {
      await tester.pumpWidget(_harness(child: const PlayerMobileScreen()));
      await tester.pump();

      expect(find.byType(BackdropFilter), findsAtLeastNWidgets(1));
    });
  });
}
