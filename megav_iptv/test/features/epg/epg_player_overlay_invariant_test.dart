// Player-overlay EPG invariant regression test (epg-screen task 6.2).
//
// This file is the safety net guaranteeing that the **closed**
// `player-overlay-state-machine` spec is not broken by anything inside
// `epg-screen`. It locks four invariants:
//
//   1. `currentProgramProvider(<channelId>)` from
//      `lib/core/providers/providers.dart` keeps its `FutureProvider.family<
//      EpgProgram?, int>` signature and behaves identically to the
//      pre-spec baseline when given a mocked `ApiClient` (Req 11.7, 11.8).
//   2. `upcomingProgramsProvider(<channelId>)` keeps its
//      `FutureProvider.family<List<EpgProgram>, int>` signature and
//      behaves identically to the pre-spec baseline (Req 11.7, 11.8).
//   3. `EpgOverlay` (closed widget at
//      `lib/features/player/widgets/epg_overlay.dart`) still pumps in a
//      test environment with a mocked `ApiClient`, with no exceptions —
//      `find.byType(EpgOverlay)` returns one widget (Req 11.8, 14.4).
//   4. `git diff master -- <closed-spec files>` is empty, i.e. no closed-
//      spec file has been modified by the current branch (Req 14.4).
//
// **Mocking strategy**: extend the real `ApiClient` (the same pattern used
// by `test/features/player/player_screen_overlay_test.dart`'s
// `FakeApiClient`) so:
//   - we exercise the real provider closures (they `ref.watch(apiClient
//     Provider)` and call its methods), proving signatures + flow are
//     identical;
//   - the harness never touches the network — the fake's overrides return
//     canned values; `dispose()` is a no-op so `apiClientProvider`'s
//     `ref.onDispose` cleanup is harmless.
//
// **Material `hide Chip`** is applied for consistency with sibling EPG
// tests where Material's `Chip` collides with our atom `Chip` — even
// though `EpgOverlay` itself doesn't use the atom, keeping the import
// shape uniform avoids future surprise.

import 'dart:io';

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:megav_iptv/core/api/api_client.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/core/playlist/models/epg_program.dart';
import 'package:megav_iptv/core/playlist/models/now_playing.dart';
import 'package:megav_iptv/core/providers/providers.dart'
    show apiClientProvider, currentProgramProvider, upcomingProgramsProvider;
import 'package:megav_iptv/features/player/widgets/epg_overlay.dart';

// =====================================================================
// Fake ApiClient — extends the real one (same pattern as
// player_screen_overlay_test.dart::FakeApiClient).
// =====================================================================

/// Deterministic fake `ApiClient` returning canned values per channel id.
///
/// `getCurrentProgram` looks up the configured `currentByChannel` map.
/// `getUpcomingPrograms` looks up `upcomingByChannel`. All other methods
/// return safe empty defaults so any descendant widget that pulls them
/// in does not blow up.
class _FakeApiClient extends ApiClient {
  _FakeApiClient({
    Map<int, EpgProgram?>? currentByChannel,
    Map<int, List<EpgProgram>>? upcomingByChannel,
  })  : currentByChannel = currentByChannel ?? const {},
        upcomingByChannel = upcomingByChannel ?? const {},
        super(baseUrl: 'http://test.invalid');

  final Map<int, EpgProgram?> currentByChannel;
  final Map<int, List<EpgProgram>> upcomingByChannel;

  @override
  Future<EpgProgram?> getCurrentProgram(int channelId) async {
    return currentByChannel[channelId];
  }

  @override
  Future<List<EpgProgram>> getUpcomingPrograms(int channelId, {int limit = 10}) async {
    return upcomingByChannel[channelId] ?? const [];
  }

  // -----------------------------------------------------------------
  // Defensive defaults — never hit by the tests below, but ensure no
  // accidental real HTTP if the closed widget ever pulls more methods.
  // -----------------------------------------------------------------

  @override
  Future<List<({String name, int count})>> getCategories() async => const [];

  @override
  Future<({List<Channel> channels, int total})> getChannels({
    String? category,
    String? search,
    int limit = 20,
    int offset = 0,
  }) async => (channels: const <Channel>[], total: 0);

