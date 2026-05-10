import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/layout/adaptive_scaffold.dart';

const _mobileKey = Key('mobile-stub');
const _tabletKey = Key('tablet-stub');
const _tvKey = Key('tv-stub');

Widget _harness({
  required double width,
  required double height,
  WidgetBuilder? tablet,
}) {
  return MediaQuery(
    data: MediaQueryData(size: Size(width, height)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: AdaptiveScaffold(
        mobile: (_) => const SizedBox.shrink(key: _mobileKey),
        tablet: tablet,
        tv: (_) => const SizedBox.shrink(key: _tvKey),
      ),
    ),
  );
}

void main() {
  group('AdaptiveScaffold', () {
    testWidgets('390 width → mobile child rendered, tv NOT', (tester) async {
      await tester.pumpWidget(_harness(width: 390, height: 844));
      expect(find.byKey(_mobileKey), findsOneWidget);
      expect(find.byKey(_tvKey), findsNothing);
    });

    testWidgets('1920 width → tv child rendered, mobile NOT', (tester) async {
      await tester.pumpWidget(_harness(width: 1920, height: 1080));
      expect(find.byKey(_tvKey), findsOneWidget);
      expect(find.byKey(_mobileKey), findsNothing);
    });

    testWidgets('1000 width without tablet builder → falls through to tv', (tester) async {
      await tester.pumpWidget(_harness(width: 1000, height: 800));
      expect(find.byKey(_tvKey), findsOneWidget);
      expect(find.byKey(_mobileKey), findsNothing);
      expect(find.byKey(_tabletKey), findsNothing);
    });

    testWidgets('1000 width with explicit tablet builder → tablet child rendered', (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 1000,
          height: 800,
          tablet: (_) => const SizedBox.shrink(key: _tabletKey),
        ),
      );
      expect(find.byKey(_tabletKey), findsOneWidget);
      expect(find.byKey(_tvKey), findsNothing);
      expect(find.byKey(_mobileKey), findsNothing);
    });
  });
}
