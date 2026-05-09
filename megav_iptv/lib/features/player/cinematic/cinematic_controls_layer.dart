/// Renders the cinematic controls layer for `ControlsState` of the
/// `PlayerScreen`. Extracted from `player_screen.dart` to keep that file
/// under the 600-line cap (Task 3.2 of player-cinematic-redesign).
///
/// This is a render-only component — it does NOT touch `_uiState`, never
/// calls `_transition()`. All side-effects (play/pause, channel select,
/// overlay toggle, navigation pop) are routed through callbacks supplied
/// by the parent.
library;

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/providers/cinematic_providers.dart' as cine;
import '../../../core/providers/providers.dart' show currentProgramProvider;
import 'channel_deck.dart';
import 'cinematic_bottom_panel.dart';
import 'cinematic_top_bar.dart';
import 'ken_burns_backdrop.dart';

/// Returns the list of widgets that compose the cinematic controls
/// overlay for the given channel. Ordering matches the closed-spec
/// `_buildOverlayLayer` contract: caller spreads this list into the
/// `Stack` it builds.
List<Widget> buildCinematicControlsLayer({
  required Channel channel,
  required FocusNode topBarFocus,
  required FocusScopeNode actionFocusScope,
  required FocusScopeNode channelDeckFocus,
  required VoidCallback onBack,
  required VoidCallback onPlayPause,
  required VoidCallback onAudio,
  required VoidCallback onSubs,
  required VoidCallback onInfo,
  required void Function(Channel channel) onChannelSelected,
}) {
  return [
    // Layer 1: ken-burns fallback (only active when no video texture).
    Consumer(
      builder: (context, ref, _) {
        final asyncTexture = ref.watch(cine.hasActiveTextureProvider);
        final hasTexture = asyncTexture.valueOrNull ?? false;
        return KenBurnsBackdrop(
          imageProvider: channel.thumbnailUrl != null && channel.thumbnailUrl!.isNotEmpty
              ? NetworkImage(channel.thumbnailUrl!)
              : null,
          active: !hasTexture,
        );
      },
    ),
    // Layers 2-4: cinematic shell with D-pad traversal.
    FocusTraversalGroup(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Top bar.
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Consumer(
                builder: (context, ref, _) {
                  final asyncProgram = ref.watch(currentProgramProvider(channel.id));
                  final program = asyncProgram.valueOrNull;
                  final bitrate = ref.watch(cine.playerBitrateLabelProvider);
                  return CinematicTopBar(
                    channelName: channel.name,
                    programTitle: program?.title ?? '',
                    bitrateLabel: bitrate,
                    focusNode: topBarFocus,
                    onBack: onBack,
                  );
                },
              ),
            ),
          ),
          // Bottom panel with action row + remote hint footer.
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Consumer(
                builder: (context, ref, _) {
                  final asyncProgram = ref.watch(currentProgramProvider(channel.id));
                  final program = asyncProgram.valueOrNull;
                  final asyncPlaying = ref.watch(cine.isPlayingProvider);
                  final isPlaying = asyncPlaying.valueOrNull ?? false;
                  return CinematicBottomPanel(
                    programTitle: program?.title,
                    epgStart: program?.start,
                    epgEnd: program?.end,
                    actionFocusScope: actionFocusScope,
                    onPlayPause: onPlayPause,
                    onAudio: onAudio,
                    onSubs: onSubs,
                    onInfo: onInfo,
                    onChannelsToggle: () => channelDeckFocus.requestFocus(),
                    isPlaying: isPlaying,
                  );
                },
              ),
            ),
          ),
          // Channel deck on the right, gated by focus.
          Align(
            alignment: Alignment.centerRight,
            child: SafeArea(
              child: Consumer(
                builder: (context, ref, _) {
                  final adjacents = ref.watch(cine.adjacentChannelsProvider);
                  return ChannelDeck(
                    isOpen: channelDeckFocus.hasFocus,
                    channels: adjacents,
                    focusScope: channelDeckFocus,
                    onChannelSelected: onChannelSelected,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  ];
}