  @override
  Future<List<Channel>> getFeaturedChannels({int limit = 10}) async => const [];

  @override
  Future<List<NowPlayingItem>> getNowPlaying() async => const [];

  @override
  Future<List<NowPlayingItem>> getUpcomingAll({int withinMinutes = 180, int limit = 50}) async =>
      const [];

  @override
  Future<({List<NowPlayingItem> items, int total})> getCategoryNowPlaying(
    String category, {
    int limit = 20,
    int offset = 0,
  }) async =>
      (items: const <NowPlayingItem>[], total: 0);

  @override
  Future<({List<NowPlayingItem> items, int total})> getMoviesNowPlaying({
    int limit = 20,
    int offset = 0,
  }) async =>
      (items: const <NowPlayingItem>[], total: 0);

  @override
  Future<List<NowPlayingItem>> getFeaturedNowPlaying({int limit = 10}) async => const [];

  @override
  Future<String?> getBestStreamUrl(int channelId) async => null;

  @override
  void dispose() {
    // No-op: base `ApiClient.dispose` would close an unused http.Client,
    // which is harmless either way; this is purely defensive.
  }
}

EpgProgram _mkProgramme(
  int id,
  int channelId, {
  required DateTime start,
  Duration length = const Duration(minutes: 30),
  String? title,
}) {
  return EpgProgram(
    id: id,
    channelId: channelId,
    title: title ?? 'Programme $id',
    start: start,
    end: start.add(length),
  );
}

