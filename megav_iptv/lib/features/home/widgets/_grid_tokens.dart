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
  ///
  /// Netflix-style: минимальный scale чтобы сетка не "плясала". Основной
  /// focus-индикатор — яркая рамка + лёгкая тень (blurRadius=12).
  ///
  /// Снижен в stability pass (`home-grid-stability-pass` spec): с 1.02 до 1.01.
  /// На пиксельной сетке 1920×1080 разница между 1.0 и 1.01 визуально
  /// неотличима, но всё ещё триггерит `AnimatedScale` rebuild для focus
  /// indication. Это убирает остаточный «push» соседних плиток при focus
  /// traversal, который наблюдался при 1.02.
  static const double focusedScale = 1.01;

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

  /// Доля ширины ряда, занимаемая правым fade-edge gradient. 0.05 = 5%
  /// (Netflix/Leanback `lb_browse_rows_fading_edge` эталон).
  static const double fadeEdgeFraction = 0.05;

  // --- v2 (stability pass — home-grid-stability-pass spec) ---
  //
  // Эти константы добавлены без удаления существующих API. Все потребители
  // постепенно переходят с magic-number'ов на эти токены. Семантика
  // Pinned-Slot Invariant'а — см. dartdoc у `CinemaRow`.

  /// Netflix-style индекс «зафиксированного» слота: куда clamping'ом всегда
  /// приводится фокусная плитка в активном ряду.
  ///
  /// Контракт (Req 1.5): screen-space позиция плитки в слоте `pinnedSlotIdx`
  /// стабильна по horizontal axis между нажатиями D-pad ↔ (с tolerance ±1.0 dp),
  /// при условиях leading-edge clamp (для tiles 0..pinnedSlotIdx) и
  /// trailing-edge clamp (для последних tiles). Используется
  /// `_scrollFocusedTileToLeadingEdge` в `CinemaRow`.
  ///
  /// Значение 1 (второй слот, 0-индексированный) — соответствует Apple TV /
  /// Netflix визуальной идиоме: первая плитка имеет «дыхание» слева, фокус
  /// останавливается на втором слоте.
  static const int pinnedSlotIdx = 1;

  /// Целевая высота плитки в logical pixels (используется как
  /// `GridTokens.cardHeightDp.h` через flutter_screenutil).
  ///
  /// Контракт (Req 3.1): на reference TV-resolution 1920×1080 и при
  /// `pickColumns(1920) == 4`, `cardW ≈ 444 dp` → `cardH/cardW ≈ 1.62`.
  /// Это попадает в целевой диапазон 1.6–1.7 (вертикальный постер-формат
  /// типа Apple TV / Netflix), который stability pass требует от плитки.
  ///
  /// Используется в `CinemaRow.build` как default `availableHeight`.
  static const double cardHeightDp = 720;

  /// Зарезервированная высота нижней metadata-зоны плитки (название
  /// канала + жанр), используется как `GridTokens.metadataReservedHeightDp.h`.
  ///
  /// Контракт (Req 3.3, 3.4): высота metadata-зоны фиксирована независимо
  /// от длины текста названия. Длинные названия эллипсятся (`maxLines: 2,
  /// overflow: TextOverflow.ellipsis`). Это убирает визуальный сдвиг
  /// baseline между фокусной и нефокусной плиткой, который наблюдался,
  /// когда `Text` мог расти/сжиматься.
  ///
  /// 46 dp = ~2 строки 16sp текста + 14 dp padding снизу.
  static const double metadataReservedHeightDp = 46;

  /// Opacity, применяемая к нефокусным плиткам **активного** ряда (того,
  /// где `_focusedIndex >= 0`). Соседние ряды (где `_focusedIndex == -1`)
  /// остаются полностью видимыми (opacity 1.0).
  ///
  /// Контракт (Req 2.2, 2.5, 6.1): TV-perf safe — `Opacity` в Flutter
  /// Impeller дёшев (один blend pass). Эффект — лёгкое затухание соседей
  /// активной плитки, усиливающее focus indication без геометрических
  /// сдвигов. Значение 0.92 — едва заметное, но измеримое.
  static const double unfocusedNeighbourOpacity = 0.92;
}
