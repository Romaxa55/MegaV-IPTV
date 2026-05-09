import 'package:flutter/material.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/ui/atoms/atoms.dart';
import 'inline_epg_bar.dart';

/// Cinematic bottom panel: SafePill wrapper containing inline EPG + action
/// row + remote hint footer.
///
/// Maps to Req 3, Req 4, Req 8, Req 9.1, Req 12.
class CinematicBottomPanel extends StatelessWidget {
  const CinematicBottomPanel({
    super.key,
    this.programTitle,
    this.epgStart,
    this.epgEnd,
    this.actionFocusScope,
    this.onPlayPause,
    this.onAudio,
    this.onSubs,
    this.onInfo,
    this.onChannelsToggle,
    required this.isPlaying,
    this.hintMode,
  });

  final String? programTitle;
  final DateTime? epgStart;
  final DateTime? epgEnd;
  final FocusScopeNode? actionFocusScope;
  final VoidCallback? onPlayPause;
  final VoidCallback? onAudio;
  final VoidCallback? onSubs;
  final VoidCallback? onInfo;
  final VoidCallback? onChannelsToggle;
  final bool isPlaying;
  final String? hintMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SafePill(
        tint: AppColors.surface,
        alpha: 0.85,
        borderRadius: AppRadius.brLg,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InlineEpgBar(programTitle: programTitle, startAt: epgStart, endAt: epgEnd),
            const SizedBox(height: 12),
            FocusScope(
              node: actionFocusScope,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MvIconButton(icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow), onPressed: onPlayPause ?? () {}),
                  const SizedBox(width: 12),
                  MvIconButton(icon: const Icon(Icons.audiotrack), onPressed: onAudio ?? () {}),
                  const SizedBox(width: 12),
                  MvIconButton(icon: const Icon(Icons.subtitles), onPressed: onSubs ?? () {}),
                  const SizedBox(width: 12),
                  MvIconButton(icon: const Icon(Icons.info_outline), onPressed: onInfo ?? () {}),
                  const SizedBox(width: 12),
                  MvIconButton(icon: const Icon(Icons.menu), onPressed: onChannelsToggle ?? () {}),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const RemoteHint(
              hints: [
                RemoteHintEntry(glyph: '↑↓', label: 'Каналы'),
                RemoteHintEntry(glyph: 'OK', label: 'Меню'),
                RemoteHintEntry(glyph: 'BACK', label: 'Назад'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
