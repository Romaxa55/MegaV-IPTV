import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';

/// 44×24 pill toggle with a 18×18 white thumb that animates between
/// alignments. Performance budget: no per-frame blur layers; optional
/// active glow uses [BoxShadow] capped at [kSafeShadowBlurMax]
/// (Req 10.x, 12.x).
class MvToggle extends StatefulWidget {
  const MvToggle({super.key, required this.value, required this.onChanged, this.label, this.subText});

  /// Current on/off state.
  final bool value;

  /// Tap callback. Receives the inverted value.
  final ValueChanged<bool> onChanged;

  /// Optional row label rendered after the pill.
  final String? label;

  /// Optional secondary line under [label] (dimmed style).
  final String? subText;

  @override
  State<MvToggle> createState() => _MvToggleState();
}

class _MvToggleState extends State<MvToggle> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.activePalette;
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final labelStyle = styles?.bodyDefault ?? theme.textTheme.bodyMedium;
    final subStyle = styles?.bodyDim ?? theme.textTheme.bodySmall;

    final pill = SafeFocusRing(
      isFocused: _focusNode.hasFocus,
      child: Container(
        width: 44.w,
        height: 24.h,
        decoration: BoxDecoration(
          color: widget.value ? palette.accent : palette.surface2,
          borderRadius: BorderRadius.circular(12),
          boxShadow: widget.value ? [BoxShadow(color: palette.accentGlow, blurRadius: kSafeShadowBlurMax)] : null,
        ),
        child: AnimatedAlign(
          alignment: widget.value ? Alignment.centerRight : Alignment.centerLeft,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: Container(
            width: 18.w,
            height: 18.h,
            margin: EdgeInsets.all(3.w),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );

    final tappable = Focus(
      focusNode: _focusNode,
      onFocusChange: (_) => setState(() {}),
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        behavior: HitTestBehavior.opaque,
        child: pill,
      ),
    );

    if (widget.label == null) return tappable;

    return Row(
      children: [
        tappable,
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.label!, style: labelStyle),
              if (widget.subText != null) Text(widget.subText!, style: subStyle),
            ],
          ),
        ),
      ],
    );
  }
}
