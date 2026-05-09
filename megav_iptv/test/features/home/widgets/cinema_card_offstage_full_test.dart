// Task 3.2 (spec home-grid-visual-polish, Req 2.1, 2.2, 2.3).
//
// Проверяет жизненный цикл full overlay в дереве виджетов CinemaCard через
// `Visibility(visible: _shouldRenderFullOverlay, …)`, добавленный в task 2.2:
//
//   * Req 2.1: пока плитка нефокусирована и фокуса не было ~150 мс, full
//     overlay (rating/age/genre/programme-title/progress) НЕ присутствует
//     в дереве.
//   * Req 2.2: при получении фокуса full overlay появляется в дереве
//     до окончания focus-анимации (так что fade-in успевает отыграть).
//   * Req 2.3: при потере фокуса subtree остаётся в дереве до завершения
//     fade-out (≈ overlayFade), и только потом удаляется.
//
// Этот файл смотрит на дерево по конкретным `Key`-ам полного overlay,
// тогда как существующий `cinema_card_overlay_test.dart` проверяет наличие
// AnimatedOpacity-обёртки. Проверки независимы и не пересекаются.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/epg_program.dart';
import 'package:megav_iptv/core/playlist/models/now_playing.dart';
import 'package:megav_iptv/features/home/widgets/_grid_tokens.dart';
import 'package:megav_iptv/features/home/widgets/cinema_card.dart';

/// Live-программа: start в прошлом, end в будущем — так `program.isNow == true`,
/// и `progress-section` действительно рендерится в фокусе.
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

/// Runtime-realistic harness (same shape used by `cinema_card_overlay_test.dart`).
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

/// 5 ключей, которые живут только в full overlay (compact-overlay их не дублирует).
const _fullOverlayKeys = <Key>[
  Key('rating-badge'),
  Key('age-rating'),
  Key('genre-emoji'),
  Key('programme-title'),
  Key('progress-section'),
];

/// Stateful-харнесс для теста смены focus state без re-mount'а CinemaCard
/// (нужен для проверки `didUpdateWidget` → `_focusJustLost`).
class _FocusToggleHarness extends StatefulWidget {
  const _FocusToggleHarness({super.key, required this.item, required this.initialFocus});

  final NowPlayingItem item;
  final bool initialFocus;

  @override
  State<_FocusToggleHarness> createState() => _FocusToggleHarnessState();
}

class _FocusToggleHarnessState extends State<_FocusToggleHarness> {
  late bool _isFocused = widget.initialFocus;

  void setFocused(bool value) => setState(() => _isFocused = value);

  @override
  Widget build(BuildContext context) {
    return CinemaCard(
      item: widget.item,
      isFocused: _isFocused,
      cardWidth: 200,
      cardHeight: 300,
    );
  }
}

void main() {
  testWidgets(
    'unfocused CinemaCard: full-overlay subtree is absent, channel-name is preserved (Req 2.1, 2.4)',
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
      // Settle ScreenUtilInit + проскочим overlayFade на случай если виджет
      // только что замонтировался: для нефокусированной "с нуля" карточки
      // _focusJustLost никогда в true не выставлялся, так что Visibility
      // визуально-инвариантен сразу, но pump-ы делают проверку устойчивой.
      await tester.pump();
      await tester.pump(GridTokens.overlayFade + const Duration(milliseconds: 50));

      for (final key in _fullOverlayKeys) {
        expect(
          find.byKey(key),
          findsNothing,
          reason: 'Full-overlay key $key MUST NOT be in tree when CinemaCard '
              'is unfocused (task 2.2 / Req 2.1)',
        );
      }

      // Compact overlay сохраняется (Req 2.4).
      expect(
        find.byKey(const Key('channel-name')),
        findsOneWidget,
        reason: 'channel-name (compact overlay) MUST stay in tree regardless '
            'of focus (Req 2.4)',
      );
    },
  );

  testWidgets(
    'focused CinemaCard: full-overlay subtree (5 keys) is present (Req 2.2)',
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
      // Дать AnimatedOpacity отыграть fade-in.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      for (final key in _fullOverlayKeys) {
        expect(
          find.byKey(key),
          findsOneWidget,
          reason: 'Full-overlay key $key MUST be in tree when CinemaCard is '
              'focused (Req 2.2)',
        );
      }

      // Compact channel-name всё ещё в дереве (Req 2.4).
      expect(find.byKey(const Key('channel-name')), findsOneWidget);
    },
  );

  testWidgets(
    'focused → unfocused: full-overlay stays during fade-out, then is removed (Req 2.3)',
    (tester) async {
      final item = _fakeItem();
      final harnessKey = GlobalKey<_FocusToggleHarnessState>();

      await tester.pumpWidget(
        _harness(
          child: _FocusToggleHarness(
            key: harnessKey,
            item: item,
            initialFocus: true,
          ),
        ),
      );
      // Fade-in проигрался → full overlay в дереве.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      for (final key in _fullOverlayKeys) {
        expect(
          find.byKey(key),
          findsOneWidget,
          reason: 'Pre-condition: focused state must mount full overlay',
        );
      }

      // Снимаем фокус, НО ПОКА НЕ pump-аем длинно: didUpdateWidget выставит
      // _focusJustLost = true, и Timer запустится на overlayFade + 16ms.
      harnessKey.currentState!.setFocused(false);

      // Один frame: state-change + Timer registered. Subtree обязан остаться
      // в дереве, потому что _focusJustLost == true (Req 2.3).
      await tester.pump();
      for (final key in _fullOverlayKeys) {
        expect(
          find.byKey(key),
          findsOneWidget,
          reason: 'Right after focus loss, full-overlay $key MUST still be in '
              'tree so AnimatedOpacity can play fade-out (Req 2.3)',
        );
      }

      // Подождём дольше overlayFade + 16ms, чтобы Timer сработал и снял
      // Visibility. Берём с запасом: overlayFade(150ms) + 100ms.
      await tester.pump(GridTokens.overlayFade + const Duration(milliseconds: 100));

      for (final key in _fullOverlayKeys) {
        expect(
          find.byKey(key),
          findsNothing,
          reason: 'After overlayFade + buffer elapsed, full-overlay $key MUST '
              'be removed from tree (Req 2.1, 2.3)',
        );
      }

      // Compact overlay по-прежнему в дереве (Req 2.4).
      expect(find.byKey(const Key('channel-name')), findsOneWidget);
    },
  );
}
