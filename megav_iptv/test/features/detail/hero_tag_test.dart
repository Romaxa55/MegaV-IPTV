import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/core/providers/providers.dart';
import 'package:megav_iptv/features/detail/detail_screen.dart';

void main() {
  testWidgets('DetailScreen has Hero with channel-poster-{id} tag', (tester) async {
    const testChannelId = 42;
    final testChannel = Channel(id: testChannelId, name: 'Test Hero', groupTitle: 'X');

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1920, 1080)),
        child: ProviderScope(
          overrides: [
            featuredChannelsProvider.overrideWith((ref) => Future.value([testChannel])),
          ],
          child: ScreenUtilInit(
            designSize: const Size(1920, 1080),
            builder: (context, _) => const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: DetailScreen(channelId: testChannelId),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final heroFinder = find.byWidgetPredicate(
      (w) => w is Hero && w.tag == 'channel-poster-42',
    );
    expect(heroFinder, findsOneWidget);
  });
}
