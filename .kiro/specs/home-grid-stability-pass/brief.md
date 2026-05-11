# Brief: home-grid-stability-pass

## Problem

После предыдущих волн `home-grid-optimization` и `home-grid-visual-polish` визуальная сетка
плиток на `CinematicHomeScreen` остаётся **визуально нестабильной**:

- Фокус-карточка ощутимо «толкает» соседей (даже при `focusedScale 1.02` — minimal scale
  всё ещё перерасчитывает положение соседей).
- Высота плитки субъективно «низковата» — обложка выглядит сжатой, теряется визуальная
  масса по сравнению с эталонными Netflix/Apple TV рядами.
- Pinned slot (Netflix-style) реализован в `cinema_row.dart`, но контракт «грид стоит,
  обложки слайдятся через зафиксированный слот» **не оформлен явно** — это эмерджентное
  поведение, не verifiable invariant.

User feedback дословно: «карточки видишь как то не красиво оберазются они должны быть по
высоте немного выше как-то т.е. выдели как бы сетку как на нетфликсе типа сетка стоит
на месте обложки карточки меняются протсо двигаются».

## Current State

- `lib/features/home/widgets/_grid_tokens.dart` — `focusedScale: 1.02`, carry `cardW/cardH`
  ratio который даёт нынешнюю «низкую» плитку.
- `lib/features/home/widgets/cinema_row.dart::_scrollFocusedTileToLeadingEdge` — pin at
  slot 1 (`const pinnedSlotIdx = 1`). Логика работает, но контракт не задокументирован.
- Фокус-кольцо `SafeFocusRing` добавляет внешнюю обводку — она физически расширяет
  визуальную bounding box карточки на ~6-8px, что усиливает ощущение «толкания» соседей.
- Соседние плитки **не сдвигаются** по геометрии — но рендеринг текста (название/жанр)
  под обложкой меняется по длине и создаёт визуальный сдвиг.

## Desired Outcome

- `focusedScale` сводится к **1.00–1.01** (визуально неощутимо), а выделение
  фокуса делается **исключительно** за счёт SafeFocusRing + лёгкого изменения непрозрачности
  соседей.
- Высота плитки увеличена так, чтобы соотношение `cardH/cardW ≈ 1.6–1.7` (вертикальный
  постер-формат, как у Apple TV / Netflix).
- Слот пиннинга оформлен как явный **визуальный контракт**: при стрелке вправо/влево
  карточки **скользят через** зафиксированный слот, focused tile визуально не двигается
  по экрану — двигаются обложки/метаданные внутри слота.
- Текстовые подписи под обложкой имеют **фиксированную высоту** (например, 2 строки
  максимум) с ellipsis, чтобы переменная длина названия не сдвигала визуальный baseline.
- Контракт «grid stable, content slides» — verifiable invariant: автотест или
  golden-test проверяет, что bounding box фокус-плитки не двигается в screen space
  при перемещении фокуса в той же полосе.

## Approach

Поверх уже работающего pin-at-slot механизма в `cinema_row.dart`:

1. **Tokens revision**: новые значения `focusedScale`, `cardH`, `metadataHeight` в
   `_grid_tokens.dart` — обновляются как **новые константы**, не модификация closed-spec
   `home-grid-optimization` (steering это запрещает).
2. **Fixed metadata height**: ввести `SizedBox(height: metaH)` обёртку для подписей,
   `Text` с `maxLines: 2, overflow: TextOverflow.ellipsis, softWrap: true`.
3. **Pinned-slot invariant tests**: golden или integration тест который двигает
   `FocusNode` через 5 плиток подряд и проверяет, что `RenderBox.localToGlobal(Offset.zero)`
   focused tile неподвижна.
4. **Optional**: соседние плитки получают `Opacity(0.92)` для усиления фокуса без
   геометрических сдвигов (TV-perf safe — `Opacity` дёшев в Flutter Impeller).

## Scope

- **In**:
  - Новые токены `focusedScale → 1.00`, `cardH ↑`, `metadataHeight = const`.
  - Fixed-height metadata wrapper для подписей под обложкой.
  - Документация pinned-slot контракта в коде (`cinema_row.dart`) и в спеке.
  - Verifiable invariant test для pinned-slot.
  - Применение нового `cardH` к `CinemaRow` в `CinematicHomeScreen` и `HomeScreen` (legacy).
- **Out**:
  - Изменение алгоритма pickColumns (закрыто `home-grid-optimization`).
  - Изменение fade-edge через DecoratedBox (закрыто `home-grid-visual-polish`).
  - Любая работа с hero (отдельный спек `hero-collapse-tile-morph`).
  - Изменения адаптивности (закрыто `mobile-adaptive-layout`).

## Boundary Candidates

- `lib/features/home/widgets/_grid_tokens.dart` — новые токены (extend, не replace).
- `lib/features/home/widgets/cinema_row.dart` — pinned-slot контракт + fixed metadata.
- `lib/features/home/widgets/poster_tile.dart` (или эквивалент) — fixed metadata height.
- `test/features/home/cinema_row_pinned_slot_test.dart` — invariant test (новый файл).

## Out of Boundary

- Не трогать `pickColumns` алгоритм.
- Не трогать `SafeFocusRing` toolkit (его реализация в `perf-safe-widgets`).
- Не трогать hero-логику.
- Не вводить новые packages в `pubspec.yaml`.

## Upstream / Downstream

- **Upstream**: `home-cinematic-redesign` (использует `CinemaRow`),
  `home-grid-optimization` (даёт pickColumns), `home-grid-visual-polish` (даёт fade-edge),
  `design-system-foundation` (даёт tokens infrastructure), `perf-safe-widgets`
  (даёт `SafeFocusRing`).
- **Downstream**: `hero-collapse-tile-morph` — целевой размер плитки в финальной
  геометрии определяет, в какой размер морфит коллапснутый hero.

## Existing Spec Touchpoints

- **Extends**: ничего не открываем. Все правки — новые токены и новые контракты.
- **Adjacent**:
  - `home-cinematic-redesign` (потребитель `CinemaRow`).
  - `home-grid-optimization` / `home-grid-visual-polish` (НЕ ОТКРЫВАТЬ — закрытые).

## Constraints

- **Perf**: соблюдать `flutter-tv-perf.md` (Realtek `rtd2851a`, avg `GPURasterizer::Draw ≤ 16.7ms`).
  Запрещено: `BackdropFilter`, `ImageFilter.blur`, `ShaderMask`, `BoxShadow.blurRadius>12`,
  `AnimatedContainer.width`.
- **No new packages** в pubspec.yaml.
- **All existing tests pass** — особенно тесты `home-grid-optimization`.
- **Backward compatible**: legacy `HomeScreen` (`/home`) и `CinematicHomeScreen`
  (`/home-cinematic`) оба используют `CinemaRow` — обе должны работать с новыми токенами.
