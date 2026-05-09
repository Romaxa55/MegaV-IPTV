import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/player/cinematic/cinematic_top_bar.dart';

void main() {
  group('CinematicTopBar', () {
    testWidgets('bitrate chip hidden when bitrateLabel is null', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicTopBar(
                channelName: 'Channel One',
                programTitle: 'Now Playing',
                bitrateLabel: null,
                onBack: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Chip), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('bitrate chip shown when bitrateLabel non-null', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicTopBar(
                channelName: 'C', programTitle: 'P',
                bitrateLabel: '4K HDR', onBack: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Chip), findsNWidgets(2));
      expect(find.text('4K HDR'), findsOneWidget);
    });

    testWidgets('long title is ellipsised', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                child: CinematicTopBar(
                  channelName: 'C',
                  programTitle: 'A very very long program title that should be truncated with ellipsis because it does not fit',
                  onBack: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final tw = tester.widget<Text>(
        find.byWidgetPredicate((w) => w is Text && w.maxLines == 1 && w.overflow == TextOverflow.ellipsis).first,
      );
      expect(tw.maxLines, 1);
      expect(tw.overflow, TextOverflow.ellipsis);
    });

    testWidgets('back button tap invokes callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicTopBar(
                channelName: 'C', programTitle: 'P',
                onBack: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(tapped, isTrue);
    });
  });
}
