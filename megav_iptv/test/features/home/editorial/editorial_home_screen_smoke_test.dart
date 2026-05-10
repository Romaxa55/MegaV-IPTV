import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/home/editorial/editorial_home_screen.dart';
import 'package:megav_iptv/features/home/home_variant_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'EditorialHomeScreen mounts skeleton without exception and exposes root key',
    (tester) async {
      // Provide an empty in-memory SharedPreferences so the override below
      // can resolve a real instance synchronously.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1920, 1080)),
          child: ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: ScreenUtilInit(
              designSize: const Size(1920, 1080),
              minTextAdapt: true,
              splitScreenMode: true,
              builder: (context, child) {
                return const MaterialApp(
                  home: EditorialHomeScreen(),
                );
              },
            ),
          ),
        ),
      );

      // Two pumps: first to mount, second to settle ScreenUtilInit's
      // post-frame builder. We avoid pumpAndSettle to keep the test
      // independent of any future animations.
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('editorial-home-root')), findsOneWidget);
    },
  );
}
