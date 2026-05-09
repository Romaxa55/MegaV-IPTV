import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Inline EPG strip showing current programme title + start/now/end times +
/// MvTrack progress. Self-ticks at 1Hz inside a private RepaintBoundary
/// to isolate stream-consumer (Req 9.4).
///
/// Maps to Req 2, Req 9.4, Req 12.1.
class InlineEpgBar extends ConsumerWidget {
  const InlineEpgBar({super.key, this.startAt, this.endAt, this.programTitle});

  final DateTime? startAt;
  final DateTime? endAt;
  final String? programTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final bodyStyle = styles?.bodyDim ?? theme.textTheme.bodySmall;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text(
            programTitle ?? 'Программа не загружена',
            style: bodyStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 6),
        _TickStrip(startAt: startAt, endAt: endAt),
      ],
    );
  }
}

class _TickStrip extends StatefulWidget {
  const _TickStrip({this.startAt, this.endAt});

  final DateTime? startAt;
  final DateTime? endAt;

  @override
  State<_TickStrip> createState() => _TickStripState();
}

class _TickStripState extends State<_TickStrip> {
  late DateTime _now;
  late final Stream<DateTime> _tickStream;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _tickStream = Stream<DateTime>.periodic(const Duration(seconds: 1), (_) => DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final timeStyle = styles?.metaMono ?? theme.textTheme.labelSmall;

    return RepaintBoundary(
      child: StreamBuilder<DateTime>(
        stream: _tickStream,
        builder: (context, snapshot) {
          _now = snapshot.data ?? _now;
          double progress = 0;
          if (widget.startAt != null && widget.endAt != null) {
            final span = widget.endAt!.difference(widget.startAt!).inSeconds;
            final passed = _now.difference(widget.startAt!).inSeconds;
            if (span > 0) progress = (passed / span).clamp(0.0, 1.0);
          }
          return Row(
            children: [
              Text(_fmt(widget.startAt), style: timeStyle),
              const SizedBox(width: 8),
              Expanded(child: MvTrack(progress: progress)),
              const SizedBox(width: 8),
              Text(_fmt(widget.endAt), style: timeStyle),
            ],
          );
        },
      ),
    );
  }

  String _fmt(DateTime? t) {
    if (t == null) return '--:--';
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
