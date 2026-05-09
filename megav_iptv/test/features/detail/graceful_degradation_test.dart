import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/core/providers/providers.dart';
import 'package:megav_iptv/features/detail/detail_screen.dart';
import 'package:megav_iptv/features/detail/providers/detail_data_provider.dart';

void main() {
  testWidgets('Empty cast and related → no В ролях / Похожие sections', (tester) async {
    const testChannelId = 1;
    final testChannel = Channel(id: testChannelId, name: 'Test', groupTitle: 'X');

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1920, 1080)),
        child: ProviderScope(
          overrides: [
            featuredChannelsProvider.overrideWith((ref) => Future.value([testChannel])),
            castListProvider(testChannelId).overrideWith((ref) => const <String>[]),
            relatedChannelsProvider(testChannelId).overrideWith((ref) => const <Channel>[]),
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

    expect(find.text('В ролях'), findsNothing);
    expect(find.text('Похожие'), findsNothing);
  });
}
