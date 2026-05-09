import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:megav_iptv/core/api/api_client.dart';
import 'package:megav_iptv/core/player/decoder_config.dart';
import 'package:megav_iptv/core/player/player_engine.dart';
import 'package:megav_iptv/core/player/player_manager.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/core/playlist/models/epg_program.dart';
import 'package:megav_iptv/core/playlist/models/now_playing.dart';
import 'package:megav_iptv/core/providers/providers.dart';
import 'package:megav_iptv/features/player/player_screen.dart';
import 'package:megav_iptv/features/player/widgets/epg_overlay.dart';
import 'package:megav_iptv/features/player/widgets/player_bottom_info.dart';

// =====================================================================
// Fakes
// =====================================================================

/// Minimal `PlayerEngine` that renders a transparent placeholder for the
/// video texture. Streams are kept open broadcast streams so the
/// `_LoadingErrorIndicator`'s `StreamBuilder` won't be left dangling.
class FakePlayerEngine implements PlayerEngine {
  final _state = StreamController<PlayerState>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _error = StreamController<String?>.broadcast();
  PlayerState _current = PlayerState.idle;

  @override
  Stream<PlayerState> get stateStream => _state.stream;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<String?> get errorStream => _error.stream;

  @override
  PlayerState get currentState => _current;

  @override
  bool get isPlaying => _current == PlayerState.playing;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> open(String url) async {
    _current = PlayerState.playing;
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {
    _current = PlayerState.stopped;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    await _state.close();
    await _position.close();
    await _error.close();
  }

  @override
  Widget buildVideoWidget({BoxFit fit = BoxFit.contain, double? width, double? height}) {
    return const SizedBox.expand(
      key: ValueKey('fake-video-widget'),
    );
  }
}

/// Subclass of the real `PlayerManager` that swaps in our fake engine and
/// makes `initialize`/`playChannel`/`stop`/`dispose` no-ops.
///
/// Subclassing (instead of implementing) is intentional — the public API
/// surface is small and stable, and `_PlayerScreenState` only touches:
/// `initialize()`, `playChannel()`, `stop()`, `activeEngine`,
/// `media3Engine`, `currentUrl`, `stateStream`.
class FakePlayerManager extends PlayerManager {
  final FakePlayerEngine _fakeEngine = FakePlayerEngine();
  final _stateCtl = StreamController<PlayerState>.broadcast();

  String? _url;
  bool _disposed = false;

  FakePlayerManager() : super();

  int initializeCalls = 0;
  int playChannelCalls = 0;
  int stopCalls = 0;
  String? lastPlayedUrl;

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
  }

  @override
  PlayerEngine? get activeEngine => _fakeEngine;

  @override
  // Force non-Media3 path so `_PlayerScreenState.build()` returns the
  // overlay-bearing tree (rather than the Media3 fallback Scaffold).
  get media3Engine => null;

  @override
  String? get currentUrl => _url;

  @override
  Stream<PlayerState> get stateStream => _stateCtl.stream;

  @override
  Future<void> playChannel(String url, {String? channelId}) async {
    playChannelCalls += 1;
    lastPlayedUrl = url;
    _url = url;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _fakeEngine.dispose();
    await _stateCtl.close();
  }
}

/// API client subclass returning canned values for the methods touched by
/// `_PlayerScreenState` and its child widgets (`PlayerBottomInfo`,
/// `EpgOverlay`).
///
/// We extend `ApiClient` with a dummy `baseUrl` so that the no-op
/// `dispose()` (closes a never-used `http.Client`) is harmless.
class FakeApiClient extends ApiClient {
  FakeApiClient() : super(baseUrl: 'http://test.invalid');

  /// Channels returned by [getChannels] for quick-switch test.
  List<Channel> channelsForGroup = const [];

