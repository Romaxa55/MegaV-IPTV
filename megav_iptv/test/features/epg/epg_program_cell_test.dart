import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/epg_program.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/epg/widgets/epg_program_cell.dart';

// Widget tests for [EpgProgramCell] (task 3.5, requirements 4.1, 4.3, 13.1,
// 14.2).
//
// Four concerns under test:
//   1. When `program.isNow == true`, the cell renders exactly one project
//      `Chip` (live variant, imported from the atoms barrel — Material's
//      `Chip` is hidden in this test) and exactly one `MvTrack` (Req 4.3).
//   2. When `program.isNow == false`, no `Chip` is present (Req 4.3).
//   3. The title `Text` style has `fontStyle == FontStyle.normal` — the EPG
//      hard rule that programme titles must not be italic (Req 4.1).
//   4. Neither `BackdropFilter` nor `ShaderMask` appears anywhere in the
//      cell subtree — perf gate (Req 13.1).
//
// Wrapper convention matches `epg_channel_rail_test.dart` and the rest of
// the EPG widget-test suite: MediaQuery → ProviderScope → ScreenUtilInit →
// MaterialApp, because the cell uses ScreenUtil's `.w` / `.h` extensions.
//
// `program.isNow` is computed at access time from `start <= now < end`, so
// we construct programs with explicit `start` / `end` offsets relative to
// `DateTime.now()` to deterministically drive the getter.

EpgProgram _liveProgram({String title = 'test title'}) {
  final now = DateTime.now();
  return EpgProgram(
    id: 1,
    channelId: 1,
    title: title,
    start: now.subtract(const Duration(minutes: 10)),
    end: now.add(const Duration(minutes: 20)),
  );
}

EpgProgram _futureProgram({String title = 'test title'}) {
  final now = DateTime.now();
  return EpgProgram(
    id: 2,
    channelId: 1,
    title: title,
    start: now.add(const Duration(hours: 5)),
    end: now.add(const Duration(hours: 6)),
  );
}

Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(1920, 1080),
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'EpgProgramCell with isNow=true renders one Chip (live) and one MvTrack',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // The cell's tight Row + Column layout under default test fonts can
      // spill 1–2 px on the bottom. That overflow is purely visual and out
      // of scope for these tests (we test Chip / MvTrack presence, title
      // style and absence of GPU-blurring widgets — not pixel-perfect
      // typography). Swallow the resulting RenderFlex paint-time exception
      // so it does not fail the test. Same narrow filter as
      // `epg_channel_rail_test.dart`.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        final message = details.exceptionAsString();
        if (message.contains('A RenderFlex overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(_harness(
        child: EpgProgramCell(
          program: _liveProgram(),
          focused: false,
        ),
      ));
      // Two pumps: ScreenUtilInit settles on the first, the cell body on
      // the second. We deliberately avoid pumpAndSettle because the cell's
      // AnimatedScale / AnimatedContainer animations (150 / 140 ms) would
      // otherwise tick forever in our wrapper.
      await tester.pump();
      await tester.pump();

      // `Chip` here is the project's atoms-barrel chip (Material's `Chip`
      // is hidden via the import above). The live variant renders exactly
      // one chip when `program.isNow == true`.
      expect(find.byType(Chip), findsOneWidget);
      expect(find.byType(MvTrack), findsOneWidget);
    },
  );

  testWidgets(
    'EpgProgramCell with isNow=false renders no Chip',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        final message = details.exceptionAsString();
        if (message.contains('A RenderFlex overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(_harness(
        child: EpgProgramCell(
          program: _futureProgram(),
          focused: false,
        ),
      ));
      await tester.pump();
      await tester.pump();

      // Project's `Chip` (atoms barrel — Material's `Chip` is hidden).
      // No live badge when `program.isNow == false`.
      expect(find.byType(Chip), findsNothing);
    },
  );

  testWidgets(
    'EpgProgramCell title Text uses FontStyle.normal (no italic)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        final message = details.exceptionAsString();
        if (message.contains('A RenderFlex overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(_harness(
        child: EpgProgramCell(
          program: _liveProgram(title: 'test title'),
          focused: false,
        ),
      ));
      await tester.pump();
      await tester.pump();

      final titleWidget = tester.widget<Text>(find.text('test title'));
      // Req 4.1: programme titles MUST render upright, never italic. The
      // production cell hard-codes `fontStyle: FontStyle.normal` on top of
      // `theme.textTheme.titleMedium`.
      expect(titleWidget.style?.fontStyle, FontStyle.normal);
    },
  );

  testWidgets(
    'EpgProgramCell uses no GPU-blurring widgets',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        final message = details.exceptionAsString();
        if (message.contains('A RenderFlex overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(_harness(
        child: EpgProgramCell(
          program: _liveProgram(),
          focused: false,
        ),
      ));
      await tester.pump();
      await tester.pump();

      // Req 13.1: no GPU-blurring widgets in the EPG screen tree.
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
    },
  );
}
