import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/home/cinematic/cinematic_remote_hint_footer.dart';

void main() {
  group('CinematicRemoteHintFooter', () {
    testWidgets('renders root key + RemoteHint atom', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CinematicRemoteHintFooter()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('cinematic-remote-hint')), findsOneWidget);
      expect(find.byType(RemoteHint), findsOneWidget);
    });

    testWidgets('IgnorePointer + ExcludeFocus prevent focus/tap capture', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CinematicRemoteHintFooter()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(IgnorePointer), findsAtLeastNWidgets(1));
      expect(find.byType(ExcludeFocus), findsAtLeastNWidgets(1));
    });

    testWidgets('const ctor reachable', (tester) async {
      // Compile-time check via const ctor invocation
      const widget = CinematicRemoteHintFooter();
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: widget)),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
