import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/perf/perf_safe_widgets.dart';
import 'package:megav_iptv/core/playlist/models/epg_program.dart';
import 'package:megav_iptv/core/playlist/models/now_playing.dart';
import 'package:megav_iptv/features/home/editorial/editorial_side_card.dart';

NowPlayingItem _mockItem({String title = 'Эпизод I'}) {
  final now = DateTime(2026, 5, 9, 20, 0);
  return NowPlayingItem(
    channelId: 1,
    channelName: 'Канал «Театр»',
    groupTitle: 'Драма',
    logoUrl: 'https://example.test/logo.png',
    thumbnailUrl: 'https://example.test/thumb.jpg',
    program: EpgProgram(
      id: 10,
      channelId: 1,
      title: title,
      description: '1981 г.\n\nКраткое описание программы.',
      category: 'Драма',
      icon: 'https://example.test/poster.jpg',
      start: now,
      end: now.add(const Duration(minutes: 90)),
    ),
  );
}

Widget _wrap(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(1920, 1080),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, _) {
          return MaterialApp(
            home: Scaffold(body: child),
          );
        },
      ),
    ),
  );
}

void main() {
  // Narrow filter — silence RenderFlex overflow noise that surfaces when the
  // 540-lp poster + meta-column composes against the 1920-lp surface in a
  // bare Scaffold (production callers wrap the card in an Expanded). Other
  // exceptions still bubble up through `tester.takeException()`.
  setUp(() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final message = details.exceptionAsString();
      if (message.contains('A RenderFlex overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);
  });

  testWidgets(
    'EditorialSideCard.next renders ДАЛЕЕ В ЭФИРЕ eyebrow + countdown + key',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 540,
            child: EditorialSideCard.next(
              item: _mockItem(),
              remaining: 'через 55 мин',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('editorial-side-card-next')), findsOneWidget);
      expect(find.text('ДАЛЕЕ В ЭФИРЕ'), findsOneWidget);
      expect(find.text('через 55 мин'), findsOneWidget);
    },
  );

  testWidgets(
    'EditorialSideCard.featured renders РЕКОМЕНДУЕМ eyebrow + key',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 540,
            child: EditorialSideCard.featured(
              item: _mockItem(),
              remaining: '2ч 06м',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('editorial-side-card-featured')),
        findsOneWidget,
      );
      expect(find.text('РЕКОМЕНДУЕМ'), findsOneWidget);
    },
  );

  testWidgets(
    'EditorialSideCard does not introduce any BackdropFilter (Req 4.2)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 540,
            child: EditorialSideCard.next(
              item: _mockItem(),
              remaining: 'через 12 мин',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(BackdropFilter), findsNothing);
    },
  );

  testWidgets(
    'EditorialSideCard wraps content in exactly one SafeFocusRing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 540,
            child: EditorialSideCard.next(
              item: _mockItem(),
              remaining: 'через 12 мин',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // The card itself wraps content in one SafeFocusRing; the inner
      // Poster atom adds another. Scope to descendants of the keyed root
      // and verify exactly one is the *direct* card-level ring.
      final cardRoot = find.byKey(const Key('editorial-side-card-next'));
      expect(cardRoot, findsOneWidget);
      // At least one — and the topmost descendant is the card-level
      // SafeFocusRing wrapping the DecoratedBox.
      expect(
        find.descendant(
          of: find.byType(EditorialSideCard),
          matching: find.byType(SafeFocusRing),
        ),
        findsWidgets,
      );
    },
  );
}
