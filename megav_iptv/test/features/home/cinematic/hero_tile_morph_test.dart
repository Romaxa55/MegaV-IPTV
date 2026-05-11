// hero_tile_morph_test.dart — verifiable contract for the state machine
// owned by `hero-collapse-tile-morph` spec.
//
// Task 5.1: pure-function state machine tests for computeNextHeroMorphState.
// Tasks 6.1 / 7.1 / 8.1 (focus survival, disableAnimations, bounding rect)
// require widget mounting and arrive in follow-up commits.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/home/cinematic/hero_tile_morph.dart';

void main() {
  group('computeNextHeroMorphState — happy path transitions', () {
    test('idleExpanded + collapse → morphingCollapsing', () {
      expect(
        computeNextHeroMorphState(
          HeroMorphState.idleExpanded,
          HeroMorphCommand.collapse,
        ),
        HeroMorphState.morphingCollapsing,
      );
    });

    test('morphingCollapsing + tickerCompleted → idleCollapsed', () {
      expect(
        computeNextHeroMorphState(
          HeroMorphState.morphingCollapsing,
          HeroMorphCommand.tickerCompleted,
        ),
        HeroMorphState.idleCollapsed,
      );
    });

    test('idleCollapsed + expand → morphingExpanding', () {
      expect(
        computeNextHeroMorphState(
          HeroMorphState.idleCollapsed,
          HeroMorphCommand.expand,
        ),
        HeroMorphState.morphingExpanding,
      );
    });

    test('morphingExpanding + tickerDismissed → idleExpanded', () {
      expect(
        computeNextHeroMorphState(
          HeroMorphState.morphingExpanding,
          HeroMorphCommand.tickerDismissed,
        ),
        HeroMorphState.idleExpanded,
      );
    });
  });

  group('computeNextHeroMorphState — mid-flight reverse', () {
    test('morphingCollapsing + expand → morphingExpanding (reverse)', () {
      expect(
        computeNextHeroMorphState(
          HeroMorphState.morphingCollapsing,
          HeroMorphCommand.expand,
        ),
        HeroMorphState.morphingExpanding,
      );
    });

    test('morphingExpanding + collapse → morphingCollapsing (reverse)', () {
      expect(
        computeNextHeroMorphState(
          HeroMorphState.morphingExpanding,
          HeroMorphCommand.collapse,
        ),
        HeroMorphState.morphingCollapsing,
      );
    });
  });

  group('computeNextHeroMorphState — disableAnimations instant snap', () {
    test('any state + disableAnimationsCollapse → idleCollapsed', () {
      for (final s in HeroMorphState.values) {
        expect(
          computeNextHeroMorphState(s, HeroMorphCommand.disableAnimationsCollapse),
          HeroMorphState.idleCollapsed,
          reason: 'from $s',
        );
      }
    });

    test('any state + disableAnimationsExpand → idleExpanded', () {
      for (final s in HeroMorphState.values) {
        expect(
          computeNextHeroMorphState(s, HeroMorphCommand.disableAnimationsExpand),
          HeroMorphState.idleExpanded,
          reason: 'from $s',
        );
      }
    });
  });

  group('computeNextHeroMorphState — idempotent no-op edges', () {
    // No-op edges return current state unchanged so misbehaving callers
    // (e.g. duplicate ticker events from controller) cannot corrupt state.
    test('idleExpanded + tickerCompleted → idleExpanded (no-op)', () {
      expect(
        computeNextHeroMorphState(
          HeroMorphState.idleExpanded,
          HeroMorphCommand.tickerCompleted,
        ),
        HeroMorphState.idleExpanded,
      );
    });

    test('idleCollapsed + collapse → idleCollapsed (no-op)', () {
      expect(
        computeNextHeroMorphState(
          HeroMorphState.idleCollapsed,
          HeroMorphCommand.collapse,
        ),
        HeroMorphState.idleCollapsed,
      );
    });

    test('idleExpanded + expand → idleExpanded (no-op)', () {
      expect(
        computeNextHeroMorphState(
          HeroMorphState.idleExpanded,
          HeroMorphCommand.expand,
        ),
        HeroMorphState.idleExpanded,
      );
    });
  });

  group('HeroTileMorph widget integration — basic mount', () {
    Widget _harness(Widget child) => ScreenUtilInit(
          designSize: const Size(1920, 1080),
          builder: (context, _) => MaterialApp(
            home: Scaffold(body: Center(child: child)),
          ),
        );

    testWidgets('mounts in expanded state without error', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(_harness(HeroTileMorph(
        expandedChild: const Text('HERO_EXPANDED', key: ValueKey('exp')),
        collapsedCaption: 'collapsed caption',
        focusNode: node,
        collapsed: false,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(HeroTileMorph), findsOneWidget);
      // Expanded subtree is visible at t=0 (opacity=1).
      expect(find.byKey(const ValueKey('exp')), findsOneWidget);
    });

    testWidgets('toggling collapsed: false → true drives state machine to idleCollapsed',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final node = FocusNode();
      addTearDown(node.dispose);

      var collapsed = false;
      late StateSetter setOuter;
      await tester.pumpWidget(_harness(StatefulBuilder(builder: (ctx, set) {
        setOuter = set;
        return HeroTileMorph(
          expandedChild: const SizedBox(),
          collapsedCaption: 'cap',
          focusNode: node,
          collapsed: collapsed,
        );
      })));
      await tester.pumpAndSettle();

      // Flip the flag — animation should now run.
      setOuter(() => collapsed = true);
      await tester.pump(); // schedule the controller.forward()
      // After 350ms the 300ms controller has completed.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final state =
          tester.state(find.byType(HeroTileMorph)) as State<HeroTileMorph>;
      // Use the @visibleForTesting getter via dynamic.
      // ignore: avoid_dynamic_calls
      expect((state as dynamic).debugState, HeroMorphState.idleCollapsed);
    });
  });
}
