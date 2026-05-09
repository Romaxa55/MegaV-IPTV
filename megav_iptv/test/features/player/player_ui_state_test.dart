import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/features/player/player_screen.dart';
import 'package:megav_iptv/features/player/widgets/player_overlay.dart';

void main() {
  group('PlayerUiState sealed type', () {
    test('HiddenState is constructable as const', () {
      const state = HiddenState();
      expect(state, isA<PlayerUiState>());
      expect(state, isA<HiddenState>());
    });

    test('ControlsState round-trips hideAt', () {
      final t = DateTime(2026, 5, 9, 14, 30);
      final state = ControlsState(hideAt: t);
      expect(state.hideAt, t);
      expect(state, isA<PlayerUiState>());
    });

    test('BriefOsdState round-trips hideAt', () {
      final t = DateTime(2026, 5, 9, 14, 30);
      final state = BriefOsdState(hideAt: t);
      expect(state.hideAt, t);
      expect(state, isA<PlayerUiState>());
    });

    test('SwitchPreviewState round-trips previewChannel and commitAt', () {
      const ch = Channel(
        id: 1234,
        name: 'Test Channel',
        groupTitle: 'Test',
      );
      final t = DateTime(2026, 5, 9, 14, 30);
      final state = SwitchPreviewState(previewChannel: ch, commitAt: t);
      expect(state.previewChannel.id, 1234);
      expect(state.previewChannel.name, 'Test Channel');
      expect(state.commitAt, t);
      expect(state, isA<PlayerUiState>());
    });

    test('OverlayState round-trips mode for each PlayerOverlayMode value', () {
      for (final mode in PlayerOverlayMode.values) {
        final state = OverlayState(mode: mode);
        expect(state.mode, mode);
        expect(state, isA<PlayerUiState>());
      }
    });

    test('exhaustive switch over PlayerUiState compiles and dispatches each variant', () {
      // Smoke test that the sealed switch is exhaustive and returns a non-null
      // String for each variant. If a new variant is ever added without
      // updating this switch, Dart compiler will fail this test at compile time.
      String label(PlayerUiState s) => switch (s) {
        HiddenState() => 'hidden',
        ControlsState() => 'controls',
        BriefOsdState() => 'brief',
        SwitchPreviewState() => 'switchPreview',
        OverlayState() => 'overlay',
      };

      const ch = Channel(id: 1, name: 'X');
      expect(label(const HiddenState()), 'hidden');
      expect(label(ControlsState(hideAt: DateTime(2026))), 'controls');
      expect(label(BriefOsdState(hideAt: DateTime(2026))), 'brief');
      expect(
        label(SwitchPreviewState(previewChannel: ch, commitAt: DateTime(2026))),
        'switchPreview',
      );
      expect(label(const OverlayState(mode: PlayerOverlayMode.epg)), 'overlay');
    });
  });
}
