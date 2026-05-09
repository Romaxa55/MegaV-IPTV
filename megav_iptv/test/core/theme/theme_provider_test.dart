import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/theme/app_palettes.dart';
import 'package:megav_iptv/core/theme/theme_provider.dart';

void main() {
  group('themeProvider', () {
    testWidgets('initial state is noirCobalt', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _PaletteConsumer(),
          ),
        ),
      );

      // Read directly from a tester-scoped container instead of pumping a probe
      final container = ProviderScope.containerOf(
        tester.element(find.byType(_PaletteConsumer)),
      );
      expect(container.read(themeProvider), AppPaletteName.noirCobalt);
      expect(container.read(themeProvider).palette.background,
          const Color(0xFF06060A));
    });

    testWidgets('setPalette updates state and rebuilds Consumer', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _PaletteConsumer(),
          ),
        ),
      );

      // Verify initial render shows noirCobalt accent
      expect(_findContainerColor(tester),
          AppPaletteName.noirCobalt.resolve().accent);

      // Switch to crimsonReel via the public API
      final container = ProviderScope.containerOf(
        tester.element(find.byType(_PaletteConsumer)),
      );
      await container.read(themeProvider.notifier).setPalette(
            AppPaletteName.crimsonReel,
          );
      await tester.pump();

      // Consumer should now reflect crimsonReel
      expect(container.read(themeProvider), AppPaletteName.crimsonReel);
      expect(_findContainerColor(tester),
          AppPaletteName.crimsonReel.resolve().accent);
    });

    test('setPalette without PaletteStore does not throw', () async {
      // Default themeProvider has no PaletteStore — verify in-memory only
      // mode (Req 6.2) does not error.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial read triggers build()
      expect(container.read(themeProvider), AppPaletteName.noirCobalt);

      // Switching should complete without throwing
      await container.read(themeProvider.notifier).setPalette(
            AppPaletteName.pitch,
          );
      expect(container.read(themeProvider), AppPaletteName.pitch);
    });
  });
}

/// Tiny consumer that paints a Container in the active palette's accent
/// color so widget tests can verify rebuilds via the rendered tree.
class _PaletteConsumer extends ConsumerWidget {
  const _PaletteConsumer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themeProvider).palette;
    return Container(
      width: 100,
      height: 100,
      color: palette.accent,
    );
  }
}

Color _findContainerColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.byType(Container),
  );
  return (container.color)!;
}
