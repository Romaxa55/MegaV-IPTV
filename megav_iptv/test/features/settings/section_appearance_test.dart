import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/theme/app_palettes.dart';
import 'package:megav_iptv/core/theme/theme_provider.dart';
import 'package:megav_iptv/features/settings/widgets/palette_swatches.dart';
import 'package:megav_iptv/features/settings/widgets/section_appearance.dart';

Widget _harness({required Widget child, List<Override> overrides = const []}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ProviderScope(
      overrides: overrides,
      child: ScreenUtilInit(
        designSize: const Size(1920, 1080),
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: child),
        ),
      ),
    ),
  );
}

void main() {
  group('SectionAppearance', () {
    testWidgets('renders palette swatches and font picker', (tester) async {
      await tester.pumpWidget(_harness(child: const SectionAppearance()));
      await tester.pumpAndSettle();

      expect(find.byType(PaletteSwatches), findsOneWidget);
      expect(find.text('Cinematic'), findsOneWidget);
    });

    testWidgets('tapping a non-active swatch updates themeProvider', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1920, 1080)),
          child: ProviderScope(
            child: Consumer(
              builder: (ctx, ref, _) {
                container = ProviderScope.containerOf(ctx);
                return ScreenUtilInit(
                  designSize: const Size(1920, 1080),
                  builder: (ctx, _) => const MaterialApp(
                    debugShowCheckedModeBanner: false,
                    home: Scaffold(body: SectionAppearance()),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default starts at noirCobalt.
      expect(container.read(themeProvider), AppPaletteName.noirCobalt);

      // Tap the first swatch (plum) — different from the active default.
      final gestures = find.descendant(
        of: find.byType(PaletteSwatches),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(gestures.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(container.read(themeProvider), AppPaletteName.plum);
    });
  });
}
