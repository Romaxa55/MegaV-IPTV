import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/now_playing.dart';
import 'package:megav_iptv/core/providers/providers.dart';
import 'package:megav_iptv/features/home/cinematic/cinematic_home_screen.dart';

void main() {
  testWidgets(
    'CinematicHomeScreen mounts without exception and exposes all 6 component keys',
    (tester) async {
      // Pin to 1920×1080 so ScreenUtil initialises correctly and
      // off-screen rail tiles are reachable via skipOffstage: false.
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
              moviesNotifierProvider.overrideWith((_) => _StubMoviesNotifier()),
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
      expect(find.byKey(const Key('cinematic-home-root')), findsOneWidget);
      expect(find.byKey(const Key('cinematic-genre-tabs')), findsOneWidget);
      expect(find.byKey(const Key('cinematic-hero')), findsOneWidget);
      // Below-the-fold items may be offstage in a constrained viewport.
      expect(find.byKey(const Key('cinematic-dual-rail-landscape'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const Key('cinematic-live-strip'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const Key('cinematic-dual-rail-portrait'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const Key('cinematic-remote-hint'), skipOffstage: false), findsOneWidget);
    },
  );
}

// ---------------------------------------------------------------------------
// Stub notifiers — return empty data without hitting real HTTP.
// ---------------------------------------------------------------------------

class _StubMoviesNotifier extends MoviesNotifier {
  _StubMoviesNotifier() : super(_StubApiClient() as dynamic);

  @override
  Future<void> waitForInit() async {
    state = const AsyncValue.data([]);
  }
}

// _StubApiClient is only used to satisfy the super constructor; waitForInit
// overrides the actual loading behaviour above.
class _StubApiClient {
  @override
  // ignore: avoid_dynamic_calls
  dynamic noSuchMethod(Invocation i) => null;
}
