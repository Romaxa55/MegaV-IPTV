import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/core/providers/providers.dart';
import 'package:megav_iptv/features/home/cinematic/cinematic_home_screen.dart';
import 'package:megav_iptv/features/home/editorial/editorial_home_screen.dart';
import 'package:megav_iptv/features/home/home_screen.dart';
import 'package:megav_iptv/features/home/home_variant_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coexistence tests — phase 6.2 of `home-editorial-redesign`.
///
/// These tests verify that the three Home variants (legacy, cinematic,
/// editorial) live side-by-side without leaking root-`Key` collisions and
/// that the persisted [HomeVariant] selection round-trips through
/// [SharedPreferences].
///
/// Tests 1-3 mount each screen in isolation (a full GoRouter pump is too
/// flaky for unit tests). Test 4 is the true persistence guarantee.
Widget _wrap(Widget screen, SharedPreferences prefs, {List<Override> extra = const []}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...extra,
      ],
      child: ScreenUtilInit(
        designSize: const Size(1920, 1080),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp(home: screen);
        },
      ),
    ),
  );
}

void main() {
  testWidgets(
    'editorial variant: editorial-home-root present, cinematic-home-root absent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        _wrap(
          const EditorialHomeScreen(),
          prefs,
          extra: [
            featuredChannelsProvider.overrideWith((ref) async => const <Channel>[]),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('editorial-home-root')), findsOneWidget);
      expect(find.byKey(const Key('cinematic-home-root')), findsNothing);
    },
  );

  testWidgets(
    'cinematic variant: cinematic-home-root present, editorial-home-root absent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(_wrap(const CinematicHomeScreen(), prefs));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('cinematic-home-root')), findsOneWidget);
      expect(find.byKey(const Key('editorial-home-root')), findsNothing);
    },
  );

  test(
    'legacy variant: HomeVariant.legacy is selectable and persists '
    'side-by-side with the cinematic / editorial enums',
    () async {
      // The legacy [HomeScreen] requires a full network stack
      // (`featuredNowPlayingProvider`, `cinemaCategoriesProvider`,
      // `moviesNotifierProvider`) to render — pumping it here would test
      // those upstream providers, not coexistence. Instead we verify the
      // routing-level invariant: the [HomeVariant.legacy] enum value
      // round-trips through [SharedPreferences] without aliasing the
      // other two variants.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      final notifier = HomeVariantNotifier(prefs);
      await notifier.set(HomeVariant.legacy);

      // Re-hydrate from the same prefs and confirm the stored enum is
      // exactly `legacy` — not `editorial`, not `cinematic`.
      final rehydrated = HomeVariantNotifier(prefs);
      expect(rehydrated.state, HomeVariant.legacy);
      expect(rehydrated.state, isNot(HomeVariant.editorial));
      expect(rehydrated.state, isNot(HomeVariant.cinematic));

      // The HomeScreen import must still resolve — guards against
      // accidental removal of the legacy entry-point class.
      expect(HomeScreen, isNotNull);
    },
  );

  test(
    'persistence: HomeVariantNotifier round-trips selection through SharedPreferences',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      // First instance — set state to editorial and persist.
      final notifierA = HomeVariantNotifier(prefs);
      expect(notifierA.state, kHomeVariantDefault);
      await notifierA.set(HomeVariant.editorial);
      expect(notifierA.state, HomeVariant.editorial);

      // Second instance reading the same prefs must hydrate to editorial.
      final notifierB = HomeVariantNotifier(prefs);
      expect(notifierB.state, HomeVariant.editorial);

      // Switch to legacy and verify the same hydration contract.
      await notifierB.set(HomeVariant.legacy);
      final notifierC = HomeVariantNotifier(prefs);
      expect(notifierC.state, HomeVariant.legacy);
    },
  );
}
