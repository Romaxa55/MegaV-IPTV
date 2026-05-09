import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/epg_program.dart';
import 'package:megav_iptv/core/playlist/models/now_playing.dart';
import 'package:megav_iptv/features/home/widgets/_grid_tokens.dart';
import 'package:megav_iptv/features/home/widgets/cinema_card.dart';

/// Builds a fake [NowPlayingItem] whose `program` is currently "live"
/// (start in the past, end in the future) so `program.isNow == true`.
NowPlayingItem _fakeItem() {
  final now = DateTime.now();
  return NowPlayingItem(
    channelId: 1,
    channelName: 'Test Channel',
    groupTitle: 'Movies',
    logoUrl: null,
    thumbnailUrl: null,
    program: EpgProgram(
      id: 100,
      channelId: 1,
      title: 'Test Programme',
      description: '1981 г.\n\nA story about something',
      category: 'Драма',
      icon: null,
      lang: 'ru',
      start: now.subtract(const Duration(minutes: 10)),
      end: now.add(const Duration(minutes: 50)),
    ),
  );
}

/// Wraps [child] in a runtime-realistic harness:
///   * `MediaQuery` size 1920x1080 — matches the screenutil designSize so
///     `.w`/`.h`/`.sp` resolve to identity scale.
///   * `ScreenUtilInit(designSize: Size(1920, 1080))`.
///   * `MaterialApp` + `Scaffold`.
Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ScreenUtilInit(
      designSize: const Size(1920, 1080),
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'unfocused CinemaCard renders compact (channel-name visible) and full overlay opacity == 0',
    (tester) async {
      final item = _fakeItem();

      await tester.pumpWidget(
        _harness(
          child: CinemaCard(
            item: item,
            isFocused: false,
            cardWidth: 200,
            cardHeight: 300,
          ),
        ),
      );
      await tester.pump(); // settle ScreenUtilInit
      await tester.pump(GridTokens.overlayFade + const Duration(milliseconds: 50));

      // Compact overlay: channel-name must be present and visible.
      expect(find.byKey(const Key('channel-name')), findsOneWidget);

      // Task 2.2 (Req 2.1, 2.2): full overlay subtree (including the
      // AnimatedOpacity wrapper) is removed from the tree via Visibility once
      // the card is fully unfocused and fade-out has elapsed. Compact overlay
      // (channel-name) is preserved.
      final animatedOpacityFinder = find.descendant(
        of: find.byType(CinemaCard),
        matching: find.byType(AnimatedOpacity),
      );
      expect(animatedOpacityFinder, findsNothing,
          reason: 'Full overlay AnimatedOpacity must be removed from the tree when '
              'CinemaCard is fully unfocused (task 2.2, Req 2.1)');
    },
  );

  testWidgets(
    'focused CinemaCard reveals full overlay (channel-name still visible, full overlay opacity == 1)',
    (tester) async {
      final item = _fakeItem();

      await tester.pumpWidget(
        _harness(
          child: CinemaCard(
            item: item,
            isFocused: true,
            cardWidth: 200,
            cardHeight: 300,
          ),
        ),
      );
      // Pump past the AnimatedOpacity duration.
      await tester.pump();
      await tester.pump(GridTokens.overlayFade + const Duration(milliseconds: 50));

      // Compact still has channel-name.
      expect(find.byKey(const Key('channel-name')), findsOneWidget);

      // Full overlay AnimatedOpacity wrapper must report opacity ≈ 1.
      final animatedOpacityFinder = find.descendant(
        of: find.byType(CinemaCard),
        matching: find.byType(AnimatedOpacity),
      );
      expect(animatedOpacityFinder, findsOneWidget);

      final animatedOpacity = tester.widget<AnimatedOpacity>(animatedOpacityFinder);
      expect(animatedOpacity.opacity, 1.0,
          reason: 'Full overlay must be fully opaque when CinemaCard is focused (Req 6.1, 6.2)');

      // Sanity: full-overlay children exist in the tree.
      expect(find.byKey(const Key('rating-badge')), findsOneWidget);
      expect(find.byKey(const Key('age-rating')), findsOneWidget);
      expect(find.byKey(const Key('genre-emoji')), findsOneWidget);
      expect(find.byKey(const Key('programme-title')), findsOneWidget);
      // Programme is live (isNow == true) → progress-section is rendered.
      expect(find.byKey(const Key('progress-section')), findsOneWidget);
    },
  );
}
