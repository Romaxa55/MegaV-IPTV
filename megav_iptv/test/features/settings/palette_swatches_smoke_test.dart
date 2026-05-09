import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/theme/app_palettes.dart';
import 'package:megav_iptv/features/settings/widgets/palette_swatches.dart';

Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(1920, 1080),
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
        ),
      ),
    ),
  );
}

void main() {
  group('PaletteSwatches', () {
    testWidgets('renders one swatch per AppPaletteName', (tester) async {
      await tester.pumpWidget(_harness(child: const PaletteSwatches()));
      await tester.pumpAndSettle();

      // 6 entries in AppPaletteName.values → 6 swatches → at least 6 GestureDetectors.
      expect(AppPaletteName.values.length, 6);

      // Each swatch is a tappable GestureDetector. Filter to direct children of
      // the swatches grid via finding tap-targets inside the PaletteSwatches.
      final gestures = find.descendant(
        of: find.byType(PaletteSwatches),
        matching: find.byType(GestureDetector),
      );
      expect(gestures, findsNWidgets(6));
    });
  });
}