  @override
  Future<({List<Channel> channels, int total})> getChannels({
    String? category,
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    return (channels: channelsForGroup, total: channelsForGroup.length);
  }

  @override
  Future<String?> getBestStreamUrl(int channelId) async => 'http://test.invalid/stream/$channelId';

  @override
  Future<EpgProgram?> getCurrentProgram(int channelId) async => null;

  @override
  Future<List<EpgProgram>> getUpcomingPrograms(int channelId, {int limit = 10}) async => const [];

  // The remaining methods are unused by the screen under test but must
  // still compile against the base class signature. The default base
  // implementations would attempt real HTTP — override them defensively
  // in case some descendant widget pulls them in.

  @override
  Future<List<({String name, int count})>> getCategories() async => const [];

  @override
  Future<List<Channel>> getFeaturedChannels({int limit = 10}) async => const [];

  @override
  Future<List<NowPlayingItem>> getNowPlaying() async => const [];

  @override
  Future<List<NowPlayingItem>> getUpcomingAll({int withinMinutes = 180, int limit = 50}) async => const [];

  @override
  Future<({List<NowPlayingItem> items, int total})> getCategoryNowPlaying(
    String category, {
    int limit = 20,
    int offset = 0,
  }) async => (items: const <NowPlayingItem>[], total: 0);

  @override
  Future<({List<NowPlayingItem> items, int total})> getMoviesNowPlaying({
    int limit = 20,
    int offset = 0,
  }) async => (items: const <NowPlayingItem>[], total: 0);

  @override
  Future<List<NowPlayingItem>> getFeaturedNowPlaying({int limit = 10}) async => const [];

  @override
  void dispose() {
    // Do not call super.dispose() — base class would close the unused http.Client,
    // but that is harmless either way; just a defensive no-op.
  }
}

// =====================================================================
// Harness
// =====================================================================

/// Build a runtime-realistic widget tree for `PlayerScreen` so that
/// ScreenUtil resolves to identity scale (designSize == surface size).
///
/// MUST be paired with `tester.binding.setSurfaceSize(Size(1920, 1080))`
/// in the test body (see existing pattern in
/// `cinema_row_debounce_test.dart`).
Widget _harness({
  required Channel? initialChannel,
  required FakePlayerManager playerManager,
  required FakeApiClient apiClient,
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(apiClient),
      playerManagerProvider.overrideWithValue(playerManager),
      currentChannelProvider.overrideWith((ref) => initialChannel),
      currentChannelIndexProvider.overrideWith((ref) => 0),
      decoderConfigProvider.overrideWith((ref) => const DecoderConfig()),
    ],
    child: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ScreenUtilInit(
        designSize: const Size(1920, 1080),
        builder: (context, _) => const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: PlayerScreen()),
        ),
      ),
    ),
  );
}

// =====================================================================
// Tests
// =====================================================================

