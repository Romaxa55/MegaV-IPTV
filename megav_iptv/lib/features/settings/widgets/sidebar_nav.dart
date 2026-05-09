import 'package:flutter/material.dart' hide Chip;
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// 6-item sidebar with FocusTraversalGroup, D-pad up/down support and
/// D-pad right traverse via [Shortcuts] / [Actions].
///
/// The traversal-right intent allows a Settings shell to focus the body
/// pane (i.e. wraps `arrowRight` to a `VoidCallback`) without coupling
/// the sidebar to the body widget's [FocusNode].
class SidebarNav extends StatefulWidget {
  const SidebarNav({super.key, required this.selectedIndex, required this.onSelected, required this.onTraverseRight});

  /// Currently active section index (0..5).
  final int selectedIndex;

  /// Tap / select callback. Receives the new index.
  final ValueChanged<int> onSelected;

  /// Called when the focused item receives a `arrowRight` press.
  final VoidCallback onTraverseRight;

  @override
  State<SidebarNav> createState() => _SidebarNavState();
}

class _SidebarNavState extends State<SidebarNav> {
  static const List<String> _sectionLabels = ['Тема', 'Плеер', 'Сеть', 'Производительность', 'О приложении', 'Сброс'];

  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = List.generate(_sectionLabels.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.activePalette;

    return Container(
      width: 300.w,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: palette.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 32.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Brand(size: 28, showWordmark: true),
              ),
            ),
          ),
          SizedBox(height: 32.h),
          Expanded(
            child: FocusTraversalGroup(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  for (int i = 0; i < _sectionLabels.length; i++)
                    Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: _SidebarItem(
                        label: _sectionLabels[i],
                        index: i,
                        isSelected: i == widget.selectedIndex,
                        focusNode: _nodes[i],
                        onTap: () => widget.onSelected(i),
                        onTraverseRight: widget.onTraverseRight,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Intent fired when D-pad right pressed on a focused sidebar item.
class _TraverseRightIntent extends Intent {
  const _TraverseRightIntent();
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.label,
    required this.index,
    required this.isSelected,
    required this.focusNode,
    required this.onTap,
    required this.onTraverseRight,
  });

  final String label;
  final int index;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback onTraverseRight;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  @override
  Widget build(BuildContext context) {
    final palette = AppColors.activePalette;
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final baseStyle = styles?.bodyDefault ?? theme.textTheme.bodyLarge;
    final activeStyle = baseStyle?.copyWith(color: palette.text);
    final inactiveStyle = baseStyle?.copyWith(color: palette.textDim);

    final body = Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        borderRadius: AppRadius.brSm,
        color: widget.isSelected ? palette.accentSoft : Colors.transparent,
      ),
      child: Row(
        children: [
          if (widget.isSelected) Container(width: 3.w, height: 20.h, color: palette.accent) else SizedBox(width: 3.w),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              widget.label,
              style: widget.isSelected ? activeStyle : inactiveStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _TraverseRightIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _TraverseRightIntent: CallbackAction<_TraverseRightIntent>(
            onInvoke: (_) {
              widget.onTraverseRight();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: widget.focusNode,
          onFocusChange: (_) => setState(() {}),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: SafeFocusRing(isFocused: widget.focusNode.hasFocus, child: body),
          ),
        ),
      ),
    );
  }
}
