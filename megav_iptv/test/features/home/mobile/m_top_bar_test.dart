import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/home/mobile/widgets/m_top_bar.dart';

Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  group('MTopBar', () {
    testWidgets('renders with key and Brand atom', (tester) async {
      await tester.pumpWidget(_harness(child: const MTopBar()));
      await tester.pump();

      expect(find.byKey(const Key('m-top-bar')), findsOneWidget);
      expect(find.byType(Brand), findsOneWidget);
    });

    testWidgets('renders meta column stub strings', (tester) async {
      await tester.pumpWidget(_harness(child: const MTopBar()));
      await tester.pump();

      expect(find.text('Москва'), findsOneWidget);
      expect(find.text('—7°'), findsOneWidget);
      expect(find.text('21:14'), findsOneWidget);
    });
  });
}
