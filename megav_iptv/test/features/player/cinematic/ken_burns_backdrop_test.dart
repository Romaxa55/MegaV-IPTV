import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/player/cinematic/ken_burns_backdrop.dart';

void main() {
  group('KenBurnsBackdrop', () {
    testWidgets('renders no Image when imageProvider is null', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: KenBurnsBackdrop(imageProvider: null, active: true),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('Visibility hides when active=false', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: KenBurnsBackdrop(
                imageProvider: AssetImage('assets/grain_overlay.png'),
                active: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final v = tester.widget<Visibility>(find.byType(Visibility));
      expect(v.visible, isFalse);
    });

    testWidgets('toggling active true→false→true does not throw', (tester) async {
      late StateSetter setter;
      bool active = true;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (ctx, set) {
                  setter = set;
                  return KenBurnsBackdrop(
                    imageProvider: const AssetImage('assets/grain_overlay.png'),
                    active: active,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      setter(() => active = false);
      await tester.pump();
      setter(() => active = true);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposes cleanly on unmount', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: KenBurnsBackdrop(
                imageProvider: AssetImage('assets/grain_overlay.png'),
                active: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  });
}
