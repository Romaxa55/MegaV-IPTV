import 'dart:typed_data';

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';

void main() {
  // Use a memory-only ImageProvider — the actual bytes don't matter because
  // Poster wraps the Image with errorBuilder that falls back to a ColoredBox.
  // We test widget-tree structure, not image rendering.
  final transparentImage = MemoryImage(
    Uint8List.fromList(<int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature only
    ]),
  );

  group('Poster (T-Poster-1, T-Poster-2)', () {
    testWidgets('hideText: true → no Text widget for title/subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Poster(
              image: transparentImage,
              title: 'Should not appear',
              subtitle: 'Either',
              hideText: true,
            ),
          ),
        ),
      );
      expect(find.text('Should not appear'), findsNothing);
      expect(find.text('Either'), findsNothing);
    });

    testWidgets('progress: 0.6 → MvTrack widget present in tree', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Poster(image: transparentImage, progress: 0.6)),
        ),
      );
      expect(find.byType(MvTrack), findsOneWidget);
    });

    testWidgets('orientation: portrait → AspectRatio.aspectRatio is 2/3', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Poster(image: transparentImage, orientation: PosterOrientation.portrait),
          ),
        ),
      );
      final ar = tester.widget<AspectRatio>(find.byType(AspectRatio).first);
      expect(ar.aspectRatio, closeTo(2 / 3, 0.001));
    });
  });
}
