# Brief: home-grid-visual-polish

## Problem
После закрытия спека `home-grid-optimization` (commit e78e84c) пользователь подтвердил субъективную плавность сетки на референсном TV-боксе (`192.168.100.8:5555`), но при последующем включении performance overlay (`P` в Flutter) обнаружил перформанс-долг и попросил визуальный полиш в стиле Netflix.

Конкретные наблюдения:
- **Performance baseline на TV** (зафиксирован в `snapshots/baseline_perf_overlay.png`): GPU thread `avg 20.3 ms/frame, max 34.2 ms/frame`. При целевых 60 fps бюджет = 16.7 мс. Среднее уже выше бюджета (~49 fps), пиковые миссы дают видимый stutter.
- **Резкое обрезание правого края ряда** (зафиксировано в `snapshots/baseline_clean.png`): частично-видимая 4-я плитка справа упирается в правый край экрана без визуального fade. Netflix Android TV в аналогичной позиции применяет `fadingEdge` (Leanback `lb_browse_rows_fading_edge = 16dp`).
- **Подписи каналов** на правых плитках («MM Стивен Кинг HD» и пр.) почти упираются в край карточки — текстовый padding узкий.
- Срезание постера сверху на активной плитке, замеченное на macOS-сборке, **на TV не воспроизводится** — это был артефакт desktop-рендера и/или пойманный midflight scale-кадр. Не входит в этот спек.

## Current State
После Major 2/3/4/5 предыдущего спека:
- `_grid_tokens.dart`, `cinema_card.dart`, `cinema_row.dart`, `home_screen.dart` — на текущей реализации.
- 17/17 авто-тестов зелёные, `flutter analyze` чист.
- На TV: 4 плитки в ряду на FullHD, фиксированная ширина, scale-only фокус, debounce 400 мс, compact/full overlay split.
- Не реализовано:
  - Fade-edge правого края ряда (резкий обрез частично-видимой плитки).
  - `Visibility(visible: isFocused, ...)` обёртка над `_buildFullOverlay()` — сейчас полный overlay билдится у ВСЕХ плиток, даже невидимых (opacity == 0). Это была документированная отложенная оптимизация в `tasks.md` task 5.6.
  - Перепроверка hot-path'а на скролле: что ещё ребилдится в кадре, кроме full overlay?

## Desired Outcome
1. Правый край ряда **визуально плавно затухает** (а-ля Netflix), частично-видимая плитка не обрезается резко.
2. На референсном TV-боксе perf-overlay при скролле: avg ≤ 16.7 мс, max ≤ 25 мс. При невозможности достичь стабильно (например, на этом железе физический потолок) — задокументировать остаточный долг и закрыть с явным признанием.
3. Подписи каналов в compact-overlay'е не упираются в правый край карточки (минимальный косметический фикс).
4. Никакой регрессии существующих 17 тестов; никакого расширения публичного API виджетов.
5. Side-by-side сравнение `snapshots/baseline_*.png` с `snapshots/after_*.png` — оператор видит визуальное и численное улучшение.

## Approach
**Подход 2 «Сбалансированный»** — выбран среди трёх рассмотренных.

Изменения по слоям:

**В `cinema_row.dart`**:
- Обернуть горизонтальный `ListView.builder` в `ShaderMask` с `BlendMode.dstOut` и `LinearGradient(stops: [0, ~0.95, 1.0], colors: [transparent, transparent, opaque-mask])`. Это создаст fade-out на последних 5% ширины ряда. Левый край не fade-им (там фиксированная стартовая позиция первой плитки, fade был бы артефактом).
- Поведение fade-edge **не зависит от ширины окна** — он всегда `~5%` ширины ряда. Можно зафиксировать как `GridTokens.fadeEdgeFraction = 0.05` в `_grid_tokens.dart`.

**В `cinema_card.dart`**:
- Обернуть `_buildFullOverlayWithFade()` дополнительным внешним слоем: `Visibility(visible: widget.isFocused || _wasRecentlyFocused, child: ...)`, где `_wasRecentlyFocused` — флаг State, который остаётся `true` ещё `GridTokens.overlayFade.inMilliseconds` после потери фокуса (чтобы fade-out отработал, не «ножом» обрезался). Альтернатива проще: `Offstage(offstage: !widget.isFocused, child: ...)` с обёрткой над AnimatedOpacity — но это режет fade-out полностью; Visibility с пост-fade flag — компромисс.
- Увеличить bottom padding в `_buildBottomChannelLine` с текущих ~2.h до 6.h, чтобы текст не упирался в нижний край.

