import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/player/decoder_config.dart';
import 'package:megav_iptv/core/providers/providers.dart';
import 'package:megav_iptv/features/settings/settings_screen.dart';
import 'package:megav_iptv/features/settings/widgets/section_player.dart';
import 'package:megav_iptv/features/settings/widgets/sidebar_nav.dart';

Widget _harness({required Widget child, List<Override> overrides = const []}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ProviderScope(
      overrides: overrides,
      child: ScreenUtilInit(
        designSize: const Size(1920, 1080),
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: child,
        ),
      ),
    ),
  );
}

void main() {
  group('SettingsScreen', () {
    testWidgets('renders SidebarNav with 6 items', (tester) async {
      await tester.pumpWidget(
        _harness(
          overrides: [
            decoderConfigProvider.overrideWith((ref) => const DecoderConfig()),
          ],
          child: const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SidebarNav), findsOneWidget);
      // All 6 sidebar labels visible.
      expect(find.text('Тема'), findsAtLeastNWidgets(1));
      expect(find.text('Плеер'), findsAtLeastNWidgets(1));
      expect(find.text('Сеть'), findsAtLeastNWidgets(1));
      expect(find.text('Производительность'), findsAtLeastNWidgets(1));
      expect(find.text('О приложении'), findsAtLeastNWidgets(1));
      expect(find.text('Сброс'), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping Плеер switches body to SectionPlayer', (tester) async {
      await tester.pumpWidget(
        _harness(
          overrides: [
            decoderConfigProvider.overrideWith((ref) => const DecoderConfig()),
          ],
          child: const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Плеер'));
      await tester.pumpAndSettle();

      expect(find.byType(SectionPlayer), findsOneWidget);
    });

    testWidgets('no BackdropFilter anywhere in the widget tree', (tester) async {
      await tester.pumpWidget(
        _harness(
          overrides: [
            decoderConfigProvider.overrideWith((ref) => const DecoderConfig()),
          ],
          child: const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ImageFiltered), findsNothing);
    });
  });
}
