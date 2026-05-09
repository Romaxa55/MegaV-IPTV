import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';

void main() {
  group('atoms smoke (T-1..T-13)', () {
    testWidgets('Brand renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Brand())));
      expect(find.byType(Brand), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Chip renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Chip(label: 'TEST'))));
      expect(find.byType(Chip), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GenreTabs renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GenreTabs(labels: ['A', 'B'], activeIndex: 0))),
      );
      expect(find.byType(GenreTabs), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MMLogo renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MMLogo())));
      expect(find.byType(MMLogo), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MvButton.primary renders without crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MvButton.primary(label: 'OK', onPressed: () {}))),
      );
      expect(find.byType(MvButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MvIconButton renders without crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MvIconButton(icon: const Icon(Icons.star), onPressed: () {})),
        ),
      );
      expect(find.byType(MvIconButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MvKey renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MvKey(glyph: 'OK'))));
      expect(find.byType(MvKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MvStrip renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MvStrip())));
      expect(find.byType(MvStrip), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MvTrack renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox(width: 200, child: MvTrack(progress: 0.5)))),
      );
      expect(find.byType(MvTrack), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Poster renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Poster(image: AssetImage('assets/grain_overlay.png'))),
        ),
      );
      expect(find.byType(Poster), findsOneWidget);
      // Image may emit error in test env (asset bundle differs); errorBuilder
      // covers the fallback. We only assert the Poster widget itself mounts.
    });

    testWidgets('RemoteHint renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RemoteHint(
              hints: [
                RemoteHintEntry(glyph: '↑', label: 'Up'),
                RemoteHintEntry(glyph: 'OK', label: 'Confirm'),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(RemoteHint), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SectionTitle renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SectionTitle(title: 'Movies'))),
      );
      expect(find.byType(SectionTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('StatusBar renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StatusBar(city: 'Moscow', tempC: 5))),
      );
      expect(find.byType(StatusBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
