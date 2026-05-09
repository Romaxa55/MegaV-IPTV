import 'package:flutter/material.dart' hide Chip;

import '../../../core/ui/atoms/atoms.dart';

/// Footer remote-key hints. Wraps atom [RemoteHint] in [IgnorePointer] +
/// [ExcludeFocus] so the row doesn't capture taps or focus traversal,
/// and in [RepaintBoundary] for paint-isolation (Req 9.6).
///
/// Maps to Requirements 7.1-7.3, 9.6, 13.1.
class CinematicRemoteHintFooter extends StatelessWidget {
  const CinematicRemoteHintFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('cinematic-remote-hint'),
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: RepaintBoundary(
        child: ExcludeFocus(
          child: IgnorePointer(
            child: RemoteHint(
              hints: [
                RemoteHintEntry(glyph: '↑↓←→', label: 'Навигация'),
                RemoteHintEntry(glyph: 'OK', label: 'Выбрать'),
                RemoteHintEntry(glyph: 'BACK', label: 'Назад'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
