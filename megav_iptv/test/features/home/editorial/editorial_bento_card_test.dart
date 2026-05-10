import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/epg_program.dart';
import 'package:megav_iptv/core/playlist/models/now_playing.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/home/editorial/editorial_bento_card.dart';

NowPlayingItem _mockItem({String title = 'Зеркало', int channelId = 42}) {
  final now = DateTime(2026, 5, 9, 21, 0);
  return NowPlayingItem(
    channelId: channelId,
    channelName: 'Канал «Авто»',
    groupTitle: 'Драма',
    logoUrl: 'https://example.test/logo.png',
    thumbnailUrl: 'https://example.test/thumb.jpg',
    program: EpgProgram(
      id: 1,
      channelId: channelId,
      title: title,
      description: '1975 г.\n\nКраткое описание.',
      category: 'Драма',
      icon: 'https://example.test/poster.jpg',
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

double _titleFontSize(WidgetTester tester, String title) {
  final textWidget = tester.widget<Text>(find.text(title));
  return textWidget.style!.fontSize!;
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
    'EditorialBentoCard: 2x2 live cell renders 36 sp italic title + Live chip',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final cell = EditorialBentoCell(
        item: _mockItem(title: 'Сталкер', channelId: 1),
        cols: 2,
        rows: 2,
        live: true,
      );

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 800,
            height: 600,
            child: EditorialBentoCard(cell: cell),
          ),
        ),
      );
      await tester.pump();

      expect(_titleFontSize(tester, 'Сталкер'), 36);
      expect(find.byType(Chip), findsOneWidget);
    },
  );

  testWidgets(
    'EditorialBentoCard: 1x1 non-live cell renders 20 sp title + no chip',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final cell = EditorialBentoCell(
        item: _mockItem(title: 'Солярис', channelId: 2),
        cols: 1,
        rows: 1,
      );

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 300,
            height: 220,
            child: EditorialBentoCard(cell: cell),
          ),
        ),
      );
      await tester.pump();

      expect(_titleFontSize(tester, 'Солярис'), 20);
      expect(find.byType(Chip), findsNothing);
    },
  );

  testWidgets(
    'EditorialBentoCard does not introduce any BackdropFilter (Req 9.1)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final cell = EditorialBentoCell(
        item: _mockItem(channelId: 3),
        cols: 2,
        rows: 2,
        live: true,
      );

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 800,
            height: 600,
            child: EditorialBentoCard(cell: cell),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(BackdropFilter), findsNothing);
    },
  );

  testWidgets(
    'EditorialBentoCard: tap fires onTap callback',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var tapped = 0;
      final cell = EditorialBentoCell(
        item: _mockItem(channelId: 4),
        cols: 2,
        rows: 2,
      );

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 800,
            height: 600,
            child: EditorialBentoCard(
              cell: cell,
              onTap: () => tapped++,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(EditorialBentoCard));
      await tester.pump();

      expect(tapped, 1);
    },
  );

  testWidgets(
    'EditorialBentoCard: focus + 400ms wait fires onFocusChange(true)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool? lastFocus;

      final cell = EditorialBentoCell(
        item: _mockItem(channelId: 5),
        cols: 2,
        rows: 2,
      );

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 800,
            height: 600,
            child: EditorialBentoCard(
              cell: cell,
              onFocusChange: (v) => lastFocus = v,
            ),
          ),
        ),
      );
      await tester.pump();

      // Walk into a descendant of the inner Focus so Focus.of() can
      // find the Focus ancestor and return its node. Transform.scale
      // sits directly under the bento card's Focus, so its element
      // gives us a context with that Focus as ancestor.
      final innerChildFinder = find
          .descendant(
            of: find.byType(EditorialBentoCard),
            matching: find.byType(Transform),
          )
          .first;
      final element = tester.element(innerChildFinder);
      final node = Focus.of(element);
      node.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 410));

      expect(lastFocus, isTrue);
    },
  );
}
