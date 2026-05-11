# Brief: home-unified-grid-scroll

## Problem

После Polish Cycle 2026 главный экран собран из двух layout-блоков: hero
(`Positioned top:0, height:620`) и rails-list (`Positioned top:620,
ListView.builder`). Hero и rails — отдельные scroll-вьюеры с
самостоятельными ScrollController. Hero пытается «жить как плитка»
через `HeroTileMorph` (300ms morph), но это компромисс — пользователь
объяснил голосом + скрином, что ожидал **другую** модель.

Реальная пользовательская модель (цитата по сообщению + screenshot
2026-05-11 22:13):

> «если нет hero, то должна быть сетка 3 на 4, когда мы вниз листаем
> hero не фиксировано, а уходит наверх — как бы понял, часть сетки.
> Наш фокус всегда на квадрате 2×1, т.е. вторая строчка, первый постер,
> и когда мы влево-вправо — то просто подставляем ленту. И можно во
> все стороны, как бы понял. А если поднялся в самый верх — hero
> занимает ровно 1×4.»

То есть hero — это не отдельная секция, а **row-0** того же грида,
шириной во всю экранную ширину (1×4 для `pickColumns=4` на 1920 dp).
Фокус намертво приколочен к slot `(row=2, col=1)`. Стрелки двигают
grid под фокусом, фокус — никогда. ↑ из rails возвращает hero на
экран как row-0; ↓ из hero уплывает hero наверх и ставит первую
плитку первого rail в focused slot.

## Current State

Файлы которые меняются (по результатам аудита):
- `lib/features/home/cinematic/cinematic_home_screen.dart:497–533` —
  Stack с `Positioned(top:0, hero) + Positioned(top:expandedH,
  ListView rails)`. Hero и rails не делят scroll-controller.
- `lib/features/home/cinematic/hero_tile_morph.dart` — 363 строки
  geometry+opacity morph, существует только для hero collapse. В новой
  модели **не нужен**: hero не сжимается в плитку, а уезжает по
  вертикали как обычная row.
- `lib/features/home/widgets/cinema_row.dart` — horizontal
  pinned-slot уже работает (`GridTokens.pinnedSlotIdx = 1`). Контракт
  `Pinned-Slot Invariant` доказан тестами
  `cinema_row_pinned_slot_test.dart`. **Расширяется** на вертикальную
  ось (новый `RowPinnedScroller` или integrated в существующий
  `ListView.builder`).
- `lib/features/home/widgets/_grid_tokens.dart` — `pickColumns` и
  `cardHeightDp` остаются как есть.

Что **уже корректно сейчас** (не надо переделывать):
- Horizontal pinned slot, focus traversal (`FocusTraversalGroup` +
  `WidgetOrderTraversalPolicy` после фикса `d626edc`).
- 4-колоночный layout, scale, opacity damping, metadata reserved
  height.
- Rails data flow (`featuredNowPlayingProvider` +
  `categoryNotifierProvider`).

## Desired Outcome

1. Главный экран = единый вертикально-скроллящийся grid.
2. Row-0 = hero, height ≈ 600 dp, full-bleed (1×4 на 1920).
3. Row-1..N = обычные cinema rows, height = `GridTokens.cardHeightDp`.
4. Фокус всегда на одной и той же screen-space позиции — slot `(row=2, col=1)`.
5. ↓ из focused slot → весь grid скроллится наверх так что следующая
   row занимает focused slot. Hero уплывает наверх естественно.
6. ↑ из focused slot → grid скроллится вниз, предыдущая row занимает
   focused slot. Когда focused slot = row-1 и ↑ — row-0 (hero)
   становится focused, hero полностью видна.
7. Внутри row ←/→ работает как и сейчас (Pinned-Slot Invariant горизонтально).
8. На самом верху и самом низу — естественные leading/trailing clamps
   как в существующем `CinemaRow`.
9. Анимации — `Curves.easeInOutCubic`, ≤300 ms.
10. Hero **не сворачивается** в плитку. `HeroTileMorph` удаляется.

## Approach

**Vertical Pinned-Slot Invariant**: применить тот же контракт что в
`home-grid-stability-pass` (`pinnedSlotIdx=1`), но на вертикальной оси.
Использовать `ScrollController` родительского `ListView` (вертикальный),
рассчитывать `targetOffset = (focusedRowIdx -
GridTokens.verticalPinnedSlotIdx) * rowStride` и анимировать туда.

Hero становится первым child этого ListView (row 0), его focus-target
— анонимный Focus-виджет внутри (наследует логику из
`hero_tile_morph._buildCollapsedLayout` re-entry target), плюс
обычная кнопка «Смотреть» доступна когда hero в focused slot. При
прокрутке наверх — hero видна, при прокрутке вниз — обычная
ScrollPosition уносит её за пределы viewport.

