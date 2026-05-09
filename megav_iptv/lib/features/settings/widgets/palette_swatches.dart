import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/theme/app_palettes.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/theme/theme_provider.dart';

/// 6-swatch grid that previews each [AppPaletteName] and writes the
/// active palette through [themeProvider]. Per Req 3.4 / 3.5 the
/// `setPalette` write happens **only** in the swatch's `onTap`
/// callback — never during build.
class PaletteSwatches extends ConsumerWidget {
  const PaletteSwatches({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(themeProvider);

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      mainAxisSpacing: 16.h,
      crossAxisSpacing: 16.w,
      children: AppPaletteName.values
          .map(
            (name) => RepaintBoundary(
              child: _Swatch(
                name: name,
                isActive: name == active,
                onTap: () => ref.read(themeProvider.notifier).setPalette(name),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _Swatch extends StatefulWidget {
  const _Swatch({required this.name, required this.isActive, required this.onTap});

  final AppPaletteName name;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_Swatch> createState() => _SwatchState();
}

class _SwatchState extends State<_Swatch> {
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
    final palette = widget.name.palette;
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final labelStyle = styles?.bodyDefault ?? theme.textTheme.bodyMedium;

    return SafeFocusRing(
      isFocused: _focusNode.hasFocus,
      child: Focus(
        focusNode: _focusNode,
        onFocusChange: (_) => setState(() {}),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              color: palette.surface1,
              borderRadius: AppRadius.brMd,
              border: widget.isActive
                  ? Border(
                      left: BorderSide(color: palette.accent, width: 4.w),
                    )
                  : null,
            ),
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _bar(palette.background),
                    SizedBox(width: 4.w),
                    _bar(palette.accent),
                    SizedBox(width: 4.w),
                    _bar(palette.accentGlow),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(widget.name.displayName, style: labelStyle, maxLines: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(Color color) => Expanded(
    child: Container(
      height: 24.h,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
    ),
  );
}
