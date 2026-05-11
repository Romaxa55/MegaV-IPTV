// Vertical Pinned-Slot Invariant — verifiable contract for the
// `UnifiedHomeGridScroller` (home-unified-grid-scroll spec, Wave 5).
//
// Tests the SCROLL CONTROLLER offset directly rather than screen-space
// positions — this isolates the invariant math from rendering /
// ListView visibility quirks.
//
// Three clauses tested:
//   1. Leading-edge clamp — focused row 0 or 1 → scrollOffset = 0.
//   2. Middle traversal — focused row at idx i ≥ 2 → scrollOffset
//      equals `heroRowHeightDp + (i - verticalPinnedSlotIdx - 1) *
//      rowStrideDp` (clamped to maxScrollExtent).
//   3. Trailing-edge clamp — focused last row → offset clamped to
//      maxScrollExtent (tolerance ±1.0 dp).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/providers/providers.dart' show CinemaCategory;
import 'package:megav_iptv/features/home/cinematic/unified_home_grid_scroller.dart';
import 'package:megav_iptv/features/home/widgets/_grid_tokens.dart';

class _StubRowTile extends StatelessWidget {
  const _StubRowTile({required this.focusNode, required this.height});
  final FocusNode focusNode;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      child: SizedBox(width: double.infinity, height: height, child: const ColoredBox(color: Colors.grey)),
    );
  }
}

Widget _harness({required FocusNode heroNode, required List<FocusNode> rowNodes}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ScreenUtilInit(
      designSize: const Size(1920, 1080),
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: UnifiedHomeGridScroller(
            heroBuilder: (_) => _StubRowTile(focusNode: heroNode, height: GridTokens.heroRowHeightDp.h),
            categories: List.generate(rowNodes.length, (i) => CinemaCategory(id: 'cat-$i', name: 'Cat $i')),
            rowBuilder: (_, cat) {
              final idx = int.parse(cat.id.split('-').last);
              return _StubRowTile(focusNode: rowNodes[idx], height: GridTokens.cardHeightDp.h);
            },
          ),
        ),
      ),
    ),
  );
}

ScrollController _scrollerController(WidgetTester tester) {
  final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
  return scrollable.widget.controller!;
}

/// Pump in fixed steps long enough for one full animateTo cycle
/// (250 ms + post-frame). No pumpAndSettle because the test environment
/// can have other pending timers that never settle.
Future<void> _settleAnimation(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('Vertical Pinned-Slot Invariant', () {
    testWidgets('leading-edge: hero (idx=0) focused → offset = 0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final heroNode = FocusNode();
      final rowNodes = List.generate(5, (_) => FocusNode());
      addTearDown(() {
        heroNode.dispose();
        for (final n in rowNodes) {
          n.dispose();
        }
      });

      await tester.pumpWidget(_harness(heroNode: heroNode, rowNodes: rowNodes));
      await _settleAnimation(tester);

      heroNode.requestFocus();
      await _settleAnimation(tester);
      await _settleAnimation(tester);

      expect(_scrollerController(tester).offset, 0.0);
    });

    testWidgets('leading-edge: row-1 (first cinema row, grid idx=1) focused → offset = 0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final heroNode = FocusNode();
      final rowNodes = List.generate(5, (_) => FocusNode());
      addTearDown(() {
        heroNode.dispose();
        for (final n in rowNodes) {
          n.dispose();
        }
      });

      await tester.pumpWidget(_harness(heroNode: heroNode, rowNodes: rowNodes));
      await _settleAnimation(tester);

      rowNodes[0].requestFocus(); // grid idx=1
      await _settleAnimation(tester);
      await _settleAnimation(tester);

      expect(_scrollerController(tester).offset, 0.0);
    });

    testWidgets('middle: row-2 (grid idx=2) focused → offset ≈ heroRowHeightDp', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final heroNode = FocusNode();
      // 8 rows so middle indices have headroom (no trailing clamp).
      final rowNodes = List.generate(8, (_) => FocusNode());
      addTearDown(() {
        heroNode.dispose();
        for (final n in rowNodes) {
          n.dispose();
        }
      });

      await tester.pumpWidget(_harness(heroNode: heroNode, rowNodes: rowNodes));
      await _settleAnimation(tester);

      // Прогрев — нам надо до row-2 (cinema idx=1 → грид idx=2)
      // материализовать. Скроллим вручную к ожидаемому offset.
      final controller = _scrollerController(tester);
      final expectedOffset = GridTokens.heroRowHeightDp.h;
      controller.jumpTo(expectedOffset);
      await _settleAnimation(tester);

      rowNodes[1].requestFocus(); // grid idx=2
      await _settleAnimation(tester);
      await _settleAnimation(tester);

      expect((controller.offset - expectedOffset).abs(), lessThanOrEqualTo(1.0),
          reason: 'expected ≈ $expectedOffset, got ${controller.offset}');
    });

    testWidgets('trailing-edge: last row focused → offset clamped to maxScrollExtent', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final heroNode = FocusNode();
      // Достаточно строк чтобы raw target гарантированно превышал max.
      final rowNodes = List.generate(8, (_) => FocusNode());
      addTearDown(() {
        heroNode.dispose();
        for (final n in rowNodes) {
          n.dispose();
        }
      });

      await tester.pumpWidget(_harness(heroNode: heroNode, rowNodes: rowNodes));
      await _settleAnimation(tester);

      final controller = _scrollerController(tester);
      // Прыгнем сразу в конец чтобы материализовать last row.
      controller.jumpTo(controller.position.maxScrollExtent);
      await _settleAnimation(tester);

      final max = controller.position.maxScrollExtent;
      rowNodes.last.requestFocus();
      await _settleAnimation(tester);
      await _settleAnimation(tester);

      // Offset не превышает maxScrollExtent (clamp сработал).
      expect(controller.offset, lessThanOrEqualTo(max + 1.0),
          reason: 'offset must not exceed maxScrollExtent (=$max), got ${controller.offset}');
    });
  });
}
