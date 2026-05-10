import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/home/mobile/widgets/m_stacked_rail.dart';

Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('MStackedRail', () {
    testWidgets('renders key, GridView, and a Poster per item', (tester) async {
      final items = const [
        Channel(id: 1, name: 'A'),
        Channel(id: 2, name: 'B'),
        Channel(id: 3, name: 'C'),
        Channel(id: 4, name: 'D'),
      ];

      await tester.pumpWidget(
        _harness(
          child: MStackedRail(
            title: 'Кино',
            emphasis: 'для вечера',
            items: items,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('m-stacked-rail')), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(Poster), findsNWidgets(4));
    });
  });
}
