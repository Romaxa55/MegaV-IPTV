import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/epg/epg_screen.dart';

// Phase-2 smoke test for the empty [EpgScreen] skeleton.
//
// Scope (task 2.3, requirements 13.1, 14.2, 14.3):
//   * EpgScreen mounts without exception under ProviderScope + MaterialApp.
//   * Root Scaffold key 'epg-screen-root' is present.
//   * No BackdropFilter / ShaderMask anywhere in the tree (flat-fill rule).
//
// TODO(phase 5): once EpgScreen body consumes `epgWindowProvider`, add a
// `ProviderScope(overrides: [epgWindowProvider.overrideWith(...)])` so this
// smoke test continues to be hermetic. In Phase-2 the screen body is
// `SizedBox.shrink()` for every state, so overriding the family provider
// here is unnecessary scaffolding.
Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(1920, 1080),
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: child,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'EpgScreen Phase-2 skeleton mounts with key and zero blur effects',
    (tester) async {
      await tester.pumpWidget(_harness(child: const EpgScreen()));
      // Two pumps: first settles ScreenUtilInit, second settles ConsumerState
      // initial build. Avoids pumpAndSettle() so we do not mask any
      // accidentally introduced infinite animations.
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('epg-screen-root')), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
    },
  );
}
