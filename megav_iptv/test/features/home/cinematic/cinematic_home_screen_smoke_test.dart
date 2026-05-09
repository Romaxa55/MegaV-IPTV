import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/home/cinematic/cinematic_home_screen.dart';

void main() {
  testWidgets(
    'CinematicHomeScreen skeleton mounts without exception and exposes root key',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CinematicHomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('cinematic-home-root')), findsOneWidget);
    },
  );
}
