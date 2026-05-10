import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/core/providers/providers.dart';
import 'package:megav_iptv/features/home/editorial/editorial_home_screen.dart';
import 'package:megav_iptv/features/home/home_variant_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke test for the wired-up `EditorialHomeScreen` (Phase 6.1).
///
/// Mounts the screen with a mock list of ≥3 channels so the hero, both
/// side cards and the bento grid all render. Asserts every root key
/// exposed by the editorial atoms so accidental removal of any key (or
/// rename of any composing widget) trips this test immediately.
void main() {
  testWidgets(
    'EditorialHomeScreen mounts every component when provider yields ≥4 channels',
    (tester) async {
      // The editorial layout is designed for a 1920×1080 TV viewport.
      // Default Flutter test surface is 800×600 — too narrow for the hero
      // meta column to fit and tall enough to demand infinite-height
      // children of the unbounded ListView slot. Pin the surface to the
      // production design size so the test asserts what real devices see.
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      final mockChannels = <Channel>[
        const Channel(id: 1, name: 'Hero Channel', groupTitle: 'Кино'),
        const Channel(id: 2, name: 'Next Channel', groupTitle: 'Кино'),
        const Channel(id: 3, name: 'Featured Channel', groupTitle: 'Сериалы'),
        const Channel(id: 4, name: 'Bento One', groupTitle: 'Кино'),
        const Channel(id: 5, name: 'Bento Two', groupTitle: 'Кино'),
      ];

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1920, 1080)),
          child: ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              featuredChannelsProvider.overrideWith((ref) async => mockChannels),
            ],
            child: ScreenUtilInit(
              designSize: const Size(1920, 1080),
              minTextAdapt: true,
              splitScreenMode: true,
              builder: (context, child) {
                return const MaterialApp(home: EditorialHomeScreen());
              },
            ),
          ),
        ),
      );

      // Two pumps: mount + provider future settle. We avoid pumpAndSettle
      // to keep the test independent of any future animation work.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);

      // Root key — owned by `EditorialHomeScreen` itself.
      expect(find.byKey(const Key('editorial-home-root')), findsOneWidget);

      // Above-the-fold chrome — Brand header, masthead, hero.
      expect(find.byKey(const Key('editorial-brand-header')), findsOneWidget);
      expect(find.byKey(const Key('editorial-masthead')), findsOneWidget);
      expect(find.byKey(const Key('editorial-hero')), findsOneWidget);
      expect(find.byKey(const Key('editorial-genre-tabs')), findsOneWidget);

      // Below-the-fold sections may be offstage in the default test
      // viewport — assert structural mount with skipOffstage: false.
      expect(
        find.byKey(const Key('editorial-bento-grid'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('editorial-film-reel-strip'), skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'EditorialHomeScreen still mounts root + chrome when channels list is empty',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1920, 1080)),
          child: ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              featuredChannelsProvider.overrideWith((ref) async => const <Channel>[]),
            ],
            child: ScreenUtilInit(
              designSize: const Size(1920, 1080),
              minTextAdapt: true,
              splitScreenMode: true,
              builder: (context, child) {
                return const MaterialApp(home: EditorialHomeScreen());
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('editorial-home-root')), findsOneWidget);
      // Chrome that does NOT depend on bento cells must still mount.
      expect(find.byKey(const Key('editorial-brand-header')), findsOneWidget);
      expect(find.byKey(const Key('editorial-masthead')), findsOneWidget);
      expect(find.byKey(const Key('editorial-hero')), findsOneWidget);
      expect(
        find.byKey(const Key('editorial-film-reel-strip'), skipOffstage: false),
        findsOneWidget,
      );
      // Bento grid is conditional on cells — must NOT render when empty.
      expect(find.byKey(const Key('editorial-bento-grid')), findsNothing);
    },
  );
}
