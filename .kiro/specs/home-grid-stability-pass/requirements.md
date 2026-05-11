# Requirements Document

## Introduction

После завершения двух предыдущих волн оптимизации (`home-grid-optimization`,
`home-grid-visual-polish`) горизонтальная сетка плиток на главном экране
`CinematicHomeScreen` остаётся **визуально нестабильной**: фокусированная карточка
ощутимо «толкает» соседей, высота плитки субъективно ниже эталона
Netflix/Apple TV, а Netflix-style pin-at-slot-1 реализован эмпирически и не
оформлен как verifiable invariant. User feedback (дословно): «карточки
обрезаются — должны быть по высоте выше; сделай как на Netflix, где сетка
стоит на месте, а обложки внутри неё двигаются».

Цель спецификации — **финальная стабилизация визуала сетки** через минимальные
правки в существующем `CinemaRow` + `CinemaCard`: новые токены геометрии и
анимации (поверх существующих, не модифицируя `home-grid-optimization`),
fixed-height metadata wrapper для подписей, явный документированный
**Pinned-Slot Invariant** с проверяющим автотестом. Спецификация поверх
закрытых волн: ни `home-grid-optimization`, ни `home-grid-visual-polish` не
открываются повторно — все правки идут как новые константы и новый контракт.

## Boundary Context

- **In scope**:
  - Уменьшение визуально ощутимого scale активной плитки до неощутимого
    уровня; компенсация подсветки фокуса другими средствами без изменения
    геометрии соседей.
  - Увеличение высоты плитки до postcard/Netflix-style пропорции и применение
    новой высоты к `CinemaRow` на обоих главных экранах (`CinematicHomeScreen`
    и legacy `HomeScreen`).
  - Фиксированная высота нижней метаданной зоны карточки (название канала,
    название программы и т. п.), чтобы переменная длина текста не сдвигала
    визуальный baseline.
  - Формализация Pinned-Slot Invariant и его автоматическая проверка тестом.
  - Документация контракта pinned-slot в коде и в spec-артефактах.
- **Out of scope**:
  - Алгоритм `pickColumns` (3/4/5 колонок) — закрыт `home-grid-optimization`.
  - Реализация fade-edge через DecoratedBox — закрыта `home-grid-visual-polish`.
  - Любая работа с hero (раскрытие/коллапс, transitions) — отдельный спек
    `hero-collapse-tile-morph`.
  - Изменения mobile-варианта (`mobile-adaptive-layout` закрыт).
  - Добавление новых пакетов в `pubspec.yaml`.
  - Изменение реализации `SafeFocusRing` (toolkit `perf-safe-widgets`).
- **Adjacent expectations**:
  - Закрытые спеки `home-grid-optimization` и `home-grid-visual-polish`
    остаются «as-is»: `pickColumns`, fade-edge, focus debounce, `late final`
    кэш псевдо-данных, pinned-slot-`scrollFocusedTileToLeadingEdge` —
    все эти контракты должны сохраниться без регрессий.
  - Steering `flutter-tv-perf.md` запрещает на TV-таргете `BackdropFilter`,
    `ImageFilter.blur`, `ShaderMask`, `BoxShadow.blurRadius > 12`,
    `AnimatedContainer.width` для focus-эффектов. Все требования этой
    спецификации совместимы с запретами.
  - Все существующие тесты (на момент старта — 30+) должны продолжать
    проходить; новые тесты добавляются, существующие не модифицируются
    кроме случаев, когда новая геометрия плитки делает их числовые
    ожидания заведомо несоответствующими — тогда правка фиксирует новое
    наблюдаемое поведение, а не подгоняет тест.

## Requirements

### Requirement 1: Pinned-Slot Invariant как формальный контракт

**Objective:** As a TV user, I want the focused tile to stay anchored in
the same on-screen position while I traverse a row with the D-pad, so that
the row feels like a static grid through which posters slide rather than
a list that jumps under my focus.

#### Acceptance Criteria

