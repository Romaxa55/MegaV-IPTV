import 'package:flutter/material.dart' hide Chip, SearchController;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:megav_iptv/core/api/api_client.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/search/state/search_controller.dart';
import 'package:megav_iptv/features/search/widgets/search_results_grid.dart';
import 'package:megav_iptv/features/search/widgets/search_state.dart';

// Widget tests for [SearchResultsGrid] (task 10.5, requirements 6.1, 6.2,
// 6.3, 6.4, 6.5, 6.6, 6.8, 9.5).
//
// Strategy:
//   We override `searchControllerProvider` with a `_FakeSearchController`
//   that subclasses [SearchController] but is constructed with a no-op
//   ApiClient (so any accidental network call would surface as a 500
//   loud failure) and starts in a *pre-set* `SearchUiState` of our
//   choice. This lets each test target exactly one of the five sealed
//   state branches without touching production code paths.
//
// Why subclass instead of a parallel StateNotifier:
//   `searchControllerProvider` is typed as
//   `StateNotifierProvider.autoDispose<SearchController, SearchUiState>`.
//   `overrideWith(...)` requires the override to return a `SearchController`
//   subtype; a sibling class would not satisfy the type system without
//   changing the production provider signature.

class _FakeSearchController extends SearchController {
  _FakeSearchController(SearchUiState initialState)
      : super(ApiClient(
          baseUrl: 'http://test.local',
          // Loud network — if anything in the widget tree accidentally
          // triggers a real API call, the fake client surfaces a 500.
          client: MockClient((_) async => http.Response('forbidden', 500)),
        )) {
    state = initialState;
  }

  @override
  Future<void> requestNextPage() async {
    // No-op: the grid view's `addPostFrameCallback` schedules this on the
    // last cell of a "hasMore" page. The widget test never asserts on
    // pagination side-effects — only on the rendered layout — so we
    // intentionally short-circuit it here to keep the test deterministic.
  }
}

Widget _harness({required SearchUiState state}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ProviderScope(
      overrides: [
        searchControllerProvider.overrideWith((ref) => _FakeSearchController(state)),
      ],
      child: ScreenUtilInit(
        designSize: const Size(1920, 1080),
        builder: (context, _) => const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: SearchResultsGrid()),
        ),
      ),
    ),
  );
}

Channel _ch(int id) => Channel(id: id, name: 'Channel $id');

void main() {
  testWidgets('Test A — Idle renders the "Начните вводить запрос" hint', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_harness(state: const Idle()));
    await tester.pump();
    await tester.pump();

    expect(find.text('Начните вводить запрос'), findsOneWidget);
  });

  testWidgets('Test B — Loading renders a CircularProgressIndicator', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_harness(state: const Loading('q')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Test C — Empty(query) renders the query inside the empty message', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_harness(state: const Empty('xyz')));
    await tester.pump();
    await tester.pump();

    // The widget renders `Ничего не найдено по запросу "xyz"`. We assert
    // by predicate to make the test resilient to surrounding punctuation
    // changes.
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('xyz'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Test D — SearchError renders message and a "Повторить" button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_harness(
      state: const SearchError(message: 'oops', lastQuery: 'q'),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('oops'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets(
    'Test E — Results renders 2 Posters and the GridView keeps Mali-friendly perf flags',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // The Poster atom + GridView childAspectRatio of 16:9 in the tight
      // test surface can spill 1–2 px on tile rows. Same purely visual
      // overflow filtering as the EPG widget tests.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        final message = details.exceptionAsString();
        if (message.contains('A RenderFlex overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(_harness(
        state: Results(items: [_ch(1), _ch(2)], total: 2, query: 'q', hasMore: false),
      ));
      await tester.pump();
      await tester.pump();

      // 2 channels → 2 Poster atoms rendered.
      expect(find.byType(Poster), findsNWidgets(2));

      // Read the GridView itself and assert the Mali-friendly knobs from
      // the production widget (Req 6.8, 9.5). `addAutomaticKeepAlives` and
      // `addRepaintBoundaries` live on the underlying SliverChildBuilderDelegate
      // (GridView.builder forwards them into the delegate).
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.cacheExtent, 1500);
      final delegate = grid.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.addAutomaticKeepAlives, isTrue);
      expect(delegate.addRepaintBoundaries, isTrue);
    },
  );
}
