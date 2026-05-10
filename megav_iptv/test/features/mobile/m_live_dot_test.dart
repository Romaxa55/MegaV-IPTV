import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/mobile/widgets/m_live_dot.dart';

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
  group('MLiveDot', () {
    testWidgets('renders with key and AnimatedBuilder under RepaintBoundary',
        (tester) async {
      await tester.pumpWidget(_harness(child: const MLiveDot()));
      // Single pump only — `pumpAndSettle` would loop forever because the
      // controller is on `repeat`.
      await tester.pump();

      expect(find.byKey(const Key('m-live-dot')), findsOneWidget);

      final ancestors = find.ancestor(
        of: find.byType(AnimatedBuilder),
        matching: find.byType(RepaintBoundary),
      );
      // The RepaintBoundary that we explicitly added is one of potentially
      // multiple ancestors (Material wraps things internally), but ours is
      // the one keyed `m-live-dot` and is the closest ancestor.
      expect(ancestors, findsAtLeastNWidgets(1));

      // Specifically verify our keyed RepaintBoundary is in the ancestor chain.
      final keyed = find.ancestor(
        of: find.byType(AnimatedBuilder),
        matching: find.byKey(const Key('m-live-dot')),
      );
      expect(keyed, findsOneWidget);
    });
  });
}