1. While focus stays inside the same row and moves between non-edge tiles via D-pad, the CinemaRow shall keep the focused tile's screen-space top-left position stable within a tolerance of 1.0 logical pixel between successive focus changes.
2. When focus first enters a row from a tile whose index allows pinning (index больше или равен фиксированному pinned slot, index меньше длины ряда минус число хвостовых клеток), the CinemaRow shall scroll so that the focused tile occupies the configured pinned slot position.
3. When focus moves to a tile near the leading edge of the row (index меньше pinned slot), the CinemaRow shall keep the scroll offset at 0 instead of pulling the tile to the pinned slot.
4. When focus moves to a tile near the trailing edge of the row (where pinning would exceed maxScrollExtent), the CinemaRow shall clamp the scroll offset to maxScrollExtent without overshoot.
5. The CinemaRow shall expose the pinned-slot index as a named constant referenced from a stable token source, so that the invariant is verifiable by tests without scraping source code.
6. The CinemaRow shall document the Pinned-Slot Invariant in dartdoc comments visible to consumers of the widget, including the tolerance and edge-case clauses listed above.

### Requirement 2: Визуальная нейтральность фокуса

**Objective:** As a TV user, I want the focus indicator to be obvious without
visibly pushing the neighbours of the focused tile, so that the row stops
"breathing" every time my D-pad moves and feels physically still.

#### Acceptance Criteria

1. The CinemaCard shall apply a focused scale value that is at most 1.01 (т. е. визуальное увеличение не превышает 1%) so that neighbour tile positions are not perceptibly displaced.
2. While a tile is focused, the CinemaCard shall mark it visually through a combination of border, focus ring and optional neighbour de-emphasis (opacity ниже 1.0 у нефокусных плиток), and shall not rely on scale alone to indicate focus.
3. The CinemaCard shall keep the focused scale value as a named token in the same token source as other grid tokens, so that the «scale neutrality» contract is enforceable across consumers.
4. While the focused scale is in effect, the CinemaRow shall not change the visible geometry (width/height/translation) of unfocused tiles relative to their resting state.
5. If a neighbour de-emphasis effect is applied to unfocused tiles, the CinemaCard shall use only GPU-cheap properties (например, Opacity) and shall not introduce any rule prohibited by `flutter-tv-perf.md` (BackdropFilter, ImageFilter.blur, ShaderMask, BoxShadow.blurRadius greater than 12, AnimatedContainer.width for focus).

### Requirement 3: Геометрия плитки и фиксированная зона метаданных

**Objective:** As a TV user, I want each tile to feel like a proper vertical
poster (in the style of Netflix / Apple TV) and to keep the text below the
poster on a stable baseline regardless of programme name length, so that
neither the tile aspect nor the row baseline visibly shifts as I scroll.

#### Acceptance Criteria

1. The CinemaCard shall render at an aspect ratio cardH/cardW in the range 1.6 to 1.7 (inclusive) on the reference TV resolution used by `pickColumns`, so that posters look vertical and visually dominant.
2. The CinemaRow shall propagate the new tile height through to existing height-dependent slots (row height, loading placeholder height, hero-below offset) without breaking any layout assumption documented in `home-grid-optimization` or `home-grid-visual-polish`.
3. The CinemaCard shall reserve a fixed-height region below the poster for textual metadata so that the vertical position of the bottom edge of the tile is independent of programme/channel name length.
4. While the focused state changes between true и false, the CinemaCard shall keep the fixed-height metadata region at its fixed height (no reflow caused by adding or removing rows of text).
5. When the channel name or programme title exceeds the available width of the fixed-height metadata region, the CinemaCard shall render the overflowing text with ellipsis and shall not extend beyond the configured number of lines.
6. The fixed-height region's value shall be defined as a named token in the same token source as other grid tokens (consistent with Requirement 1.5 and Requirement 2.3).

### Requirement 4: Совместимость с обоими главными экранами и закрытыми спеками

**Objective:** As an operator of MegaV IPTV, I want both home screens
(legacy and cinematic) to keep working after this change and all previously
green tests to stay green, so that the stability pass does not regress any
behaviour locked in by earlier waves.

