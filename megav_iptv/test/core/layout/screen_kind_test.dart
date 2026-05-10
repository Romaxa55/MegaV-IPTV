import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/layout/screen_kind.dart';

/// Pumps a widget that captures `screenKindOf(context)` under a synthetic
/// MediaQuery viewport of [width] x [height] and returns the resolved kind.
Future<ScreenKind> _resolveKind(WidgetTester tester, double width, double height) async {
  late ScreenKind resolved;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      child: Builder(
        builder: (context) {
          resolved = screenKindOf(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return resolved;
}

void main() {
  group('screenKindOf', () {
    testWidgets('390x844 (phone) → mobile', (tester) async {
      expect(await _resolveKind(tester, 390, 844), ScreenKind.mobile);
    });

    testWidgets('800x1024 (tablet) → tablet', (tester) async {
      expect(await _resolveKind(tester, 800, 1024), ScreenKind.tablet);
    });

    testWidgets('1920x1080 (tv) → tv', (tester) async {
      expect(await _resolveKind(tester, 1920, 1080), ScreenKind.tv);
    });

    testWidgets('boundary: 600 → tablet, 1280 → tv', (tester) async {
      // width == 600 fails `< 600`, hits `< 1280` → tablet.
      expect(await _resolveKind(tester, 600, 800), ScreenKind.tablet);
      // width == 1280 fails both lower checks → tv.
      expect(await _resolveKind(tester, 1280, 800), ScreenKind.tv);
    });
  });
}
