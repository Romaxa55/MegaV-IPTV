import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/player/mobile/widgets/m_swipe_hint.dart';

Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('MSwipeHint', () {
    testWidgets('renders with key under RepaintBoundary', (tester) async {
      await tester.pumpWidget(_harness(child: const MSwipeHint()));
      // Single pump only — controller is on `repeat`, `pumpAndSettle` would
      // loop forever.
      await tester.pump();

      expect(find.byKey(const Key('m-swipe-hint')), findsOneWidget);

      final keyed = find.ancestor(
        of: find.byType(FadeTransition),
        matching: find.byKey(const Key('m-swipe-hint')),
      );
      expect(keyed, findsOneWidget);
    });
  });
}