#### Acceptance Criteria

1. The CinematicHomeScreen shall continue to render its hero, rails, boot overlay, preview-player and remote-hint footer with the new tile geometry, without any new layout overflow, focus trap, or scroll-controller detachment.
2. The legacy HomeScreen shall continue to render its rails using the same `CinemaRow` widget and the new tile geometry, without losing existing focus-debounce, preview-player wiring, or pagination behaviour.
3. While running the existing automated test suite (unit, widget, golden) on the spec branch, the project shall keep all previously passing tests passing, except for tests whose only failure is a numeric mismatch caused directly by the new tile height or fixed-height metadata region (such tests shall be updated to match the new observable values without weakening the original intent).
4. The CinemaRow shall preserve every contract closed by `home-grid-optimization` (pickColumns 3/4/5 thresholds, focusStableDebounce of 400 ms, late-final pseudo-data cache, AnimatedScale-based focus animation, removal of blurRadius greater than 12) and by `home-grid-visual-polish` (right-edge fade via DecoratedBox, Visibility-wrapped full overlay, fast-scroll animation collapse), with no modification to those code paths beyond what is strictly required for the new tokens.
5. While displaying a row whose data is still loading, the CinemaRow loading placeholder shall match the new tile height и new column count from `pickColumns`, so that loaded data does not produce a layout jump (preserves `home-grid-optimization` Req 11.1, 11.2, 11.5 semantics under new geometry).

### Requirement 5: Verifiable invariant test

**Objective:** As a future maintainer, I want a test that fails the moment
the Pinned-Slot Invariant is broken, so that subsequent visual changes to
the grid cannot silently regress «grid stable, content slides».

#### Acceptance Criteria

1. The project shall include an automated widget test that mounts a `CinemaRow` instance with a deterministic dataset of at least N tiles, where N is large enough that pinning is reachable on the reference screen width (т. е. N не меньше pinned slot index плюс число колонок плюс 2).
2. When the test programmatically moves focus across at least 5 successive tiles within the middle of the row, the test shall sample the screen-space position of the focused tile's render box after each focus change and assert that the position remains stable within 1.0 logical pixel tolerance (consistent with Requirement 1.1).
3. The test shall also verify the leading-edge clamp behaviour by moving focus to a tile with index less than the pinned slot and asserting that the row's scroll offset stays at 0 (consistent with Requirement 1.3).
4. The test shall also verify the trailing-edge clamp behaviour by moving focus to the last tile and asserting that the row's scroll offset equals maxScrollExtent (consistent with Requirement 1.4).
5. If the test detects deviation outside tolerance, the test shall produce a failure message that names the offending focus index pair and the measured deviation, so that the regression is diagnosable from the test output without re-running with custom instrumentation.

### Requirement 6: Производительность и TV-target соответствие

**Objective:** As a TV user on a low-end Realtek box, I want the stability
pass to not introduce any GPU/CPU regression on the reference device, so
that the visual win is not paid for in frame drops.

#### Acceptance Criteria

1. The CinemaCard and CinemaRow shall not introduce any of the APIs prohibited by `flutter-tv-perf.md` for the TV target (BackdropFilter, ImageFilter.blur, ShaderMask, BoxShadow.blurRadius greater than 12, AnimatedContainer.width as a focus animation, heavy SVG above 64 dp).
2. While the user scrolls a row with the new tile geometry on the reference device profile, the CinemaRow shall keep the average GPU rasterizer frame time at or below 16.7 ms (60 fps target), matching the budget enforced by previous waves.
3. While a row is idle (no scroll, no focus change), the CinemaCard shall keep the number of BUILD events caused by its own subtree at or below the level established after `home-grid-visual-polish` (no new continuous stream subscriptions or per-frame rebuilds introduced by neighbour de-emphasis).
4. The CinemaCard shall keep heavy overlays (rating, age, genre, progress, programme info) behind the existing Visibility/AnimatedOpacity gate so that nefocused tiles still skip the heavy subtree, preserving the BUILD-event reduction shipped by `home-grid-visual-polish`.
