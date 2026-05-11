# Brief: hero-collapse-tile-morph

## Problem

На `CinematicHomeScreen` коллапс hero при переходе вниз к рядам и его возврат при подъёме
вверх реализован через **`AnimatedCrossFade`** — hero визуально **исчезает в чёрную пустоту**,
оставляя пользователя без точки опоры. Обратный переход (стрелка вверх с первой полосы)
аналогично — hero просто появляется через крестфейд из пустоты.

User feedback дословно:
- «Когда возвращаюсь вверх не появляется эта хуйня, ну то есть все исчезает, черное
  место остается пустое.»
- «херо херо наверно сделать размером как буддто 1 строчка из плиток ну вс поуму
  и по феншую»
- «скрытие с эффектом сдвига чтоль»

Желаемое поведение — **киносъёмочный morph**: hero не исчезает, а **сжимается до размера
обычной плитки в первом слоте первой полосы** (как будто это первая карточка ряда «Сейчас
в эфире»), и плитки полосы заезжают на освобождённое пространство сверху.

## Current State

- `lib/features/home/cinematic/cinematic_home_screen.dart` — hero обёрнут в
  `AnimatedCrossFade(crossFadeState: _heroFocused ? showFirst : showSecond)`.
- `_heroFocused` слушается через `Focus(skipTraversal: true, onFocusChange:)` wrapper.
- `showFirst` — full hero (heroH = 620, fullBleed backdrop + title + Watch button).
- `showSecond` — `SizedBox.shrink()` (полная пустота).
- Первая полоса плиток позиционирована через **фиксированный** `Positioned(top: 620)`
  (не AnimatedPositioned — раньше анимация top вызывала ScrollController-attached-twice
  ошибки).
- Эффект: при стрелке вниз hero мгновенно исчезает, под ним пустое чёрное место, и
  первая полоса не двигается визуально — это и есть основной баг.

## Desired Outcome

- При стрелке **вниз** с hero на первую полосу: hero **slide+scale morph** в плитку
  в слоте 0 первой полосы. Длительность ~280–350ms, кривая `Curves.easeInOutCubic`.
- На последнем кадре морфа hero визуально **становится первой плиткой** полосы
  (тот же aspect, тот же радиус, тот же фокус-кольцо если фокус остался на «hero-tile»).
- Соседние плитки полосы **слайдятся вправо** (или влево, в зависимости от направления
  чтения и pinned-slot) чтобы освободить слот 0 для hero-tile — но это уже работа
  pinned-slot контракта из `home-grid-stability-pass`.
- При стрелке **вверх** с плитки первой полосы (если фокус на «hero-tile» — то есть
  на слоте 0): обратный morph — плитка расширяется в hero. Длительность та же.
- На любом промежуточном кадре морфа: **нет чёрных дыр**, нет «прыжков», hero+первая полоса
  визуально слиты в единый geometric flow.
- D-pad навигация не теряется: focus survives через morph (через `FocusAttachment` или
  явный `FocusNode` ребиндинг).
- Анимация **отключаема** через `MediaQuery.disableAnimations` (accessibility).

## Approach

**Hero-as-tile геометрия (вариант a из discovery)**:
- Hero и первая плитка слота 0 — это **один и тот же виджет** в дереве, оборачивающий
  одни и те же визуальные ресурсы.
- Виджет имеет 2 layout-режима: `expanded` (heroH ≈ 620, fullBleed metadata)
  и `collapsed` (cardH из `_grid_tokens`).
- Между режимами анимируется `AnimatedBuilder` + кастомный `TweenSequence`:
  - первые 50% — scale + position morph контейнера,
  - последние 50% — opacity-морф вспомогательных элементов (Watch button, large title,
    full backdrop затухает; обложка + плитка-подпись проявляются).
- Первая полоса — это `CinemaRow` со специальным первым слотом, занятым hero-tile widget.
  В expanded-режиме hero-tile визуально вылезает за верхнюю границу полосы (через
  `Stack + Positioned(top: -heroExtraExtent)`), в collapsed-режиме сидит ровно в своём
  слоте.