**Hero внутри grid**: hero не Positioned, а такой же child ListView
как любой rail. Это автоматически решает scroll coupling. Hero width
= viewport width, height = 600 dp (тот же что был expanded). Внутри
— старый `CinematicHeroContent` (название, кнопки), без `HeroTileMorph`.

**HeroTileMorph удаляется**: подход morph → tile неправильный. Hero
не tile, hero — row.

## Scope

### In
- Новый виджет `UnifiedHomeGridScroller` (или интегрированный в
  существующий ListView) с vertical pinned slot.
- Hero как row-0 — single child внутри того же ListView (full-bleed
  width, height ≈ 600 dp).
- Vertical pinned slot constant в `GridTokens` (предложение:
  `verticalPinnedSlotIdx = 1` — вторая видимая row фиксирована).
- Удаление `hero_tile_morph.dart` + связанных тестов
  (`hero_tile_morph_test.dart`).
- Упрощение `cinematic_home_screen.dart` — больше нет двойной Stack-структуры.
- Обновление `home-grid-stability-pass` boundary: pinned-slot invariant
  теперь и горизонтально, и вертикально.
- Vertical pinned-slot widget test (вертикальный аналог
  `cinema_row_pinned_slot_test.dart`).

### Out
- Legacy `/home` (HomeScreen) — не трогаем.
- Player, EPG, search, mobile, settings — не трогаем.
- Backend API — без изменений.
- 6 palettes / themes — не трогаем.
- Carousel hero rotation (если совместимо с новой структурой —
  оставляем как есть; если нет — выключаем feature-flag-ом).

## Boundary Candidates
- `UnifiedHomeGridScroller` (или интегрированный в `CinematicHomeScreen`
  через extension method) — вертикальный pinned-scroll controller.
- `HeroAsRow` — обёртка над `CinematicHeroContent` для использования
  внутри ListView.
- `GridTokens.verticalPinnedSlotIdx` + `GridTokens.rowStrideDp`
  geometry helpers.
- Виджет-тест vertical pinned slot.

## Out of Boundary
- Изменение `home-grid-optimization` (pickColumns 3/4/5) — read-only.
- Изменение `home-grid-visual-polish` (fade edges) — read-only.
- Удаление `cinema_row.dart` horizontal pinned slot — он работает
  как был, переиспользуется.
- Любые правки в player, EPG, mobile.

## Upstream / Downstream

**Upstream**:
- `design-system-foundation` — theme (палитры) read-only.
- `perf-safe-widgets` — `SafeBackdrop`, `SafePill` для hero.
- `design-system-atoms` — Chip, MMLogo, MvButton.
- `home-grid-optimization` — `pickColumns`, `GridTokens` core constants.
- `home-grid-visual-polish` — fade edge, focused scale.
- `home-grid-stability-pass` — horizontal pinned slot, `cardHeightDp`,
  `focusedScale = 1.01`.
- `home-cinematic-redesign` — `CinematicHeroContent`, `CinematicRail`.

**Downstream**:
- `hero-collapse-tile-morph` — **сделан obsolete**. Spec остаётся в
  истории, файл `hero_tile_morph.dart` удаляется.
- Будущие специи на главный экран (если будут) — наследуют
  unified-grid модель.

## Existing Spec Touchpoints
- **Extends** (заимствует контракт): `home-grid-stability-pass`
  (vertical вариант pinned-slot invariant).
- **Adjacent**: `home-cinematic-redesign` (hero content вшит в row-0,
  не отдельная Section).
- **Replaces / Obsoletes**: `hero-collapse-tile-morph` (UX-модель
  заменена).

## Constraints

- TV-perf: `flutter-tv-perf.md` правила соблюдаются (no BackdropFilter
  на frame, no ShaderMask, no AnimatedContainer.width, no
  ImageFilter.blur, BoxShadow.blurRadius ≤ 12). Vertical scroll
  анимирует scrollOffset, не layout-properties.
- Realtek `rtd2851a` smoke остаётся блокером для user-side.
- 600-line file limit pre-commit hook — новый файл `UnifiedHomeGridScroller`
  не больше 600 строк (или вынести в несколько файлов).
- Все существующие 109/109 home-тестов должны остаться зелёными;
  hero_tile_morph_test.dart удаляется вместе с виджетом.
- Тесты: Vertical Pinned-Slot Invariant обязателен (по аналогии с
  `cinema_row_pinned_slot_test.dart`).
- Russian-first content stays.
