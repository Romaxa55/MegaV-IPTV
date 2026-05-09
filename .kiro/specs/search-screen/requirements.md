# Requirements Document

## Introduction

`search-screen` — Wave 2 спек, добавляющий **net-new TV-grade поиск** в MegaV IPTV. Сегодня поиска во Flutter-приложении нет; design handoff (`search-v2.jsx`, 582 строки) задаёт эталон: 6×6 кириллическая экранная клавиатура, D-pad-навигация без physical keyboard, debounced запросы и сетка результатов. Этот спек создаёт `lib/features/search/` с экраном, клавиатурой, полем ввода и сеткой результатов на базе уже закрытых foundation-спеков, плюс минимально расширяет API-слой.

Foundation-зависимости (ВСЕ закрыты — GO):
- `design-system-foundation` (#4): `AppPalette`, `AppRadius`, `MegaVTextStyles`, `AppColors` proxy.
- `perf-safe-widgets` (#13): `SafePill`, `SafeFocusRing`, `SafeBackdrop`, `ComputedColors`, `kSafeShadowBlurMax`.
- `design-system-atoms` (#14): `Poster`, `Chip`, `MvButton`, `MvIconButton`, `SectionTitle`, `RemoteHint` через barrel `package:megav_iptv/core/ui/atoms/atoms.dart`.

Целевое устройство: Realtek `rtd2851a` Android TV-бокс. Performance-budget из `flutter-tv-perf.md` соблюдается: `GPURasterizer::Draw` avg ≤ 16.7 ms, debounce 250–400 ms (Leanback `lb_card_selected_animation_delay`), focus-анимации через `Transform.scale`, никаких `BackdropFilter`/`ShaderMask`/`BoxShadow.blurRadius > 12`.

См. `brief.md`, GitHub issue #10, `.kiro/design/megav-iptv-handoff/project/screens/search-v2.jsx`, `.kiro/steering/flutter-tv-perf.md`, `.kiro/steering/roadmap.md`.

## Boundary Context

- **In scope** (NEW в `lib/features/search/`):
  - `search_screen.dart` — главный экран `/search`, 2-колоночный layout (left 360 logical px keyboard pane, right 1fr results pane).
  - `widgets/cyrillic_keyboard.dart` — 6×6 кириллическая клавиатура (А–Я, Ё, твёрдый/мягкий знак) + utility-row (Пробел, Стереть, RU/EN-switch). D-pad-навигация по `focusRow / focusCol`.
  - `widgets/search_input.dart` — текстовое поле с blinking accent caret через `AnimationController` + `RepaintBoundary` (изолированно от parent).
  - `widgets/search_results_grid.dart` — сетка результатов на `Poster` atoms, lazy-load (initial 20, scroll → +20).
  - `widgets/search_state.dart` — sealed `SearchUiState` (`Idle` / `Loading` / `Empty` / `Error` / `Results`) + Riverpod state-controller.
  - `state/search_controller.dart` — Riverpod `AsyncNotifier`/`StateNotifier`, debounce 350 ms, re-entry guard `_inFlight`.
  - Тесты: widget tests клавиатуры (D-pad nav), search_input (caret blink), results-grid (states), unit tests state-controller (debounce + re-entry).

- **In scope** (MINIMAL EXTENSION существующих файлов):
  - `lib/core/api/api_client.dart` — добавить **один** новый метод `searchChannels({required String query, int limit = 20, int offset = 0})` возвращающий `({List<Channel> channels, int total})`. **Все существующие методы (`getCategories`, `getChannels`, `getFeaturedChannels`, `getNowPlaying`, `getCurrentProgram`, `getUpcomingPrograms`, `getBestStreamUrl`, `thumbnailUrl`, `getCategoryNowPlaying`, `getMoviesNowPlaying`, `getFeaturedNowPlaying`, `getUpcomingAll`, `dispose`) сохраняют сигнатуру и поведение — backward-compat обязательна.**
  - `lib/app.dart` — добавить `GoRoute(path: '/search', builder: (_, _) => const SearchScreen())` в существующий `_router` без изменения других routes.
  - `lib/features/home/widgets/...` — добавить **single** search-affordance (icon-button) в существующий header home-screen, кликабельный → `context.push('/search')`. Никакая другая логика home-screen не меняется.

- **Out of scope**:
  - Voice search (явно out per roadmap & brief).
  - Search by genre/category (только text-search).
  - Backend search-index изменения, новые HTTP-endpoint'ы (используется существующий `/api/channels?search=` контракт).
  - Search suggestions / prefix API.
  - Mobile (issue #12 owner; mobile-adaptive-layout сам решит, переиспользует ли клавиатуру).
  - Изменение `pickColumns 3/4/5` логики (закрыто `home-grid-optimization`).
  - Изменение `PlayerUiState` (`player-overlay-state-machine` не трогается).
  - Native-player engine, playlist-loader, EPG-data layer.

- **Adjacent expectations**:
  - 65 существующих тестов (foundation + atoms + closed specs) продолжают проходить без модификации.
  - Все atoms используются через barrel `package:megav_iptv/core/ui/atoms/atoms.dart`; этот спек НЕ добавляет новых atoms.
  - Theming через `Theme.of(context)` + `AppColors.X`; этот спек НЕ модифицирует palettes.
  - `flutter analyze` чисто на всех новых файлах.
  - Все правила из `flutter-tv-perf.md` соблюдены (см. Req 9).

## Requirements

### Requirement 1: Search-route регистрация и search-affordance

**Objective:** Как пользователь home-screen, я хочу видеть и нажимать кнопку поиска в header'е, чтобы перейти на экран `/search`.

#### Acceptance Criteria

1. The Router shall register a new `GoRoute` with `path: '/search'` whose builder returns `const SearchScreen()`.
2. The Router shall preserve all existing routes (`/`, `/home`, `/player`, `/settings`) without modification.
3. The Home Screen header shall display a clickable search-affordance (mag-glass icon button) that on `OK`/`tap` invokes `context.push('/search')`.
4. The search-affordance shall be focusable via D-pad and visually highlight via `SafeFocusRing` when focused.
5. While the user navigates back from `/search`, the Home Screen shall restore previous focus and scroll position unchanged.

### Requirement 2: 6×6 cyrillic keyboard layout

**Objective:** Как TV-пользователь без physical keyboard, я хочу видеть полную кириллическую клавиатуру 6×6 + utility-row, чтобы вводить запрос пультом.

#### Acceptance Criteria

1. The Cyrillic Keyboard shall render a 6×6 grid of character keys with the exact layout from `search-v2.jsx` `KB_ROWS`:
   - Row 0: А Б В Г Д Е
   - Row 1: Ё Ж З И Й К
   - Row 2: Л М Н О П Р
   - Row 3: С Т У Ф Х Ц
   - Row 4: Ч Ш Щ Ъ Ы Ь
   - Row 5: Э Ю Я + 3 utility cells (Пробел, Стереть, RU/EN)
2. The Cyrillic Keyboard shall accept exactly one optional locale prop (`KeyboardLocale.ru` default | `KeyboardLocale.en`); when `en` selected, character cells switch to a 6×6 latin layout (A–Z plus utility row).
3. Each character cell shall render a `MvKey`-style keycap (background `AppPalette.surface2`, radius `AppRadius.brXs`, typography `metaMono`).
4. The utility row shall expose three actions: `space` (inserts ` `), `backspace` (removes last char), `localeToggle` (switches RU↔EN).
5. The Cyrillic Keyboard shall expose a callback `onKeyPressed(KeyboardKey key)` where `KeyboardKey` is a sealed type covering `Char(String glyph)`, `Space`, `Backspace`, `LocaleToggle`.
6. The Cyrillic Keyboard shall not depend on physical keyboard input — it is purely a visual D-pad-navigable widget.

### Requirement 3: D-pad navigation внутри клавиатуры

**Objective:** Как TV-пользователь, я хочу перемещать фокус по клавиатуре стрелками пульта и активировать клавиши `OK`, чтобы вводить текст без physical keyboard.

#### Acceptance Criteria

1. The Cyrillic Keyboard shall maintain `(focusRow, focusCol)` integer state, both in range `[0, 5]`.
2. While `arrowUp` is pressed, the Cyrillic Keyboard shall decrement `focusRow` clamped to 0 (does not wrap).
3. While `arrowDown` is pressed, the Cyrillic Keyboard shall increment `focusRow` clamped to 5 (does not wrap).
4. While `arrowLeft` is pressed and `focusCol > 0`, the Cyrillic Keyboard shall decrement `focusCol`.
5. While `arrowLeft` is pressed and `focusCol == 0`, the Cyrillic Keyboard shall NOT consume the event — the parent `SearchScreen` interprets it (no-op at left edge of pane).
6. While `arrowRight` is pressed and `focusCol < 5`, the Cyrillic Keyboard shall increment `focusCol`.
7. While `arrowRight` is pressed and `focusCol == 5`, the Cyrillic Keyboard shall NOT consume the event — the parent `SearchScreen` shall transfer focus to the results pane.
8. While `OK` is pressed on a character cell, the Cyrillic Keyboard shall invoke `onKeyPressed(Char(glyph))` exactly once.
9. While `OK` is pressed on a utility cell, the Cyrillic Keyboard shall invoke `onKeyPressed(Space|Backspace|LocaleToggle)` accordingly.
10. The focused cell shall be visually distinguished via `Transform.scale(1.05)` + `SafeFocusRing` (no `AnimatedContainer.width` per `flutter-tv-perf.md`).

### Requirement 4: Search input field with blinking caret

**Objective:** Как пользователь, я хочу видеть текущий запрос в крупном поле с пульсирующей кареткой, чтобы понимать состояние ввода.

#### Acceptance Criteria

1. The Search Input shall render the current `query` string at typography `Theme.of(context).megavText.displayLarge` (≈32 logical px) with letter-spacing per design.
2. The Search Input shall render an accent-coloured caret bar adjacent to the last character whose opacity blinks 1.0 ↔ 0.2 with period 1000 ms.
3. The blinking caret shall be driven by an `AnimationController(duration: 1000ms, repeat: true)` wrapped in a `RepaintBoundary` so the parent screen does NOT rebuild on each tick.
4. While `query` is empty, the Search Input shall display a placeholder string («Найти что-то стоящее» or equivalent) at lower opacity, with the blinking caret rendered at the placeholder's start.
5. The Search Input shall NOT accept physical keyboard input — its `query` is mutated only via the controller responding to `onKeyPressed` callbacks from the Cyrillic Keyboard.

### Requirement 5: Search controller with debounced query

**Objective:** Как пользователь, я хочу чтобы запросы к API не отправлялись на каждое нажатие клавиши, а с задержкой, чтобы не нагружать сеть.

#### Acceptance Criteria

1. The Search Controller shall maintain a `query` string, mutated synchronously on each `onKeyPressed` (so the Search Input updates immediately).
2. The Search Controller shall debounce API requests with a `Timer(Duration(milliseconds: 350))` per Leanback timing (`lb_card_selected_animation_delay` 400 ms — chosen 350 ms as documented project default within the 250–400 ms band).
3. While a new keypress arrives within the debounce window, the Search Controller shall cancel the pending Timer and start a fresh one — only the last query within the window triggers an API request.
4. While `query.length < 1`, the Search Controller shall NOT send any API request and shall transition to `SearchUiState.idle`.
5. The Search Controller shall guard concurrent API calls with an `_inFlight` boolean: while one request is awaiting, a newly-debounced request shall not start until the previous one resolves or fails.
6. The Search Controller shall be implemented as a Riverpod `StateNotifier` (or `AsyncNotifier`) and expose its current state as a watchable provider.

### Requirement 6: Results grid with state rendering

**Objective:** Как пользователь, я хочу видеть результаты поиска в визуальной сетке с понятными состояниями (загрузка/пусто/ошибка/успех).

#### Acceptance Criteria

1. The Results Pane shall render based on a sealed `SearchUiState` with exactly the variants: `Idle`, `Loading`, `Empty`, `Error(message)`, `Results(items, total)`.
2. While state is `Idle`, the Results Pane shall display a hint placeholder (e.g. «Начните вводить запрос»).
3. While state is `Loading` (after debounce, before response), the Results Pane shall display a centred progress indicator (`CircularProgressIndicator` или equivalent), retaining previous results muted (50% opacity) so the pane does not flash.
4. While state is `Empty`, the Results Pane shall display a textual «Ничего не найдено» message with the current query echoed.
5. While state is `Error(message)`, the Results Pane shall display the error string and a `MvButton.ghost` «Повторить» action that re-issues the last query.
6. While state is `Results(items, total)`, the Results Pane shall render items in a grid using the `Poster` atom from `package:megav_iptv/core/ui/atoms/atoms.dart`, with channel name as `title`.
7. The grid shall use `pickColumns(MediaQuery.of(context).size.width)` for column count (3/4/5 per closed `home-grid-optimization` rules) but is allowed to clamp max columns to 4 in the right pane (since 360 logical px are reserved for keyboard).
8. The grid shall use `cacheExtent: 1500`, `addAutomaticKeepAlives: true`, `addRepaintBoundaries: true` per `flutter-tv-perf.md`.

### Requirement 7: Lazy-load pagination of results

**Objective:** Как пользователь, я хочу прокручивать результаты дольше initial-страницы и видеть подгрузку без блокировки UI.

#### Acceptance Criteria

1. The Search Controller shall request the initial page with `limit: 20, offset: 0`.
2. While the user scrolls within `cacheExtent` of the last item AND `Results(items.length < total)`, the Search Controller shall request the next page with `offset: items.length`.
3. The Search Controller shall guard pagination with the same `_inFlight` flag — concurrent next-page requests are not issued.
4. While `query` changes (new debounced request issued), the Search Controller shall reset paging state (`offset = 0`) and discard previous items.
5. While a pagination request fails, the Search Controller shall NOT replace existing items — it surfaces a transient error indicator (e.g. footer chip) but keeps the loaded items rendered.

### Requirement 8: API extension — `searchChannels` (backward-compat bounded)

**Objective:** Как разработчик, я хочу добавить в `ApiClient` единственный новый метод `searchChannels` без изменения существующего API surface.

#### Acceptance Criteria

1. The Api Client Module shall add exactly one new public method `searchChannels({required String query, int limit = 20, int offset = 0})` returning `Future<({List<Channel> channels, int total})>`.
2. The Api Client Module shall implement `searchChannels` by calling the existing `/api/channels` endpoint with `search=<query>&limit=<limit>&offset=<offset>` query parameters (no new HTTP endpoint introduced — backend contract unchanged).
3. The Api Client Module shall preserve every existing method signature exactly: `getCategories`, `getChannels`, `getFeaturedChannels`, `getNowPlaying`, `getUpcomingAll`, `getCategoryNowPlaying`, `getMoviesNowPlaying`, `getFeaturedNowPlaying`, `getCurrentProgram`, `getUpcomingPrograms`, `getBestStreamUrl`, `thumbnailUrl`, `dispose`. Any caller of these methods shall continue compiling and behaving identically.
4. The Api Client Module shall NOT alter the constructor signature, the `baseUrl` field, the underlying `_client` field, or `_enrichThumbnail` private helper.
5. While the response status code is 200, `searchChannels` shall parse the response identically to `getChannels` — `data['channels']` (List) → `Channel.fromJson` mapping, `data['total']` (int).
6. While the response status code is non-200, `searchChannels` shall throw `Exception('Failed to search channels')` (mirrors existing pattern).
7. A unit test shall cover both successful parsing and non-200 throw, AND a regression test shall assert that calling `getChannels(search: 'q')` (existing pre-spec API) still works unchanged.

### Requirement 9: Performance compliance with flutter-tv-perf.md

**Objective:** Как пользователь TV-бокса rtd2851a, я хочу плавный 60 fps при использовании поиска без лагов скролла или фокуса.

#### Acceptance Criteria

1. No file under `lib/features/search/` shall use `BackdropFilter`, `ShaderMask`, or `ImageFilter.blur` (verified by grep — 0 hits).
2. No file under `lib/features/search/` shall set `BoxShadow.blurRadius > 12` (verified by grep `blurRadius:\s*([2-9][0-9]+|1[3-9])` — 0 hits in production code).
3. The blinking caret animation shall be wrapped in a `RepaintBoundary` so its 1 Hz tick does not rebuild the parent screen.
4. The keyboard focus visual shall use `Transform.scale` (or `AnimatedScale`) and not `AnimatedContainer.width`.
5. The results grid `ListView`/`GridView` shall set `cacheExtent: 1500`, `addAutomaticKeepAlives: true`, `addRepaintBoundaries: true`.
6. The Search Controller's debounce duration shall be in the band `[250, 400]` ms inclusive (Leanback-aligned).
7. While typing rapidly (≥6 keys/sec for 5 sec), the parent `SearchScreen` `build` shall be invoked at most 2× per second on `query` change (debounce-isolated state); BUILD events count over 30 sec idle on rtd2851a target shall be ≤ 5.

### Requirement 10: Sealed UI state and Riverpod isolation

**Objective:** Как разработчик, я хочу иметь compile-time-полную state-machine для search-UI, чтобы исключить недопустимые состояния.

#### Acceptance Criteria

1. The Search State Module shall define a sealed class `SearchUiState` in `lib/features/search/widgets/search_state.dart` with exactly the variants `Idle`, `Loading`, `Empty(query)`, `Error(message, lastQuery)`, `Results(items, total, query, hasMore)`.
2. The Search Controller's `state` setter shall be the single mutation point — every transition goes through `_transition(SearchUiState newState)`.
3. The `_transition` method shall cancel any pending debounce or pagination Timer BEFORE calling `state = newState`, mirroring the `player-overlay-state-machine` pattern.
4. A `switch` over `SearchUiState` in the rendering code shall be exhaustive (no `default:` case).
5. The Search Controller shall be exposed via a Riverpod provider factory (e.g. `searchControllerProvider`) and consumed via `ref.watch` inside the screen — `SearchScreen` itself remains `ConsumerWidget` (not `ConsumerStatefulWidget`) so heavy rebuilds are avoided.

### Requirement 11: Atom & foundation reuse only — no duplicates

**Objective:** Как maintainer codebase, я хочу чтобы search-screen использовал готовые atoms, а не дублировал presentation.

#### Acceptance Criteria

1. The Search Screen shall display result tiles using `Poster` atom imported from `package:megav_iptv/core/ui/atoms/atoms.dart`.
2. The Search Screen shall display utility-row buttons using `MvButton` or `MvIconButton` atoms.
3. The Search Screen shall display section headers using `SectionTitle` atom.
4. The Search Screen shall display recent-queries chips using `Chip` atom (variant `ghost` or `defaultVariant`).
5. The Search Screen shall display remote-hint footer using `RemoteHint` atom.
6. The Search Screen shall NOT define any widget that duplicates an existing atom's purpose; if a shape is missing, this spec extends the atoms package via a follow-up issue, not via local definitions.
7. The Search Screen shall consume colours via `Theme.of(context)` + `AppColors.X` proxy — no hardcoded `Color(0x...)` literals except where matching `flutter-tv-perf.md` examples (gradient overlays).

### Requirement 12: Testability and analyzer cleanliness

**Objective:** Как maintainer, я хочу чтобы search-фичу можно было покрыть юнит-тестами и она не ломала существующие 65 тестов.

#### Acceptance Criteria

1. The Cyrillic Keyboard shall expose a `@visibleForTesting` constructor parameter for an injectable `(focusRow, focusCol)` initial state, enabling deterministic D-pad tests.
2. The Search Controller shall accept an injectable `ApiClient` (or `Future<({List<Channel> channels, int total})> Function(String, int, int)` callback) so unit tests can stub network calls without `http.MockClient` boilerplate.
3. A widget test shall assert that pressing arrowDown on row 0 moves `focusRow` to 1 and that arrowDown on row 5 keeps `focusRow` at 5 (no wrap).
4. A widget test shall assert that pressing OK on cell `(0, 0)` invokes `onKeyPressed(Char('А'))`.
5. A unit test shall assert that two synchronous keypresses within 350 ms result in exactly ONE `searchChannels` call (debounce works).
6. A unit test shall assert that `searchChannels` returns the same shape as `getChannels(search: ...)` for the same query (parity check).
7. `flutter analyze` shall report 0 errors, 0 warnings on every new file under `lib/features/search/` and on the modified `lib/core/api/api_client.dart`.
8. All 65 pre-existing tests (foundation + atoms + closed specs) shall continue to pass without modification after this spec lands.
