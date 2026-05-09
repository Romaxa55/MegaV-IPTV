import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/now_playing.dart';
import 'package:megav_iptv/features/home/widgets/cinema_row.dart';

NowPlayingItem _item(int id) => NowPlayingItem(
      channelId: id,
      channelName: 'Channel $id',
      groupTitle: 'Movies',
      logoUrl: null,
      thumbnailUrl: null,
      program: null,
    );

/// Wraps the [child] in a runtime-realistic harness so screenutil resolves
/// `.w/.h/.sp` to identity scale (designSize == runtime size).
///
/// IMPORTANT: must be paired with `tester.binding.setSurfaceSize(Size(1920, 1080))`
/// so the actual render surface matches the MediaQuery override.
Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ScreenUtilInit(
      designSize: const Size(1920, 1080),
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: child,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'CinemaRow renders exactly one ShaderMask wrapping the inner ListView (Req 1.1)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final items = List.generate(6, (i) => _item(100 + i));

      await tester.pumpWidget(
        _harness(
          child: CinemaRow(
            title: 'Test',
            items: items,
            onItemTap: (_) {},
            onItemFocus: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Test 1: Exactly one ShaderMask is present in the row's tree.
      expect(
        find.byType(ShaderMask),
        findsOneWidget,
        reason: 'CinemaRow must render exactly one ShaderMask for the right '
            'edge fade-out (Req 1.1).',
      );

      // Test 2: The ShaderMask uses BlendMode.dstOut so transparent stops keep
      // content opaque and the right-edge stop carves a fade-out.
      final shaderMask = tester.widget<ShaderMask>(find.byType(ShaderMask));
      expect(
        shaderMask.blendMode,
        BlendMode.dstOut,
        reason: 'ShaderMask must use BlendMode.dstOut so the right-edge gradient '
            'cuts a fade-out instead of compositing colour (Req 1.1).',
      );

      // Test 3: The ShaderMask is an ancestor of the inner ListView — i.e. the
      // mask actually wraps the scrolling content, not some unrelated subtree.
      expect(
        find.descendant(
          of: find.byType(ShaderMask),
          matching: find.byType(ListView),
        ),
        findsOneWidget,
        reason: 'ShaderMask must wrap the row\'s ListView so the fade-out '
            'applies to the scrolling tiles (Req 1.1).',
      );
    },
  );
}
