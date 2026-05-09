# Requirements Document — epg-screen

## Introduction

`epg-screen` — Wave 2 спек: полноэкранный электронный программный гид (EPG) с **двумерной time-grid**: вертикальный rail каналов слева + горизонтальная сетка передач справа (10 слотов × 30 мин = 5h окно). Цель — превзойти Netflix-style гид по удобству пульта на TV-боксе rtd2851a, оставаясь в рамках `flutter-tv-perf.md` (Mali-class GPU, virtualised 2D scrolling, без `BackdropFilter`/`ShaderMask`).

Сейчас в проекте есть только **player-overlay EPG** (`lib/features/player/widgets/epg_overlay.dart`, 1D timeline по одному каналу) — он принадлежит закрытому спеку `player-overlay-state-machine` и **не должен** ломаться. Полноэкранный 2D-гид отсутствует.

Эталон-дизайн: `.kiro/design/megav-iptv-handoff/project/screens/epg-v2.jsx` (549 строк, см. `brief.md`). Header italic display 56 px «Программа передач» + DayPicker (-2..+4 дня), filter row с category pills (через атом `GenreTabs`), main area 2-col grid (CH_W = 240 px channel rail + scrollable time grid SLOT_W = 180 px / ROW_H = 88 px), NOW marker в **начале** видимого окна, preview-strip снизу.