**В `_grid_tokens.dart`**:
- Добавить `static const double fadeEdgeFraction = 0.05` (или 0.04–0.06 на ваш вкус).

**Что не делается в этом спеке**:
- `RepaintBoundary` гигиена — отдельная отложенная задача (Подход 3 из предыдущего спека).
- `CachedNetworkImage` — отдельная отложенная задача.
- Переписывание `_buildProgressSection` на `CustomPainter` — отдельная отложенная задача.
- Дополнительная диагностика hot-path'а через DevTools timeline — будет частью task'а 5.x этого спека (manual perf-инспекция оператором), а не автоматическим subagent-ревью.

## Scope
- **In**:
  - `cinema_row.dart` — добавить ShaderMask fade-edge на правом крае ряда.
  - `cinema_card.dart` — добавить Visibility-обёртку для отключения билда невидимого full overlay; увеличить bottom-padding compact-строки.
  - `_grid_tokens.dart` — добавить `fadeEdgeFraction` константу.
  - Авто-тесты на новое поведение: (a) ShaderMask присутствует в дереве cinema_row, (b) full overlay не билдится при `isFocused == false`.
  - After-снапшот с TV (clean + perf overlay) для side-by-side сравнения.
- **Out**:
  - Hero-баннер сверху, BootOverlay, плеер, EPG, sidebar — out of boundary как и в предыдущем спеке.
  - Замена `Image.network` на `CachedNetworkImage`.
  - `RepaintBoundary` хирургия и `CustomPainter` для прогресс-бара.
  - Любые изменения в data-providers, моделях, app_colors.
  - Срезание постера сверху на macOS — не воспроизводится на референсном TV, не входит.
  - Ручной аудит других экранов (`settings_screen`, `playlist_loader`) — отдельные истории.

## Boundary Candidates
- **Edge fade ряда** (`cinema_row.dart`) — визуальная маска, не влияет на focus-state и scroll-логику.
- **Visibility-обёртка карточки** (`cinema_card.dart`) — perf-оптимизация, не влияет на API виджета.
- **Token addition** (`_grid_tokens.dart`) — однострочное расширение существующей системы констант.

## Out of Boundary
- Любая работа в плеере (`lib/core/player/`).
- Любая работа с image loading (диск-кэш, Cached*Image, оптимизация декодинга).
- Изменения в Riverpod-провайдерах.
- Расширение публичного API `CinemaCard` или `CinemaRow`.
- Срезание постера на macOS — не воспроизводится на TV, требует отдельного desktop-теста если когда-то понадобится.

## Upstream / Downstream
- **Upstream**:
  - `home-grid-optimization` спек (закрыт, commit e78e84c) — этот спек его расширяет визуально, не ломая.
  - `lib/core/ui/utils/fast_scroll_detector.dart` — продолжаем читать, не менять.
  - `lib/core/theme/app_colors.dart` — продолжаем читать, не менять.
- **Downstream**:
  - Будущий спек на CachedNetworkImage / RepaintBoundary гигиену — наследует более чистую модель.
  - Будущий спек на player-stability — нет связи, отдельная история.

## Existing Spec Touchpoints
- **Extends**: `home-grid-optimization` (visually polishing on top of the closed implementation).
- **Adjacent**: нет.

## Constraints
- **Stack**: Flutter SDK + flutter_screenutil + flutter_riverpod (не меняется). Без новых пакетов.
- **Платформа**: целевое устройство — пользовательский TV-бокс на `192.168.100.8:5555`. Тестирование iOS/Web не требуется, но не должно сломаться.
- **Совместимость**: ни одного существующего теста (16 home-grid + 1 baseline) сломать нельзя; публичные API CinemaCard/CinemaRow остаются неизменными; контракт `onItemFocus` остаётся debounced 400 мс.
- **Performance**: `ShaderMask` на TV — известно дешёвая операция (single GPU shader pass), не должна добавить >2 мс к кадру. `Visibility` с unbuilt child — выигрыш ~3–5 мс на кадре скролла (сегодня full overlay билдится 4–5 раз в кадре ради opacity=0).
- **No new dependencies** в `pubspec.yaml`.
- **Принцип**: «не оптимизировать вслепую» — после реализации сравниваем `baseline_perf_overlay.png` (avg 20.3 мс) с `after_perf_overlay.png`. Если ≤ 16.7 мс — закрываем. Если нет — фиксируем остаточный долг и переходим к Подходу 3 (отдельный спек).
