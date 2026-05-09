import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/core/providers/providers.dart';
import 'package:megav_iptv/features/detail/detail_screen.dart';

/// Wraps [child] in a runtime-realistic harness so `flutter_screenutil`
/// extensions (`.w`, `.h`, `.sp`) resolve. Mirrors the harness pattern used
/// by other widget tests under `test/features/home/widgets/`.
Widget _harness({required Widget child, required List<Override> overrides}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ProviderScope(
      overrides: overrides,
      child: ScreenUtilInit(
        designSize: const Size(1920, 1080),
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: child,
        ),
      ),
    ),
  );
}

void main() {
  group('DetailScreen', () {
    testWidgets('renders Play button when channel found', (tester) async {
      const testChannelId = 1;
      final testChannel = Channel(id: testChannelId, name: 'Test Channel', groupTitle: 'News');

      await tester.pumpWidget(
        _harness(
          overrides: [
            featuredChannelsProvider.overrideWith((ref) => Future.value([testChannel])),
          ],
          child: const DetailScreen(channelId: testChannelId),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Смотреть'), findsOneWidget);
    });

    testWidgets('graceful fallback when channel not found', (tester) async {
      await tester.pumpWidget(
        _harness(
          overrides: [
            featuredChannelsProvider.overrideWith((ref) => Future.value(<Channel>[])),
          ],
          child: const DetailScreen(channelId: 999),
        ),
      );
      await tester.pumpAndSettle();

      // No Play button — graceful fallback rendered instead
      expect(find.text('Смотреть'), findsNothing);
      expect(find.textContaining('999'), findsAtLeastNWidgets(1));
    });
  });
}