Foundation deps (все закрыты + GO):
- `design-system-foundation` (#4) — `AppPalette`, `AppRadius`, `MegaVTextStyles`, `themeProvider`, `AppColors` proxy.
- `perf-safe-widgets` (#13) — `SafeBackdrop`, `SafePill`, `SafeFocusRing`, `SafeFilmGrain`, `combinedHeroGradient`, `ComputedColors`, `kSafeShadowBlurMax`, ассеты grain.
- `design-system-atoms` (#14) — 13 атомов через barrel `package:megav_iptv/core/ui/atoms/atoms.dart` (используем `Brand`, `Chip`, `GenreTabs`, `MMLogo`, `MvButton`, `MvIconButton`, `MvKey`, `Poster`, `RemoteHint`, `SectionTitle`, `MvTrack`).

**Data layer extension allowed** (per roadmap): этот спек **МОЖЕТ** расширить `lib/core/epg/*` (создать новый файл `epg_repository.dart` + `epg_window_provider`) для batch-запроса передач по N каналам в окне `[from..to]`. Расширение не должно ломать инварианты существующего player-overlay EPG (через `currentProgramProvider` / `upcomingProgramsProvider` в `lib/core/providers/providers.dart`) — поведение per-channel оригинального API остаётся идентичным.

Целевое устройство: Realtek `rtd2851a` Android TV-бокс. Performance budget из `flutter-tv-perf.md` (avg `GPURasterizer::Draw ≤ 16.7 ms` при scroll, BUILD events ≤ 5/30 sec idle) соблюдается жёстко.

См. `brief.md`, GitHub issue #9, `.kiro/design/megav-iptv-handoff/`, `.kiro/steering/roadmap.md`, `.kiro/steering/flutter-tv-perf.md`.

## Boundary Context

- **In scope** (NEW в `lib/features/epg/`):
  - `EpgScreen` — Riverpod-aware top-level widget с time-grid layout, gated через новый `go_router` route `/epg`.
  - `epg_screen.dart` — корневой widget; композирует header + day-picker + genre-tabs + grid + preview-strip.
  - `widgets/epg_day_picker.dart` — горизонтальный rail дней (-2..+4 от сегодня).
  - `widgets/epg_category_filter.dart` — обёртка над атомом `GenreTabs` для category-фильтра передач.
  - `widgets/epg_channel_rail.dart` — вертикальный список каналов слева (CH_W = 240 px), badge + name + groupTitle.
  - `widgets/epg_time_axis.dart` — sticky горизонтальная шкала времени над time-grid (10 слотов × 30 мин).
  - `widgets/epg_time_grid.dart` — virtualised 2D grid (синхронизированные `ScrollController`'ы для row vs col).
  - `widgets/epg_program_cell.dart` — ячейка передачи с `Chip(variant: live)` для текущей + focus-scale.
  - `widgets/epg_now_marker.dart` — вертикальная accent-линия + label, в начале visible window.
  - `widgets/epg_preview_strip.dart` — sticky preview снизу (132×76 thumbnail + meta + actions), отображает фокусированную программу.
  - `state/epg_screen_state.dart` — sealed UI-state (`Loading | Ready | Error`) + одна точка `_transition`.
  - `state/epg_focus_controller.dart` — D-pad навигация (←→ time, ↑↓ channel, OK = open or switch).
  - Widget tests + smoke test всего экрана + golden-snapshot (опционально).

- **In scope** (DATA LAYER EXTENSION под `lib/core/epg/`, BOUNDED):
  - `lib/core/epg/epg_repository.dart` (NEW) — публичный класс `EpgRepository` с методом:
    `Future<Map<int, List<EpgProgram>>> programmesInWindow(DateTime from, DateTime to, List<int> channelIds)`.
  - `lib/core/epg/epg_window_provider.dart` (NEW) — Riverpod-провайдер `epgWindowProvider` (family по `(from,to,channelIds)`), кэширующий результаты в окне с TTL 60 sec.
  - Опционально расширение `ApiClient` в `lib/core/api/api_client.dart` методом `Future<Map<int, List<EpgProgram>>> getEpgWindow(...)` (один-метод add, не breaking) — если backend поддерживает batch-endpoint, иначе клиентский N-fan-out по существующим per-channel вызовам с in-flight de-dup.
  - **Инвариант сохраняется**: существующие `currentProgramProvider`, `upcomingProgramsProvider` в `lib/core/providers/providers.dart` остаются нетронутыми и продолжают работать для player-overlay EPG.

- **In scope** (ENTRY POINT TOUCH):
  - Один-line добавление route `/epg` в существующий router (без модификации других routes).
  - Один FAB / hint в legacy `home_screen.dart` НЕ добавляется этим спеком (запрещено модифицировать closed home_screen). Cinematic вариант (#5) при необходимости свяжет навигацию через свой rail.

- **Out of scope** (HARD prohibition):
  - Любые модификации `lib/features/player/widgets/epg_overlay.dart` — owned by closed `player-overlay-state-machine`.
  - Любые модификации `lib/features/home/widgets/*`, `home_screen.dart`, `cinema_row.dart`, `cinema_card.dart`, `_grid_tokens.dart` — closed.
  - Любые модификации `lib/core/providers/providers.dart` существующих провайдеров (`currentProgramProvider`, `upcomingProgramsProvider`) — read-only.
  - Backend / data source extension за пределами добавления одного batch-метода в `ApiClient` (новые модели данных, миграции БД, изменения формата `EpgProgram` — out of scope).
  - Mobile layout (#12) — отдельный спек.
  - Возврат `BoxShadow.blurRadius=50`, `ShaderMask`, `BackdropFilter`, `ImageFilter.blur` в hot-path.
  - Native player engines (`lib/core/player/*`) — read-only.
  - Sealed `PlayerUiState` — отдельный спек.

- **Adjacent expectations**:
  - Closed kiro specs продолжают компилироваться и тесты остаются зелёными.
  - `design-system-foundation` (#4): theme tokens читаются через `Theme.of(context)` и `AppColors.X`.
  - `perf-safe-widgets` (#13): все glassy/focus-эффекты композируются из `SafePill` + `SafeFocusRing` + `SafeFilmGrain` + `SafeBackdrop` + `combinedHeroGradient`.
  - `design-system-atoms` (#14): импорт через barrel `package:megav_iptv/core/ui/atoms/atoms.dart`.
  - `flutter-tv-perf.md` правила обязательны (Req 9).
  - `EpgProgram` модель из `lib/core/playlist/models/epg_program.dart` НЕ модифицируется.

## Requirements

### Requirement 1: EPG screen scaffold + entry route

**Objective:** Как пользователь TV-бокса, я хочу запускать полноэкранный программный гид через явное действие пульта (route `/epg`), чтобы получить 2D-вид «каналы × время» отдельно от плеера.

#### Acceptance Criteria

1. The EPG Screen Module shall provide a public `EpgScreen` widget located at `lib/features/epg/epg_screen.dart`.
2. The EPG Screen Module shall register a new `go_router` route `/epg` (or equivalent named route) that mounts `EpgScreen` as the root content.
3. While the user is on `/epg`, the application shall not modify the legacy `HomeScreen` route registration nor the player route registration.
4. The EPG Screen Module shall not place any new files inside `lib/features/home/widgets/`, `lib/features/player/widgets/`, or modify `home_screen.dart` / `epg_overlay.dart`.
5. The root `EpgScreen` widget shall expose a stable widget `Key('epg-screen-root')` for smoke tests.
6. The EPG screen shall consume the active palette and typography exclusively via `Theme.of(context)`, `AppColors.*`, and `MegaVTextStyles` from `design-system-foundation`.

### Requirement 2: Time-grid 2D layout with virtualised scrolling

**Objective:** Как пользователь, я хочу видеть в одном кадре несколько каналов с их передачами на ближайшие часы, чтобы быстро находить интересный контент без переключения каналов.

#### Acceptance Criteria

1. The EPG screen shall render a two-column root layout: a fixed-width vertical channel rail on the left (`CH_W = 240` logical px) and a horizontally scrollable time grid on the right.
2. The time grid shall use `SLOT_W = 180` logical px (= 30 min) and `ROW_H = 88` logical px per channel, matching the design handoff `epg-v2.jsx` constants.
3. The time grid shall be virtualised in **both axes**: an outer vertical `ListView.builder` of channel rows, with each row containing an inner horizontal `ListView.builder` of programme cells (or equivalent 2-axis virtualised primitive). Both list views shall set `cacheExtent: 1500`, `addAutomaticKeepAlives: true`, `addRepaintBoundaries: true`, `clipBehavior: Clip.none`.
4. The vertical channel rail and the time grid rows shall share a single `ScrollController` for the vertical axis so they remain visually aligned during vertical scroll.
5. The horizontal time axis header (Req 5) and every grid row shall share a single `ScrollController` for the horizontal axis so the time labels remain aligned with the cells underneath.
6. The grid shall display at least 100 channels × 50 slots without producing the «фриз» symptom (avg `GPURasterizer::Draw ≤ 16.7 ms` on rtd2851a per `flutter-tv-perf.md`).
7. The grid shall not use `BackdropFilter`, `ShaderMask`, or `ImageFilter.blur` in any cell / row / header build tree.

### Requirement 3: Channel rail rendering

**Objective:** Как пользователь, я хочу видеть слева компактный список каналов с логотипом, названием и группой, чтобы понимать «куда я смотрю» в большой сетке.

#### Acceptance Criteria

1. The Channel Rail shall render each channel cell with width `CH_W = 240` and height `ROW_H = 88`, containing a 38×38 colored brand badge (via `Brand` atom or equivalent), channel name (via `MegaVTextStyles.titleMedium`), and `groupTitle` (via `MegaVTextStyles.metaMono` or label small).
2. The Channel Rail shall use the same vertical `ScrollController` as the time grid (Req 2.4).
3. The Channel Rail shall render a focus indicator via `SafeFocusRing` when a channel cell receives focus, without any `BoxShadow.blurRadius > kSafeShadowBlurMax`.
4. The Channel Rail shall not modify `Channel` model, nor the existing `categoryNotifierProvider` / `featuredChannelsProvider` shape.
5. The Channel Rail shall expose a stable `Key('epg-channel-rail')` and individual cell keys `Key('epg-channel-cell-<channelId>')`.

### Requirement 4: Programme cell rendering with live highlight

**Objective:** Как пользователь, я хочу видеть в каждом слоте название передачи, прогресс для текущей и явный «LIVE» бейдж для эфирной программы, чтобы мгновенно отличать «сейчас» от «потом».

#### Acceptance Criteria

1. The EPG Programme Cell shall render programme `title` using `Theme.of(context).megavText.titleMedium` with `fontStyle: FontStyle.normal` (Golos Text 14 px / weight 500, **no italic** per design handoff brief).
2. The EPG Programme Cell shall display the start time using a monospaced style (`MegaVTextStyles.metaMono`).
3. While the programme is currently airing (`EpgProgram.isNow == true`), the cell shall render the `Chip(variant: ChipVariant.live)` atom and a thin `MvTrack`-style progress indicator bound to `EpgProgram.progress`.
4. The EPG Programme Cell shall span horizontal pixels equal to `ceil(duration.inMinutes / 30) * SLOT_W` capped at the visible window width.
5. While focused, the EPG Programme Cell shall apply `Transform.scale(1.05)` (or `AnimatedScale` with the same factor, 150 ms duration, `Curves.easeOutCubic`) and `SafeFocusRing`. It shall not use `AnimatedContainer.width` for focus emphasis.
6. The EPG Programme Cell shall use `transition: background 140 ms, transform 140 ms`-equivalent animations (e.g., `AnimatedContainer` for color / `AnimatedScale` for transform) — values consistent with `flutter-tv-perf.md` Leanback timings (150 ms card focus).
7. The EPG Programme Cell shall expose `Key('epg-programme-cell-<programmeId>')`.

### Requirement 5: Time-axis header

**Objective:** Как пользователь, я хочу видеть верхнюю шкалу с временем, чтобы понимать «когда» каждая колонка слотов.

#### Acceptance Criteria

1. The Time-Axis Header shall render labels every 30 min in monospaced typography (`MegaVTextStyles.metaMono`).
2. The Time-Axis Header shall scroll horizontally in lock-step with the time grid via the shared horizontal `ScrollController` (Req 2.5).
3. The Time-Axis Header shall be sticky to the top edge of the screen (sliver pinned header or equivalent).
4. The Time-Axis Header shall not include any blur / shader effects in its build tree.
5. The Time-Axis Header shall expose `Key('epg-time-axis')`.

### Requirement 6: NOW marker

**Objective:** Как пользователь, я хочу видеть явную вертикальную линию «прямо сейчас», чтобы мгновенно ориентироваться во времени относительно эфира.

#### Acceptance Criteria

1. The NOW Marker shall render a vertical accent line spanning the full grid height plus an «NOW» label at the top.
2. The NOW Marker shall be positioned at the **start** of the visible time window (left-edge offset corresponding to current local time relative to the grid origin) — explicitly **not** in the middle, per design handoff brief.
3. The NOW Marker glow / shadow shall use `SafeFocusRing` semantics or `BoxShadow.blurRadius ≤ kSafeShadowBlurMax`. Use of `BoxShadow.blurRadius > 12` is forbidden.
4. The NOW Marker shall update its position at most once per minute (timer-driven) — it shall not rebuild on every animation frame.
5. The NOW Marker shall expose `Key('epg-now-marker')`.

### Requirement 7: Day picker (-2..+4 days)

**Objective:** Как пользователь, я хочу выбирать день для просмотра программы передач в диапазоне «-2..+4 от сегодня», чтобы планировать просмотр или отматывать назад.

#### Acceptance Criteria

1. The Day Picker shall render a horizontal row of 7 day buttons covering today − 2 … today + 4.
2. The Day Picker shall mark the currently selected day visually distinct (focused-active state via `SafeFocusRing` + accent fill via `SafePill`).
3. The Day Picker shall, on day selection, trigger a state transition that re-fetches programmes for the new day window via `epgWindowProvider`.
4. The Day Picker shall use `MvButton` or `MvKey` atoms for individual day cells; it shall not render bespoke `RawMaterialButton`s.
5. The Day Picker shall expose `Key('epg-day-picker')`.

### Requirement 8: Category filter via GenreTabs

**Objective:** Как пользователь, я хочу фильтровать передачи по жанру (Все / Кино / Спорт / Новости и т. д.), чтобы быстро найти контент нужного типа.

#### Acceptance Criteria

1. The EPG Category Filter shall wrap the existing `GenreTabs` atom, passing the list of available categories from EPG window data.
2. The EPG Category Filter shall, on tab selection, apply a client-side filter on programmes (matching `EpgProgram.category`) without re-fetching from the network.
3. The EPG Category Filter edge-fade overlays (left / right) shall be implemented using `Stack + Positioned + DecoratedBox(LinearGradient)` only — `ShaderMask` is forbidden.
4. The EPG Category Filter shall not modify the `GenreTabs` atom itself.
5. The EPG Category Filter shall expose `Key('epg-category-filter')`.

### Requirement 9: D-pad focus navigation

**Objective:** Как пользователь TV-пульта, я хочу перемещаться по сетке стрелками без касания экрана, и при этом фокус всегда виден в кадре.

#### Acceptance Criteria

1. The EPG Focus Controller shall handle D-pad ← → events to step focus across programme cells along the time axis within the currently focused channel row.
2. The EPG Focus Controller shall handle D-pad ↑ ↓ events to move focus between channel rows; on row change the column shall snap to the live (`isNow`) programme index of the new row, or fall back to the temporally nearest programme if no live programme exists.
3. The EPG Focus Controller shall handle the OK button to either open the programme detail (if focused on a non-live cell) or switch the player to the focused channel (if focused on a live cell). The handler shall not break the player route.
4. The EPG Focus Controller shall keep the focused cell within the viewport with at least 80 logical px of padding from any visible edge — auto-scrolling the relevant `ScrollController`(s) when the focused cell would otherwise leave the viewport.
5. The EPG Focus Controller shall debounce heavy operations (e.g., preview-strip update, network preview, hero refresh) to 400 ms after the focus stabilises, per `flutter-tv-perf.md` Leanback rules. Synchronous focus changes (cell highlight / scale) must be immediate.
6. The EPG Focus Controller shall guard async actions with an `_inFlight` flag so rapid OK presses do not produce overlapping channel-switch / detail-open requests.

### Requirement 10: Preview strip

**Objective:** Как пользователь, я хочу видеть снизу подробности про передачу, на которой стоит фокус — обложку, описание, действия — чтобы решить, переключаться ли на канал.

#### Acceptance Criteria

1. The Preview Strip shall be sticky at the bottom edge and render a 132×76 thumbnail (via `Poster` atom or `Image.network`), programme title, subtitle (channel name + start–end time), and at least one action button (`MvButton.primary` «Смотреть» when live, `MvButton.secondary` «Подробнее» otherwise).
2. The Preview Strip thumbnail shall be wrapped in a `RepaintBoundary` so its image-load shimmer does not invalidate the rest of the screen.
3. The Preview Strip shall update only on stabilised focus (Req 9.5 — 400 ms debounce); it shall not flicker on rapid arrow-key navigation.
4. The Preview Strip shall not use `BackdropFilter`, `ShaderMask`, or `BoxShadow.blurRadius > kSafeShadowBlurMax`.
5. The Preview Strip shall expose `Key('epg-preview-strip')`.

### Requirement 11: Data layer extension — `EpgRepository` and `epgWindowProvider`

**Objective:** Как разработчик, я хочу новый batch-метод для загрузки передач сразу по N каналам в окне `[from..to]`, чтобы не делать N-fan-out сетевых запросов на каждом скролле — при этом существующая player-overlay EPG-логика остаётся неизменной.

#### Acceptance Criteria

1. The EPG screen MAY extend `lib/core/epg/*` to support batch programme queries; existing player-overlay EPG provider invariants (`currentProgramProvider`, `upcomingProgramsProvider` in `lib/core/providers/providers.dart`) shall be preserved unchanged.
2. The Module shall provide a public class `EpgRepository` in `lib/core/epg/epg_repository.dart` with an instance method `Future<Map<int, List<EpgProgram>>> programmesInWindow(DateTime from, DateTime to, List<int> channelIds)`.
3. The Module shall expose `epgWindowProvider` (Riverpod `FutureProvider.family`) keyed by `(from, to, channelIds-hash)` in `lib/core/epg/epg_window_provider.dart` returning the same shape.
4. The Module shall cache successful window-fetches with a TTL of 60 seconds in-memory (per spec key) so two near-simultaneous requests for the same window do not double-fetch.
5. If the backend lacks a batch endpoint, the Module shall fall back to a client-side N-fan-out using existing `ApiClient.getUpcomingPrograms` per channel, with in-flight de-duplication so two concurrent calls for the same `channelId` share a single Future.
6. If a batch endpoint is added, the Module MAY add exactly one new method `Future<Map<int, List<EpgProgram>>> getEpgWindow(...)` to `lib/core/api/api_client.dart`. No existing methods shall be renamed, removed, or signature-changed.
7. The Module shall not modify `EpgProgram` model in `lib/core/playlist/models/epg_program.dart`.
8. After this spec lands, running the existing player-overlay `epg_overlay.dart` shall behave identically to the pre-spec baseline (per regression test, Req 13.4).

### Requirement 12: Sealed UI state + single transition point

**Objective:** Как разработчик, я хочу один `_transition` метод и sealed `EpgUiState`, чтобы исключить race-условия между загрузкой, day-switch и фокус-debounce — по правилам `flutter-tv-perf.md` (sealed state-machine pattern).

#### Acceptance Criteria

1. The EPG screen state shall be modelled by a sealed class `EpgUiState` with at least three variants: `EpgLoadingState`, `EpgReadyState({channels, programmes, focusedCellId, ...})`, `EpgErrorState({error, stackTrace})`.
2. State mutations shall be performed exclusively through a single `_transition(EpgUiState newState)` method that cancels any pending timers before `setState`.
3. Async operations shall be guarded with an `_inFlight` boolean to prevent re-entry (Req 9.6).
4. The state class shall be exhaustively covered by `switch` (Dart 3 sealed exhaustiveness) at every consumption site.

### Requirement 13: Performance compliance — `flutter-tv-perf.md`

**Objective:** Как пользователь rtd2851a TV-бокса, я хочу плавный 60 fps при скролле сетки и в idle, без фризов первого взаимодействия.

#### Acceptance Criteria

1. The EPG Screen Module shall not use `BackdropFilter`, `ShaderMask`, or `ImageFilter.blur` anywhere in `lib/features/epg/`. (`grep -rE "BackdropFilter|ShaderMask|ImageFilter\.blur" lib/features/epg/` → 0 hits.)
2. The EPG Screen Module shall not declare any `BoxShadow.blurRadius > kSafeShadowBlurMax`. (`grep -rE "blurRadius:\s*([2-9][0-9]+|1[3-9])" lib/features/epg/` → 0 hits.)
3. The EPG Screen Module shall use `AnimatedScale` (not `AnimatedContainer.width` / `.height`) for any focus-driven dimensional emphasis.
4. Stream / provider consumers (NOW marker tick, live-programme tick, current-time minute tick) shall be isolated in private `ConsumerWidget` / `StatefulWidget` classes wrapped in `RepaintBoundary` and instantiated via `const` constructors from the parent.
5. Both the channel rail vertical `ListView` and the time-grid horizontal `ListView` instances shall use `cacheExtent: 1500`, `addAutomaticKeepAlives: true`, `addRepaintBoundaries: true`, `clipBehavior: Clip.none`.
6. Manual VM Service measurement on rtd2851a shall record `avg GPURasterizer::Draw ≤ 16.7 ms` during scroll along both axes; idle BUILD events ≤ 5 / 30 sec.
7. Heavy preview-strip updates shall be debounced to 400 ms (Leanback `lb_card_selected_animation_delay`).

### Requirement 14: Backward compatibility, testability and entry-point hygiene

**Objective:** Как ответственный за регрессию, я хочу гарантию, что closed специй не сломаются, и каждое новое API/виджет покрыт тестами.

#### Acceptance Criteria

1. After this spec lands, all 94 baseline tests (per `home-cinematic-redesign` Req 12.4) plus all subsequent additions shall remain green.
2. The EPG Screen Module shall provide widget tests for every new widget class with a stable `Key`, asserting at minimum: key found, no `BackdropFilter`, no `ShaderMask`, no `BoxShadow.blurRadius > kSafeShadowBlurMax` in subtree.
3. The EPG Screen Module shall provide a smoke test for `EpgScreen` that pumps it inside `ProviderScope` + `MaterialApp` with mocked `epgWindowProvider`, asserting `Key('epg-screen-root')` is present.
4. The EPG Screen Module shall provide an explicit regression test that exercises `currentProgramProvider` / `upcomingProgramsProvider` (the player-overlay path) and asserts behaviour identical to the pre-spec baseline (Req 11.8 enforcement).
5. The EPG Screen Module shall not add any new package to `pubspec.yaml`.
6. `flutter analyze megav_iptv/lib/features/epg/ megav_iptv/lib/core/epg/` shall report 0 issues.
7. The router file modification shall be limited to a single new route entry; existing routes shall not be modified.
