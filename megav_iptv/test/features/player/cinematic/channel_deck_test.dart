import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/features/player/cinematic/channel_deck.dart';

void main() {
  final channels = List.generate(5, (i) => Channel(id: i + 1, name: 'Channel ${i + 1}'));

  group('ChannelDeck', () {
    testWidgets('renders cards when isOpen=true', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: ChannelDeck(isOpen: true, channels: channels)),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Channel 1'), findsOneWidget);
    });

    testWidgets('hides content when isOpen=false', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: ChannelDeck(isOpen: false, channels: channels)),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Channel 1'), findsNothing);
    });

    testWidgets('tap invokes onChannelSelected with correct channel', (tester) async {
      Channel? tapped;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChannelDeck(
                isOpen: true,
                channels: channels,
                onChannelSelected: (ch) => tapped = ch,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Channel 1'));
      expect(tapped?.id, 1);
      expect(tapped?.name, 'Channel 1');
    });

    testWidgets('ListView has TV-tuned perf flags', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: ChannelDeck(isOpen: true, channels: channels)),
          ),
        ),
      );
      await tester.pump();
      final lv = tester.widget<ListView>(find.byType(ListView));
      expect(lv.cacheExtent, 1500.0);
      expect(lv.clipBehavior, Clip.none);
      final delegate = lv.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.addAutomaticKeepAlives, isTrue);
      expect(delegate.addRepaintBoundaries, isTrue);
    });
  });
}
