// onboarding-remote-cheatsheet spec (Wave 6) — first-run overlay tour.
//
// Single screen с D-pad cheatsheet: четыре блока (←/→, ↑/↓, OK, Back)
// + крупная focusable кнопка «Понятно». TV-safe: только Material/Focus
// без BackdropFilter/ShaderMask.

import 'package:flutter/material.dart';

/// Single-shot overlay показывается при первом запуске Cinematic-экрана.
/// Dismiss → owner вызывает `onDismiss()` (родитель пишет в
/// [OnboardingNotifier.markShown] и убирает overlay из дерева).
class OnboardingOverlay extends StatelessWidget {
  const OnboardingOverlay({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Сплошной dim background — TV-safe, без BackdropFilter.
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Управление с пульта',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Несколько простых правил, и вы готовы',
                  style: TextStyle(fontSize: 18, color: Color(0xCCFFFFFF)),
                ),
                const SizedBox(height: 40),
                const _ControlsGrid(),
                const SizedBox(height: 48),
                _GotItButton(onPressed: onDismiss),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlsGrid extends StatelessWidget {
  const _ControlsGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 32,
      runSpacing: 24,
      alignment: WrapAlignment.center,
      children: const [
        _ControlTile(symbol: '◀ ▶', label: 'Влево / Вправо', hint: 'Переключение каналов в ряду'),
        _ControlTile(symbol: '▲ ▼', label: 'Вверх / Вниз', hint: 'Переход между рядами'),
        _ControlTile(symbol: 'OK', label: 'OK', hint: 'Смотреть выбранный канал'),
        _ControlTile(symbol: '◀', label: 'Back', hint: 'Назад / выход'),
      ],
    );
  }
}

class _ControlTile extends StatelessWidget {
  const _ControlTile({required this.symbol, required this.label, required this.hint});
  final String symbol;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            symbol,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8B5CF6),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(hint, style: const TextStyle(fontSize: 13, color: Color(0xAAFFFFFF), height: 1.3)),
        ],
      ),
    );
  }
}

class _GotItButton extends StatefulWidget {
  const _GotItButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_GotItButton> createState() => _GotItButtonState();
}

class _GotItButtonState extends State<_GotItButton> {
  final FocusNode _node = FocusNode(debugLabel: 'onboardingDismissButton');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _node.requestFocus();
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      autofocus: true,
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          // TV-perf: фиксированный padding + DecoratedBox + 150ms
          // AnimatedScale на focus indication. Никаких изменений
          // padding/width/border-width в анимации — только цвет
          // (через AnimatedContainer.decoration без layout-properties).
          return GestureDetector(
            onTap: widget.onPressed,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: focused ? 1.05 : 1.0),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: focused ? const Color(0xFF8B5CF6) : Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                  child: Text(
                    'Понятно',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: focused ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
