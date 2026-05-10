import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/home/editorial/editorial_masthead.dart';

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

const _label = 'Главная';
const _emphasis = 'сегодня';
const _dateLine = '9 МАЯ 2026';
const _issueNumber = 127;

const _masthead = EditorialMasthead(
  label: _label,
  emphasis: _emphasis,
  dateLine: _dateLine,
  issueNumber: _issueNumber,
);

void main() {
  testWidgets(
    'EditorialMasthead renders label, italic emphasis and dateline · ВЫПУСК №NNN',
    (tester) async {
      await tester.pumpWidget(_wrap(_masthead));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('editorial-masthead')), findsOneWidget);
      // The label + emphasis live inside a RichText (TextSpan tree) — drill
      // into spans via `findRichText: true`. The dateline lives in a Text
      // widget so the default text matcher is enough.
      expect(
        find.textContaining(_label, findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining(_emphasis, findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('9 МАЯ 2026 · ВЫПУСК №127'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'EditorialMasthead emphasis fragment uses italic FontStyle',
    (tester) async {
      await tester.pumpWidget(_wrap(_masthead));
      await tester.pump();
      await tester.pump();

      // Walk RichText spans and assert at least one descendant TextSpan
      // is italicised — that is the emphasis fragment.
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      var italicFound = false;
      for (final rt in richTexts) {
        rt.text.visitChildren((span) {
          if (span is TextSpan && span.style?.fontStyle == FontStyle.italic) {
            italicFound = true;
          }
          return true;
        });
        if (italicFound) break;
      }
      expect(italicFound, isTrue,
          reason: 'Emphasis TextSpan must be italicised (Req 2.2)');
    },
  );

  testWidgets(
    'EditorialMasthead root Container draws a non-default bottom hairline border',
    (tester) async {
      await tester.pumpWidget(_wrap(_masthead));
      await tester.pump();
      await tester.pump();

      // The keyed root is itself a Container — locate it via the Key first
      // to disambiguate from any wrapper Container introduced by the test
      // shell or theme.
      final container = tester.widget<Container>(
        find.byKey(const Key('editorial-masthead')),
      );
      final decoration = container.decoration;
      expect(decoration, isA<BoxDecoration>());
      final border = (decoration as BoxDecoration).border;
      expect(border, isNotNull);
      // Any Border subclass exposes `.bottom` — verify it is not the
      // zero-width default that Flutter falls back to.
      final bottom = (border as Border).bottom;
      expect(bottom, isNot(BorderSide.none));
      expect(bottom.color.a, greaterThan(0.0));
    },
  );

  testWidgets(
    'EditorialMasthead does not introduce BackdropFilter or ShaderMask',
    (tester) async {
      await tester.pumpWidget(_wrap(_masthead));
      await tester.pump();
      await tester.pump();

      // Req 9.1 enforcement — perf gate at the widget-tree level.
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
    },
  );
}
