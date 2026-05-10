import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:megav_iptv/core/api/api_client.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/features/search/state/search_controller.dart';
import 'package:megav_iptv/features/search/widgets/keyboard_key.dart';
import 'package:megav_iptv/features/search/widgets/search_state.dart';

// Unit tests for [SearchController] (task 10.1, requirements 5.1, 5.2, 5.3,
// 5.5, 7.2, 7.3, 12.2, 12.5).
//
// The controller is a `StateNotifier` that owns the search-screen UI state
// machine. It is tested in isolation from Riverpod by constructing it with a
// hand-rolled stub `ApiClient`. Each scenario asserts on `controller.state`
// directly (StateNotifier exposes its current state as a public field).
//
// Why a *manual* `_StubApiClient` extending the real [ApiClient]:
//   * The production [SearchController] only ever calls `searchChannels(...)`,
//     so the stub overrides only that method. The base ctor (super) is fed an
//     `http.Client` that throws on every request — guaranteeing the test will
//     fail loudly if the controller ever bypasses our override.
//   * No mocking framework is required — `extends ApiClient + override
//     searchChannels` is enough and keeps the type identity intact.
//
// Debounce timing (Req 5.2):
//   The controller debounces with a 350 ms timer. We pump > 350 ms (400 ms)
//   so the timer fires; we never use `pumpAndSettle` because the test runs
//   without a `WidgetTester` here.

class _StubApiClient extends ApiClient {
  _StubApiClient()
      : super(
          baseUrl: 'http://test.local',
          // Any request reaching this client should mean a bug in the
          // controller (it should always go through `searchChannels` which
          // we override). Throwing surfaces such regressions immediately.
          client: MockClient((req) async => http.Response('forbidden', 500)),
        );

  /// How many times [searchChannels] was invoked.
  int searchCallCount = 0;

  /// Last `query` argument passed to [searchChannels].
  String? lastQuery;

  /// Last `offset` argument passed to [searchChannels].
  int? lastOffset;

  /// If non-null, the next call will throw this object (and reset itself to
  /// null after consuming it — one-shot).
  Object? throwOnNextCall;

  /// If non-null, the next call returns the resolved Future of this completer
  /// instead of [responseFactory] — lets the test gate when the API resolves
  /// (used for the in-flight test).
  Completer<({List<Channel> channels, int total})>? gate;

  /// Synchronous response factory used when no [gate] is set.
  ({List<Channel> channels, int total}) Function(String query, int offset) responseFactory =
      (_, _) => (channels: const <Channel>[], total: 0);

  @override
  Future<({List<Channel> channels, int total})> searchChannels({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    searchCallCount += 1;
    lastQuery = query;
    lastOffset = offset;
    if (throwOnNextCall != null) {
      final err = throwOnNextCall!;
      throwOnNextCall = null;
      throw err;
    }
    final g = gate;
    if (g != null) {
      gate = null;
      return g.future;
    }
    return responseFactory(query, offset);
  }
}

Channel _ch(int id, [String? name]) => Channel(id: id, name: name ?? 'Channel $id');

void main() {
  group('SearchController', () {
    test('Test A — debounce coalesces two synchronous keypresses into one API call', () async {
      final api = _StubApiClient();
      final controller = SearchController(api);
      addTearDown(controller.dispose);

      // Two synchronous keypresses: "А" then "Б". Each restarts the 350 ms
      // debounce timer (Req 5.2), so only the trailing query is dispatched.
      controller.onKeyPressed(const Char('А'));
      controller.onKeyPressed(const Char('Б'));

      // Wait > 350 ms so the debounce timer fires and the search resolves.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(api.searchCallCount, 1);
      expect(api.lastQuery, 'АБ');
    });

    test('Test B — Backspace on empty query is a no-op (no API call, state stays Idle)', () async {
      final api = _StubApiClient();
      final controller = SearchController(api);
      addTearDown(controller.dispose);

      controller.onKeyPressed(const Backspace());

      // Even after the debounce window, no search must have been dispatched
      // and the state must remain `Idle`.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(api.searchCallCount, 0);
      expect(controller.state, isA<Idle>());
    });

    test('Test C — successful response with two channels transitions to Results', () async {
      final api = _StubApiClient();
      final ch1 = _ch(1, 'first');
      final ch2 = _ch(2, 'second');
      api.responseFactory = (_, _) => (channels: [ch1, ch2], total: 2);

      final controller = SearchController(api);
      addTearDown(controller.dispose);

      controller.onKeyPressed(const Char('А'));
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final state = controller.state;
      expect(state, isA<Results>());
      final results = state as Results;
      expect(results.items.length, 2);
      expect(results.total, 2);
      expect(results.hasMore, isFalse);
      expect(results.query, 'А');
    });

    test('Test D — empty response transitions to Empty(query)', () async {
      final api = _StubApiClient();
      api.responseFactory = (_, _) => (channels: const <Channel>[], total: 0);

      final controller = SearchController(api);
      addTearDown(controller.dispose);

      controller.onKeyPressed(const Char('Я'));
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final state = controller.state;
      expect(state, isA<Empty>());
      expect((state as Empty).query, 'Я');
    });

    test('Test E — throw transitions to SearchError(message, lastQuery)', () async {
      final api = _StubApiClient();
      api.throwOnNextCall = Exception('boom');

      final controller = SearchController(api);
      addTearDown(controller.dispose);

      controller.onKeyPressed(const Char('Z'));
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final state = controller.state;
      expect(state, isA<SearchError>());
      final err = state as SearchError;
      expect(err.message, contains('boom'));
      expect(err.lastQuery, 'Z');
    });

    test('Test F — requestNextPage with hasMore=false makes no API call', () async {
      final api = _StubApiClient();
      api.responseFactory = (_, _) => (channels: [_ch(1)], total: 1);

      final controller = SearchController(api);
      addTearDown(controller.dispose);

      controller.onKeyPressed(const Char('A'));
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Now hasMore == false (offset 1 == total 1). One API call made so far.
      expect(api.searchCallCount, 1);
      expect(controller.state, isA<Results>());
      expect((controller.state as Results).hasMore, isFalse);

      await controller.requestNextPage();
      // Pagination is a no-op when there is nothing left to fetch (Req 7.3).
      expect(api.searchCallCount, 1);
    });

    test(
        'Test G — requestNextPage while a request is in-flight returns immediately, no extra API call',
        () async {
      final api = _StubApiClient();
      // First call (debounced search) goes through the gate so it can be
      // suspended. We resolve the gate manually after we've fired the second
      // requestNextPage to prove the in-flight guard in [SearchController]
      // (Req 7.2).
      final gate = Completer<({List<Channel> channels, int total})>();
      api.gate = gate;

      final controller = SearchController(api);
      addTearDown(controller.dispose);

      controller.onKeyPressed(const Char('Q'));
      // Let the debounce timer fire so `_runSearch` starts and `_inFlight`
      // flips to true. Use slightly more than 350 ms.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      // At this point the API has been *called* (count == 1) but the future
      // hasn't resolved.
      expect(api.searchCallCount, 1);

      // Second call while in-flight must return immediately without calling
      // the API again.
      await controller.requestNextPage();
      expect(api.searchCallCount, 1);

      // Resolve so the controller cleans up; no further assertions needed.
      gate.complete((channels: const <Channel>[], total: 0));
      // Drain microtasks so finally-block runs.
      await Future<void>.delayed(Duration.zero);
    });
  });
}
