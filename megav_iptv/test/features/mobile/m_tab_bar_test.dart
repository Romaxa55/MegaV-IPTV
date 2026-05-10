import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/mobile/state/active_mobile_tab_provider.dart';
import 'package:megav_iptv/features/mobile/widgets/m_tab_bar.dart';

Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: child),
        ),
      ),
    ),
  );
}

void main() {
  group('MTabBar', () {
    testWidgets('renders with key and BackdropFilter', (tester) async {
      await tester.pumpWidget(_harness(child: const MTabBar()));
      await tester.pump();

      expect(find.byKey(const Key('m-tab-bar')), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('renders 5 tabs with their labels', (tester) async {
      await tester.pumpWidget(_harness(child: const MTabBar()));
      await tester.pump();

      expect(find.byType(MTab), findsNWidgets(5));
      expect(find.text('Дом'), findsOneWidget);
      expect(find.text('ТВ'), findsOneWidget);
      expect(find.text('Поиск'), findsOneWidget);
      expect(find.text('Гид'), findsOneWidget);
      expect(find.text('Профиль'), findsOneWidget);
    });

    testWidgets('tap on tab index 2 updates activeMobileTabProvider to 2',
        (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        _harness(
          child: Consumer(
            builder: (ctx, ref, _) {
              container = ProviderScope.containerOf(ctx);
              return const MTabBar();
            },
          ),
        ),
      );
      await tester.pump();

      // Initial state.
      expect(container.read(activeMobileTabProvider), 0);

      // Tap the 3rd tab ("Поиск" — index 2).
      await tester.tap(find.text('Поиск'));
      await tester.pump();

      expect(container.read(activeMobileTabProvider), 2);
    });
  });
}
