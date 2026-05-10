import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/player/mobile/widgets/m_player_controls.dart';

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
  group('MPlayerControls', () {
    testWidgets('renders with key and BackdropFilter (mobile blur boundary)',
        (tester) async {
      await tester.pumpWidget(_harness(child: const MPlayerControls()));
      await tester.pump();

      expect(find.byKey(const Key('m-player-controls')), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });
}