Преимущество: единый source-of-truth, нет двух деревьев виджетов, нет cross-fade,
focus transfer тривиален (focus на hero-tile widget живёт всегда, меняется только
его внешний вид).

Технически безопасно для TV-perf:
- Только `Transform.scale` + `AnimatedPositioned` (не `AnimatedContainer.width` — запрещено
  steering'ом).
- Только `Opacity` для текстовых элементов.
- Никаких `BackdropFilter`, `ImageFilter.blur`, `ShaderMask`.

## Scope

- **In**:
  - Новый виджет `HeroTileMorph` в `lib/features/home/cinematic/`.
  - Контроллер анимации (`AnimationController` 280ms, single `vsync`).
  - Интеграция в `CinematicHomeScreen`: hero перестаёт быть отдельным `Positioned`,
    становится первой плиткой первой полосы через специальный `firstSlot` API в `CinemaRow`.
  - Focus transfer контракт: focus survives через morph, не теряется при перемещении
    через morph-state.
  - `MediaQuery.disableAnimations` honors → instant snap между режимами.
  - Тесты: state machine morph (idle → morphing → collapsed → morphing → expanded),
    focus survival test.
- **Out**:
  - Само определение целевого размера плитки (это `home-grid-stability-pass`).
  - Видео-preview логика (уже работает через preview player, не трогаем).
  - Carousel timer hero (уже работает, не трогаем).
  - Layout остальных полос (только первая полоса получает специальный first slot).

## Boundary Candidates

- `lib/features/home/cinematic/hero_tile_morph.dart` — новый widget (новый файл).
- `lib/features/home/widgets/cinema_row.dart` — добавление optional `firstSlot` параметра
  для подмены первой плитки кастомным виджетом.
- `lib/features/home/cinematic/cinematic_home_screen.dart` — рефакторинг: hero перестаёт
  быть отдельным Positioned, передаётся в `firstSlot` первой `CinemaRow`.
- `test/features/home/cinematic/hero_tile_morph_test.dart` — state machine + focus.

## Out of Boundary

- Не трогать другие полосы (только первая).
- Не трогать carousel timer.
- Не трогать preview player.
- Не трогать grid tokens (использует значения из `home-grid-stability-pass`).
- Не вводить новые packages.

## Upstream / Downstream

- **Upstream**:
  - `home-grid-stability-pass` (даёт финальный `cardH`/`cardW` для target morph state).
  - `home-cinematic-redesign` (даёт текущий hero и `CinemaRow`).
  - `design-system-foundation` (tokens, theme).
  - `perf-safe-widgets` (`SafeFocusRing` для focus indication).
- **Downstream**:
  - `visual-feedback-pipeline` (скриншоты hero-expanded vs hero-collapsed —
    визуальные эталоны).

## Existing Spec Touchpoints

- **Extends**: ничего не открываем. Все правки — новый widget + точечная интеграция.
- **Adjacent**:
  - `home-cinematic-redesign` (НЕ ОТКРЫВАТЬ — закрытый. Модифицируем только site of use
    в `CinematicHomeScreen`).
  - `home-grid-stability-pass` (parallel sibling — даёт target размер).
  - `player-cinematic-redesign` (НЕ ТРОГАТЬ — отдельный экран).

## Constraints

- **Perf**: соблюдать `flutter-tv-perf.md`. Запрещено: `BackdropFilter`, `ShaderMask`,
  `AnimatedContainer.width`, `BoxShadow.blurRadius>12`. Allowed: `Transform.scale`,
  `AnimatedPositioned`, `Opacity`, `AnimatedBuilder`.
- **Animation duration**: 280–350ms, fixed (no spring physics — детерминированно).
- **Accessibility**: `MediaQuery.disableAnimations` → instant snap.
- **Focus**: focus survives через morph без явного `FocusNode.requestFocus()` после
  завершения анимации (использовать persistent FocusNode).
- **All existing tests pass**, особенно cinematic home tests.
- **No new packages**.
- **Backward compat**: legacy `HomeScreen` (`/home`) не использует hero-tile morph,
  остаётся как есть. Спек трогает только `CinematicHomeScreen`.