void main() {
  late Channel testChannel;

  setUp(() {
    // Non-empty streamUrl skips `api.getBestStreamUrl` inside `_openChannel`.
    testChannel = const Channel(
      id: 100,
      name: 'Test Channel',
      groupTitle: 'Movies',
      streamUrl: 'http://test.invalid/stream/100',
    );
  });

  group('PlayerScreen state-machine', () {
    testWidgets(
      'open → BriefOsd visible → after timer expiry controls hidden (Req 4.1, 4.2, 6.3)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final pm = FakePlayerManager();
        final api = FakeApiClient();

        await tester.pumpWidget(_harness(
          initialChannel: testChannel,
          playerManager: pm,
          apiClient: api,
        ));

        // Allow `_init()` async chain (initialize → openChannel → playChannel
        // → _transition(BriefOsdState)) to settle.
        await tester.pump(); // first frame
        await tester.pump(const Duration(milliseconds: 50));

        // After init, the state machine sits in BriefOsdState (3s expiry):
        // PlayerBottomInfo must be in the tree.
        expect(
          find.byType(PlayerBottomInfo),
          findsOneWidget,
          reason: 'After open, BriefOsdState shows PlayerBottomInfo',
        );

        // Pump past the 3s BriefOsd timer (with margin) — _onExpiry fires
        // and transitions to HiddenState.
        await tester.pump(const Duration(seconds: 4));

        expect(
          find.byType(PlayerBottomInfo),
          findsNothing,
          reason: 'BriefOsd auto-hides after 3s; HiddenState renders no overlays',
        );
      },
    );

    testWidgets(
      'quick-switch ⬆ → preview shown → 1.5s commit → channel changed (Req 3.3, 3.4, 4.7, 6.3)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const nextChannel = Channel(
          id: 200,
          name: 'Next Channel',
          groupTitle: 'Movies',
          streamUrl: 'http://test.invalid/stream/200',
        );

        final pm = FakePlayerManager();
        final api = FakeApiClient()..channelsForGroup = const [
          Channel(
            id: 100,
            name: 'Test Channel',
            groupTitle: 'Movies',
            streamUrl: 'http://test.invalid/stream/100',
          ),
          nextChannel,
        ];

        // Capture the ProviderContainer so we can assert on
        // `currentChannelProvider` after commit.
        final harness = _harness(
          initialChannel: testChannel,
          playerManager: pm,
          apiClient: api,
        );
        await tester.pumpWidget(harness);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Wait past the BriefOsd 3s expiry so the state-machine sits in
        // HiddenState — only HiddenState/ControlsState accept arrowUp
        // (per `_handleKeyEvent`).
        await tester.pump(const Duration(seconds: 4));

        // Sanity: nothing on screen between BriefOsd hide and quick-switch.
        expect(find.byType(PlayerBottomInfo), findsNothing);

        // Drive the quick-switch via the Focus.onKeyEvent. The test focus
        // chain is rooted at the player; `sendKeyEvent` dispatches a
        // KeyDownEvent + KeyUpEvent.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        // Flush microtasks: _quickSwitch awaits api.getChannels.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // SwitchPreviewState now renders PlayerBottomInfo with previewChannel
        // and isSwitching: true.
        final preview = find.byType(PlayerBottomInfo);
        expect(preview, findsOneWidget,
            reason: 'SwitchPreviewState should render PlayerBottomInfo for preview');
        final previewWidget = tester.widget<PlayerBottomInfo>(preview);
        expect(previewWidget.channel.id, nextChannel.id,
            reason: 'Preview shows the *next* channel before commit');
        expect(previewWidget.isSwitching, isTrue,
            reason: 'Preview is rendered with isSwitching:true');

        // Pump past the 1.5s commit timer (+ margin). _onExpiry on
        // SwitchPreviewState fires `_commitSwitchPreview(next)` →
        // updates providers → calls `_openChannel(next)` →
        // `_transition(BriefOsdState)`.
        await tester.pump(const Duration(milliseconds: 1700));
        // Allow async _openChannel/playChannel to settle.
        await tester.pump(const Duration(milliseconds: 50));

        // Read provider state from the running widget tree.
        final element = tester.element(find.byType(PlayerScreen));
        final container = ProviderScope.containerOf(element);
        expect(
          container.read(currentChannelProvider)?.id,
          nextChannel.id,
          reason: 'After 1.5s commit, currentChannelProvider holds the preview channel',
        );

        // After commit, _openChannel transitions to BriefOsdState ⇒
        // PlayerBottomInfo is rendered for the new (committed) channel.
        final committed = find.byType(PlayerBottomInfo);
        expect(committed, findsOneWidget,
            reason: 'After commit, BriefOsdState shows PlayerBottomInfo');
        final committedWidget = tester.widget<PlayerBottomInfo>(committed);
        expect(committedWidget.channel.id, nextChannel.id,
            reason: 'Committed BriefOsd shows the new channel');
        expect(committedWidget.isSwitching, isFalse,
            reason: 'BriefOsdState renders PlayerBottomInfo with isSwitching:false');

        // Verify side-effects on PlayerManager: playChannel was invoked at
        // least once (for the committed channel). The initial open in
        // _init also calls it; the committed open re-calls it.
        expect(pm.playChannelCalls, greaterThanOrEqualTo(1));
        expect(pm.lastPlayedUrl, nextChannel.streamUrl);
      },
    );

    testWidgets(
      'press E → EpgOverlay visible → press E → EpgOverlay gone (Req 4.3, 4.4, 6.3)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final pm = FakePlayerManager();
        final api = FakeApiClient();

        await tester.pumpWidget(_harness(
          initialChannel: testChannel,
          playerManager: pm,
          apiClient: api,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Clear BriefOsd to start from HiddenState (also valid: keyE works
        // from any state per `_handleKeyEvent`, but starting from a clean
        // HiddenState is the documented scenario in design.md).
        await tester.pump(const Duration(seconds: 4));

        await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
        // _toggleOverlayKey → _transition(OverlayState(epg)).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.byType(EpgOverlay),
          findsOneWidget,
          reason: 'After E, OverlayState(epg) renders EpgOverlay',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.byType(EpgOverlay),
          findsNothing,
          reason: 'Second E press toggles back to HiddenState; EpgOverlay disposed',
        );

        // Allow any pending async (EpgOverlay's _loadPrograms future) to
        // complete before tear-down — prevents pending-timer warnings.
        await tester.pump(const Duration(milliseconds: 50));
      },
    );
  });
}
