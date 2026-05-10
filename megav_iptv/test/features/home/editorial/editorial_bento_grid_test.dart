import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/epg_program.dart';
import 'package:megav_iptv/core/playlist/models/now_playing.dart';
import 'package:megav_iptv/features/home/editorial/editorial_bento_card.dart';
import 'package:megav_iptv/features/home/editorial/editorial_bento_grid.dart';

NowPlayingItem _mockItem(int id, String title) {
  final now = DateTime(2026, 5, 9, 21, 0);
  return NowPlayingItem(
    channelId: id,
    channelName: 'Канал $id',
    groupTitle: 'Драма',
    logoUrl: 'https://example.test/logo$id.png',
    thumbnailUrl: 'https://example.test/thumb$id.jpg',
    program: EpgProgram(
      id: id,
      channelId: id,
      title: title,
      description: '198$id г.\n\nОписание.',
      category: 'Драма',
      icon: 'https://example.test/poster$id.jpg',
      start: now,
      end: now.add(const Duration(minutes: 90)),
    ),
  );
}

List<EditorialBentoCell> _mockCells() => [
      EditorialBentoCell(item: _mockItem(1, 'Один'), cols: 2, rows: 2),
      EditorialBentoCell(item: _mockItem(2, 'Два'), cols: 2, rows: 1),
      EditorialBentoCell(item: _mockItem(3, 'Три'), cols: 2, rows: 1),
      EditorialBentoCell(item: _mockItem(4, 'Четыре'), cols: 1, rows: 1),
      EditorialBentoCell(item: _mockItem(5, 'Пять'), cols: 1, rows: 1),
      EditorialBentoCell(item: _mockItem(6, 'Шесть'), cols: 2, rows: 1),
    ];

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
            home: Scaffold(
              body: SingleChildScrollView(child: child),
            ),
          );
        },
      ),
    ),
  );
}

void main() {
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
    'EditorialBentoGrid: pumps with 6 cells, key present, 6 cards rendered',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 1760,
            child: EditorialBentoGrid(cells: _mockCells()),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('editorial-bento-grid')),
        findsOneWidget,
      );
      expect(find.byType(EditorialBentoCard), findsNWidgets(6));
    },
  );

  testWidgets(
    'EditorialBentoGrid: tap on first card fires onItemTap with first item',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final cells = _mockCells();
      NowPlayingItem? tapped;

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 1760,
            child: EditorialBentoGrid(
              cells: cells,
              onItemTap: (item) => tapped = item,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(EditorialBentoCard).first);
      await tester.pump();

      expect(tapped, isNotNull);
      expect(tapped!.channelId, cells.first.item.channelId);
    },
  );

  testWidgets(
    'EditorialBentoGrid: no BackdropFilter or ShaderMask anywhere (Req 9.1)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 1760,
            child: EditorialBentoGrid(cells: _mockCells()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
    },
  );
}
