import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/mobile/widgets/m_icon_btn.dart';

Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('MIconBtn', () {
    testWidgets('tap callback fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(
          child: MIconBtn(
            icon: Icons.play_arrow,
            onTap: () => taps += 1,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(MIconBtn));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('respects 44x44 minimum touch area', (tester) async {
      await tester.pumpWidget(
        _harness(
          child: MIconBtn(icon: Icons.play_arrow, onTap: () {}),
        ),
      );
      await tester.pump();

      final size = tester.getSize(find.byType(MIconBtn));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });
}
