import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/perf/perf_safe_widgets.dart';
import 'package:megav_iptv/features/settings/widgets/mv_toggle.dart';

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
  group('MvToggle', () {
    testWidgets('initial off renders thumb on the left', (tester) async {
      await tester.pumpWidget(
        _harness(child: MvToggle(value: false, onChanged: (_) {})),
      );
      await tester.pump();

      final align = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
      expect(align.alignment, Alignment.centerLeft);
    });

    testWidgets('toggle to true positions thumb on the right', (tester) async {
      bool current = false;
      await tester.pumpWidget(
        _harness(
          child: StatefulBuilder(
            builder: (ctx, setState) => MvToggle(
              value: current,
              onChanged: (v) => setState(() => current = v),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap the toggle to switch state.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      final align = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
      expect(align.alignment, Alignment.centerRight);
    });

    testWidgets('contains a SafeFocusRing for focus visual', (tester) async {
      await tester.pumpWidget(
        _harness(child: MvToggle(value: false, onChanged: (_) {})),
      );
      await tester.pump();

      // SafeFocusRing wraps the pill — should always render at least once.
      expect(find.byType(SafeFocusRing), findsAtLeastNWidgets(1));
    });
  });
}
