import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/api/api_client.dart';
import 'package:megav_iptv/core/playlist/models/now_playing.dart';
import 'package:megav_iptv/core/providers/providers.dart';
import 'package:megav_iptv/features/home/cinematic/cinematic_home_screen.dart';
import 'package:megav_iptv/features/home/home_variant_provider.dart' show sharedPreferencesProvider;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'CinematicHomeScreen mounts without exception and exposes all component keys',
    (tester) async {
      // Pin to 1920×1080 so ScreenUtil initialises correctly and
      // off-screen items are reachable via skipOffstage: false.
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // onboarding-remote-cheatsheet (Wave 6) — onboardingShownProvider
      // depends on sharedPreferencesProvider; stub it with mock prefs
      // (onboarding-shown = true to skip overlay in the smoke test).
      SharedPreferences.setMockInitialValues({'onboarding-shown': true});
      final prefs = await SharedPreferences.getInstance();

      // Stub providers so no real HTTP is attempted.
      const mockFeatured = <NowPlayingItem>[
        NowPlayingItem(channelId: 1, channelName: 'Channel One', groupTitle: 'Кино'),
        NowPlayingItem(channelId: 2, channelName: 'Channel Two', groupTitle: 'Кино'),
        NowPlayingItem(channelId: 3, channelName: 'Channel Three', groupTitle: 'Спорт'),
        NowPlayingItem(channelId: 4, channelName: 'Channel Four', groupTitle: 'Новости'),
        NowPlayingItem(channelId: 5, channelName: 'Channel Five', groupTitle: 'Кино'),
        NowPlayingItem(channelId: 6, channelName: 'Channel Six', groupTitle: 'Музыка'),
        NowPlayingItem(channelId: 7, channelName: 'Channel Seven', groupTitle: 'Кино'),
      ];

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1920, 1080)),
          child: ProviderScope(
            overrides: [
              featuredNowPlayingProvider.overrideWith((_) async => mockFeatured),
              cinemaCategoriesProvider.overrideWith((_) async => const <CinemaCategory>[]),
              moviesNotifierProvider.overrideWith((_) => MoviesNotifier(_StubApiClient())),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: ScreenUtilInit(
              designSize: const Size(1920, 1080),
              minTextAdapt: true,
              splitScreenMode: true,
              builder: (context, _) =>
                  const MaterialApp(home: CinematicHomeScreen()),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      // Root container key.
      expect(find.byKey(const Key('cinematic-home-root')), findsOneWidget);
      // Hero block — expanded by default (hero is focused on mount).
      expect(find.byKey(const Key('cinematic-hero')), findsOneWidget);
      // Remote hint footer at the bottom.
      expect(
        find.byKey(const Key('cinematic-remote-hint'), skipOffstage: false),
        findsOneWidget,
      );
      // Genre tabs must NOT be present (removed per UX decision).
      expect(find.byKey(const Key('cinematic-genre-tabs')), findsNothing);
    },
  );
}

// ---------------------------------------------------------------------------
// Stub helpers — no real HTTP calls.
// ---------------------------------------------------------------------------

/// [ApiClient] that returns empty collections for every method. Used to
/// satisfy [MoviesNotifier]'s constructor so no real HTTP is attempted.
class _StubApiClient extends ApiClient {
  _StubApiClient() : super(baseUrl: 'http://localhost');

  @override
  Future<({List<NowPlayingItem> items, int total})> getMoviesNowPlaying({
    int limit = 20,
    int offset = 0,
  }) async => (items: <NowPlayingItem>[], total: 0);
}