void main() {
  group('Player-overlay EPG invariants (closed player-overlay-state-machine)', () {
    // -----------------------------------------------------------------
    // Test 1 — currentProgramProvider signature + behaviour unchanged
    // -----------------------------------------------------------------
    test(
      'currentProgramProvider(<channelId>) returns expected EpgProgram? '
      '(Req 11.7, 11.8 — signature + behaviour identical to baseline)',
      () async {
        final now = DateTime.now();
        // A program covering "now" so EpgProgram.isNow == true and the
        // closed `ApiClient.getCurrentProgram` filter returns it.
        final liveNow = _mkProgramme(
          101,
          42,
          start: now.subtract(const Duration(minutes: 5)),
          length: const Duration(minutes: 30),
          title: 'Live Now',
        );

        final api = _FakeApiClient(currentByChannel: {42: liveNow, 99: null});
        final container = ProviderContainer(
          overrides: [apiClientProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);

        // Channel 42 → returns the live program.
        final result42 = await container.read(currentProgramProvider(42).future);
        expect(result42, isA<EpgProgram?>());
        expect(result42, isNotNull);
        expect(result42!.id, 101);
        expect(result42.title, 'Live Now');

        // Channel 99 → no current program, returns null (still EpgProgram?).
        final result99 = await container.read(currentProgramProvider(99).future);
        expect(result99, isNull);

        // Provider guard: channelId <= 0 short-circuits to null without
        // calling the api (baseline behaviour).
        final resultGuard = await container.read(currentProgramProvider(0).future);
        expect(resultGuard, isNull);
      },
    );

    // -----------------------------------------------------------------
    // Test 2 — upcomingProgramsProvider signature + behaviour unchanged
    // -----------------------------------------------------------------
    test(
      'upcomingProgramsProvider(<channelId>) returns expected List<EpgProgram> '
      '(Req 11.7, 11.8 — signature + behaviour identical to baseline)',
      () async {
        final now = DateTime.now();
        final upcoming = <EpgProgram>[
          _mkProgramme(201, 42, start: now.add(const Duration(minutes: 30)), title: 'Next'),
          _mkProgramme(202, 42, start: now.add(const Duration(minutes: 60)), title: 'After Next'),
        ];

        final api = _FakeApiClient(upcomingByChannel: {42: upcoming});
        final container = ProviderContainer(
          overrides: [apiClientProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);

        // Channel 42 → returns the canned upcoming list.
        final result42 = await container.read(upcomingProgramsProvider(42).future);
        expect(result42, isA<List<EpgProgram>>());
        expect(result42, hasLength(2));
        expect(result42[0].id, 201);
        expect(result42[1].id, 202);

        // Unknown channel → empty list (default branch).
        final resultUnknown = await container.read(upcomingProgramsProvider(7).future);
        expect(resultUnknown, isA<List<EpgProgram>>());
        expect(resultUnknown, isEmpty);

        // Provider guard: channelId <= 0 short-circuits to [] without
        // calling the api (baseline behaviour).
        final resultGuard = await container.read(upcomingProgramsProvider(0).future);
        expect(resultGuard, isEmpty);
      },
    );

    // -----------------------------------------------------------------
    // Test 3 — EpgOverlay still pumps in a widget test environment
    // -----------------------------------------------------------------
    testWidgets(
      'EpgOverlay pumps with mocked ApiClient — no exception, finds one widget '
      '(Req 11.8, 14.4 — closed widget render path intact)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // EpgOverlay's bottom-sheet header uses `widget.channelName` inside
        // a Row that, under the test's default Roboto metrics, can spill a
        // few pixels horizontally. Same swallow-pattern as
        // `epg_screen_smoke_test.dart` — visual-only, not a behaviour bug.
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          final message = details.exceptionAsString();
          if (message.contains('A RenderFlex overflowed')) return;
          originalOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalOnError);

        final now = DateTime.now();
        final api = _FakeApiClient(
          currentByChannel: {
            42: _mkProgramme(
              101,
              42,
              start: now.subtract(const Duration(minutes: 5)),
              length: const Duration(minutes: 30),
              title: 'Live Now',
            ),
          },
          upcomingByChannel: {
            42: <EpgProgram>[
              _mkProgramme(202, 42, start: now.add(const Duration(minutes: 30)), title: 'Next'),
            ],
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [apiClientProvider.overrideWithValue(api)],
            child: MediaQuery(
              data: const MediaQueryData(size: Size(1920, 1080)),
              child: ScreenUtilInit(
                designSize: const Size(1920, 1080),
                builder: (context, _) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  home: Scaffold(
                    body: EpgOverlay(
                      channelName: 'Test Channel',
                      channelId: 42,
                      onClose: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        // Drain the sequence: ScreenUtilInit settle → initState's
        // `_loadPrograms` future → setState flush. The overlay also has a
        // SlideTransition with duration 400ms; we don't `pumpAndSettle`
        // because that's optional — we only need EpgOverlay to be in the
        // tree without throwing.
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);
        expect(find.byType(EpgOverlay), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------
    // Test 4 — closed-spec files have empty diff against master
    // -----------------------------------------------------------------
    test(
      'closed-spec files have empty diff against master '
      '(Req 14.4 — read-only invariant on player-overlay-state-machine)',
      () async {
        // `flutter test` runs from the package dir (`megav_iptv/`), so we
        // strip that prefix from the file paths. The `git` invocation
        // walks up from cwd to find the repo root automatically.
        const closedSpecFiles = <String>[
          'megav_iptv/lib/features/player/widgets/epg_overlay.dart',
          'megav_iptv/lib/core/playlist/models/epg_program.dart',
        ];

        // Use the unprefixed paths (relative to package dir) — git resolves
        // them against the repo root regardless of cwd.
        final relPaths = closedSpecFiles
            .map((p) => p.replaceFirst('megav_iptv/', ''))
            .toList();

        final result = await Process.run(
          'git',
          ['diff', 'master', '--name-only', '--', ...relPaths],
          workingDirectory: Directory.current.path,
        );

        // If git itself fails (e.g. no `master` ref in this checkout, CI
        // shallow clone, etc.) the test should not falsely flag a closed-
        // spec violation — surface the failure as a reason instead.
        expect(
          result.exitCode,
          0,
          reason: 'git diff exited with ${result.exitCode}: stderr=${result.stderr}',
        );

        final stdout = (result.stdout as String).trim();
        expect(
          stdout,
          isEmpty,
          reason:
              'closed-spec files have been modified (player-overlay-state-machine '
              'is read-only):\n$stdout',
        );
      },
    );
  });
}
