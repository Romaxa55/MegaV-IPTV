// Layout-токены и pure-функции для горизонтальной сетки главного экрана.
//
// Конструктивно файл не зависит от runtime-контекста: нет BuildContext,
// нет Riverpod, нет flutter_screenutil. Размерные значения хранятся как
// raw double (`gapDp`, `horizontalPaddingDp`) — потребители сами умножают на
// `.w`/`.h` при необходимости. Это держит файл pure и тестируемым.
//
// См. spec: .kiro/specs/home-grid-optimization/design.md, секция
// «UI Tokens / `_grid_tokens.dart`».

import 'package:flutter/animation.dart';

/// Возвращает количество колонок горизонтальной сетки в зависимости от
/// логической ширины экрана.
///
/// Контракт (см. requirements 1.1, 1.2, 1.3):
///   * `screenW < 1280`         → 3
///   * `1280 ≤ screenW < 2560`  → 4
///   * `screenW ≥ 2560`         → 5
///
/// Precondition: `screenW > 0`.
int pickColumns(double screenW) {
  if (screenW < 1280) return 3;
  if (screenW < 2560) return 4;
  return 5;
}

/// Pure-константы layout/анимаций для горизонтальной сетки главного экрана.
///
/// Все длительности — `const Duration`, кривые — стандартные `Curves`,
/// размеры — raw `double` в логических пикселях (`*Dp` суффикс) или безразмерные
/// (`focusedScale`, `focusBorderWidth`).
class GridTokens {
  const GridTokens._();

  // --- Длительности анимаций (Requirement 7) ---

  /// Длительность scale/border анимации фокуса плитки. Req 7.1, 7.2.
  static const Duration focusAnimation = Duration(milliseconds: 150);

  /// Длительность анимации выравнивания активной плитки к левому краю. Req 7.3.
  static const Duration scrollAnimation = Duration(milliseconds: 250);

  /// Длительность fade-in/out полного overlay'а. Req 7.4.
  static const Duration overlayFade = Duration(milliseconds: 150);

  /// Debounce стабильного фокуса перед dispatch тяжёлых эффектов. Req 4.1, 4.2.
  static const Duration focusStableDebounce = Duration(milliseconds: 400);

  // --- Кривые (Requirement 7.5, 7.6) ---

  /// Кривая для scale-анимации фокуса.
  static const Curve focusCurve = Curves.easeOutCubic;

  /// Deceleration-style кривая для скролла к левому краю.
  static const Curve scrollCurve = Curves.fastOutSlowIn;

  /// Smooth ease-out кривая для overlay fade.
  static const Curve overlayCurve = Curves.easeOut;

  // --- Безразмерные коэффициенты (Requirement 3) ---

  /// Целевой scale активной плитки. Req 3.1.
  static const double focusedScale = 1.08;

  /// Толщина рамки фокуса. Req 3.3.
  static const double focusBorderWidth = 3.0;

  // --- Размеры в логических пикселях (Requirement 1) ---
  //
  // Хранятся как raw `double`. Потребители обязаны применить `.w`/`.h`
  // от flutter_screenutil на use-site, чтобы файл оставался без runtime-зависимостей.

  /// Зазор между плитками в ряду. Используется как `GridTokens.gapDp.w`.
  static const double gapDp = 16;

  /// Горизонтальный отступ ряда от краёв экрана. Req 1.6.
  /// Используется как `GridTokens.horizontalPaddingDp.w`.
  static const double horizontalPaddingDp = 48;

  /// Вертикальный зазор между рядами. Используется как `GridTokens.rowVerticalGapDp.h`.
  static const double rowVerticalGapDp = 20;
}
