import 'package:flutter/material.dart' hide Chip;
import 'package:flutter/services.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';

/// 6-item sidebar with FocusTraversalGroup, D-pad up/down support and
/// D-pad right traverse.
///
/// JSX reference (`settings-v2.jsx` Sidebar):
/// ```jsx
/// SETTINGS_NAV items have { label, sub } — sub is a mono 10sp subtitle.
/// Active item: borderLeft "2px solid var(--accent)", bg accentSoft,
///   label fontSize 15, fontWeight 600.
/// Inactive: transparent, label fontSize 15, fontWeight 500, textDim.
/// sub: mono 10sp, ls 0.14em, uppercase, textMute, marginTop 4.
/// padding "16px 32px" per item.
/// ```
class SidebarNav extends StatefulWidget {
  const SidebarNav({super.key, required this.selectedIndex, required this.onSelected, required this.onTraverseRight});

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onTraverseRight;

  @override
  State<SidebarNav> createState() => _SidebarNavState();
}

class _SidebarNavState extends State<SidebarNav> {
  // JSX SETTINGS_NAV — label + sub.
  static const List<(String, String)> _sections = [
    ('Тема', 'палитра · шрифты'),
    ('Плеер', 'плеер · кодеки · переходы'),
    ('Сеть', 'm3u · источники · обновления'),
    ('Производительность', 'GPU · буфер · энергия'),
    ('О приложении', 'сборка · версии · правовое'),
    ('Сброс', 'восстановление настроек'),
  ];

  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = List.generate(_sections.length, (_) => FocusNode());
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
      // JSX: width 300.
      width: 300,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: palette.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // JSX: padding "32px 0 16px" for label row.
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
            child: _SectionLabel(text: 'Разделы', count: _sections.length),
          ),
          Expanded(
            child: FocusTraversalGroup(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  for (int i = 0; i < _sections.length; i++)
                    _SidebarItem(
                      label: _sections[i].$1,
                      sub: _sections[i].$2,
                      index: i,
                      isSelected: i == widget.selectedIndex,
                      focusNode: _nodes[i],
                      onTap: () => widget.onSelected(i),
                      onTraverseRight: widget.onTraverseRight,
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

/// Mono section label: uppercase, 10sp, textMute.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.count});
  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final palette = AppColors.activePalette;
    final style = (styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 10,
      letterSpacing: 0.22 * 10,
      color: palette.textMute,
    );
    return Row(
      children: [
        Text(text.toUpperCase(), style: style),
        if (count != null) ...[
          const SizedBox(width: 12),
          Text(
            count!.toString().padLeft(2, '0'),
            style: style.copyWith(color: palette.textDim, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

class _TraverseRightIntent extends Intent {
  const _TraverseRightIntent();
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.label,
    required this.sub,
    required this.index,
    required this.isSelected,
    required this.focusNode,
    required this.onTap,
    required this.onTraverseRight,
  });

  final String label;
  final String sub;
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

    // JSX: label fontSize 15, fontWeight 600 (active) / 500 (inactive).
    final labelStyle = (styles?.bodyDefault ?? theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
      fontSize: 15,
      fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
      color: widget.isSelected ? palette.text : palette.textDim,
    );

    // JSX: sub mono 10sp, ls=0.14em, uppercase, textMute, marginTop 4.
    final subStyle = (styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 10,
      letterSpacing: 0.14 * 10,
      color: palette.textMute,
    );

    final body = Container(
      // JSX: padding "16px 32px".
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        // JSX: active → borderLeft 2px accent + bg accentSoft.
        border: Border(left: BorderSide(color: widget.isSelected ? palette.accent : Colors.transparent, width: 2)),
        color: widget.isSelected ? palette.accentSoft : Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(widget.sub.toUpperCase(), style: subStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
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
