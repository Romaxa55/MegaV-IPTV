import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:megav_iptv/core/api/api_client.dart';

// Unit tests for [ApiClient.searchChannels] and a backward-compatibility
// regression for [ApiClient.getChannels] (task 10.2, requirements 8.5, 8.6,
// 8.7, 12.6).
//
// The HTTP layer is replaced by `package:http/testing.dart`'s [MockClient],
// which lets us inspect every request and synthesise the response. This is
// the same harness pattern recommended by the `http` package itself.
//
// Channel JSON shape mirrors the real backend payload (see
// `Channel.fromJson` in `lib/core/playlist/models/channel.dart`).

void main() {
  group('ApiClient.searchChannels', () {
    test('Test A — 200 response decodes channels and total', () async {
      final mock = MockClient((req) async {
        // Sanity: the URL must hit /api/channels with a `search` query
        // parameter — otherwise we'd be testing the wrong endpoint.
        expect(req.url.path, '/api/channels');
        expect(req.url.queryParameters['search'], 'q');
        expect(req.url.queryParameters['limit'], '20');
        expect(req.url.queryParameters['offset'], '0');
        return http.Response(
          jsonEncode({
            'channels': [
              {
                'id': 1,
                'name': 'Test Channel',
                'groupTitle': 'Sports',
                'streamUrl': 'http://stream.example/1.m3u8',
                'tvgRec': 0,
                'logoUrl': null,
                'thumbnailUrl': null,
                'hasEpg': true,
              },
            ],
            'total': 42,
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(baseUrl: 'http://test.local', client: mock);
      addTearDown(api.dispose);

      final result = await api.searchChannels(query: 'q');

      expect(result.channels.length, 1);
      expect(result.channels.first.id, 1);
      expect(result.channels.first.name, 'Test Channel');
      expect(result.total, 42);
    });

    test('Test B — non-200 response throws Exception with "search channels" message', () async {
      final mock = MockClient((req) async => http.Response('boom', 500));
      final api = ApiClient(baseUrl: 'http://test.local', client: mock);
      addTearDown(api.dispose);

      // The production code throws `Exception('Failed to search channels: 500')`,
      // so the message must contain the substring "search channels".
      await expectLater(
        api.searchChannels(query: 'q'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'toString()',
            contains('search channels'),
          ),
        ),
      );
    });

    test(
        'Test C (regression) — getChannels(search: q, limit: 20, offset: 0) still returns identical shape',
        () async {
      // Same payload bytes as Test A; we hit `getChannels` with the same
      // semantic parameters and prove that the legacy entrypoint keeps
      // returning `(channels, total)` after the addition of
      // `searchChannels` (Req 8.7 — no breaking changes).
      final mock = MockClient((req) async {
        expect(req.url.path, '/api/channels');
        expect(req.url.queryParameters['search'], 'q');
        expect(req.url.queryParameters['limit'], '20');
        expect(req.url.queryParameters['offset'], '0');
        return http.Response(
          jsonEncode({
            'channels': [
              {
                'id': 7,
                'name': 'Legacy Channel',
                'groupTitle': '',
                'streamUrl': '',
                'tvgRec': 0,
                'hasEpg': false,
              },
            ],
            'total': 13,
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(baseUrl: 'http://test.local', client: mock);
      addTearDown(api.dispose);

      final result = await api.getChannels(search: 'q', limit: 20, offset: 0);

      expect(result.channels.length, 1);
      expect(result.channels.first.id, 7);
      expect(result.channels.first.name, 'Legacy Channel');
      expect(result.total, 13);
    });
  });
}
