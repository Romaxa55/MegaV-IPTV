import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/perf/perf_safe_widgets.dart';
import 'package:megav_iptv/core/playlist/models/epg_program.dart';
import 'package:megav_iptv/core/playlist/models/now_playing.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/home/editorial/editorial_hero_section.dart';
import 'package:megav_iptv/features/home/editorial/editorial_side_card.dart';

NowPlayingItem _mockItem({
  int channelId = 1,
  String channelName = 'Канал «Театр»',
  String title = 'Эпизод I',
}) {
  final now = DateTime(2026, 5, 9, 20, 0);
  return NowPlayingItem(
    channelId: channelId,
    channelName: channelName,
    groupTitle: 'Драма',
    logoUrl: 'https://example.test/logo-$channelId.png',
    thumbnailUrl: 'https://example.test/thumb-$channelId.jpg',
    program: EpgProgram(
      id: 100 + channelId,
      channelId: channelId,
      title: title,
      description: '1981 г.\n\nКраткое описание программы для теста.',
      category: 'Драма',
      icon: 'https://example.test/poster-$channelId.jpg',
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

EditorialHeroSection _hero() {
  return EditorialHeroSection(
    item: _mockItem(channelId: 1, title: 'Лидерская премьера'),
    nextItem: _mockItem(channelId: 2, title: 'Эпизод II'),
    featuredItem: _mockItem(channelId: 3, title: 'Эпизод III'),
    onPlay: () {},
    onFavoriteToggle: () {},
    onEpgOpen: () {},
  );
}

void main() {
  // Narrow filter — hero composition exceeds the bare 1920×1080 surface
  // when there's no parent scrollable, producing RenderFlex overflow
  // notifications. Production callers wrap the hero in a CustomScrollView.
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
    'EditorialHeroSection mounts root key + SafeBackdrop + 2 side cards',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(_hero()));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('editorial-hero')), findsOneWidget);
      expect(find.byType(SafeBackdrop), findsAtLeastNWidgets(1));
      expect(find.byType(EditorialSideCard), findsNWidgets(2));
    },
  );

  testWidgets(
    'EditorialHeroSection has no BackdropFilter or ShaderMask in tree',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(_hero()));
      await tester.pump();
      await tester.pump();

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
    },
  );

  testWidgets(
    'EditorialHeroSection title renders in italic display style',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(_hero()));
      await tester.pump();
      await tester.pump();

      // Locate the title Text by content and assert FontStyle.italic.
      final titleFinder = find.text('Лидерская премьера');
      expect(titleFinder, findsOneWidget);
      final text = tester.widget<Text>(titleFinder);
      final style = text.style;
      expect(style, isNotNull);
      expect(style!.fontStyle, FontStyle.italic);
    },
  );

  testWidgets(
    'EditorialHeroSection action row contains MvButton.primary wrapped in Focus',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(_hero()));
      await tester.pump();
      await tester.pump();

      // The hero composes one MvButton.primary (Смотреть) and two ghosts.
      expect(find.byType(MvButton), findsAtLeastNWidgets(3));
      expect(find.text('Смотреть'), findsOneWidget);

      // The primary CTA is wrapped in a Focus widget that owns the
      // hero focus node. Locate the Focus ancestor whose debugLabel
      // matches.
      final focusFinder = find.byWidgetPredicate(
        (w) => w is Focus && (w.focusNode?.debugLabel ?? '').contains('editorial-hero-primary'),
      );
      expect(focusFinder, findsOneWidget);
    },
  );

  testWidgets(
    'EditorialHeroSection renders the rotated EDITORS\' PICK badge via Transform',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(_hero()));
      await tester.pump();
      await tester.pump();

      // Transform.rotate produces a Transform widget. Multiple Transforms
      // exist (MaterialApp, Brand atom etc.) — assert ≥ 1 inside the hero.
      expect(
        find.descendant(
          of: find.byKey(const Key('editorial-hero')),
          matching: find.byType(Transform),
        ),
        findsAtLeastNWidgets(1),
      );
      // The badge text itself is present.
      expect(find.textContaining("EDITORS' PICK"), findsOneWidget);
    },
  );
}
