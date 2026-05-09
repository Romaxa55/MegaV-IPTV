# Requirements Document

## Introduction

`PlayerScreen` (`lib/features/player/player_screen.dart`) сейчас управляет видимостью UI поверх видео через **5 разрозненных state-полей** (3 boolean, 1 enum, 1 nullable) и **3 независимых таймера**. Это даёт логически 80 формальных комбинаций при ~5 валидных, и поведение зависит от порядка срабатывания таймеров до микросекунды. Оператор сообщает «намудрено с overlay'ями».

Performance baseline (VM Service trace на rtd2851a TV-боксе, 16.5 sec):
- avg 12.2 ms/frame raster (60+ fps), 12 of 417 frames over 16.7 ms — **достаточно**.
- ~50 BUILD-событий за 30 секунд idle — **избыточно**, ребилд всего Stack по тику `StreamBuilder<PlayerState>`.

Этот спек **не оптимизирует производительность видео-плеера** — она и так в норме. Спек устраняет **архитектурную сложность** через единый sealed `PlayerUiState` + один таймер expiry + RepaintBoundary вокруг loading/error индикатора. Цель — детерминированное, предсказуемое поведение overlay'ев при работе пультом.

Native player engines (`lib/core/player/`) и внутренности 6 overlay-виджетов остаются нетронутыми. Их публичные контракты сохраняются.

## Boundary Context

- **In scope**:
  - `_PlayerScreenState` в `lib/features/player/player_screen.dart`: state-fields, timers, transition logic, build composition.
  - Новый `sealed class PlayerUiState` (или иерархия) — единый source of truth для видимости UI.
  - Новый внутренний sub-widget для `StreamBuilder<PlayerState>` с `RepaintBoundary`.
  - Quick-switch race-fix в `_quickSwitch()`.
  - Юнит-тесты transition-таблицы и widget-тесты основных сценариев.

- **Out of scope**:
  - Native player engines (`media3_engine`, `media_kit_engine`, `native_video_player_engine`, `player_engine`, `player_manager`, `decoder_config`).
  - Внутренности 6 overlay-виджетов (`PlayerControlsOverlay`, `PlayerBottomInfo`, `EpgOverlay`, `ChannelsSidebar`, `InfoOverlay`, `SimilarOverlay`) — их публичные API сохраняются, тела не правятся.
  - Модели каналов и EPG.
  - Riverpod-провайдеры (`currentChannelProvider`, `currentChannelIndexProvider`, `apiClientProvider`, `decoderConfigProvider`) — read-only.
  - HDR / DRM / 4K / зелёные полосы / network buffering — не входят.
  - Дизайн / визуальное оформление overlay'ев (только видимость и timing).

- **Adjacent expectations**:
  - `_playerManager.activeEngine.buildVideoWidget(...)` остаётся как сейчас.
  - `PlayerOverlayMode` enum (определён в `widgets/player_overlay.dart`) сохраняется и используется внутри одного из вариантов sealed `PlayerUiState`.
  - Сетка на главном экране (закрытые спеки `home-grid-optimization`, `home-grid-visual-polish`) — не затрагивается.

## Requirements

### Requirement 1: Единый источник истины для видимости UI

**Objective:** Как разработчик, поддерживающий `PlayerScreen`, я хочу единственное поле с явно перечисленными валидными состояниями вместо пяти разрозненных флагов, чтобы любая правка не ломала комбинации и невалидное состояние было невозможно представить в коде.

#### Acceptance Criteria

1. The PlayerScreen shall hold exactly one field representing the current UI visibility state, replacing all of `_showControls`, `_showBriefOSD`, `_overlay`, and `_switchPreview`.
2. The PlayerScreen shall define a sealed type listing all valid UI visibility states, each variant carrying exactly the data required for that state (e.g., expiry deadline, preview channel, overlay mode).
3. While the PlayerScreen is rendered, every code path that needs to know whether any UI is visible shall consult only the single state field — no derived booleans, no orthogonal flags.
4. While the PlayerScreen builds its widget tree, the build logic shall dispatch on the single state field via a switch (or equivalent exhaustive pattern), and the dispatch shall be exhaustive over all variants.
5. If a code path attempts to set the state field to a value not allowed by the sealed type, the change shall fail at compile time.

### Requirement 2: Один центральный таймер expiry

**Objective:** Как пользователь TV, я хочу, чтобы overlay'и появлялись и исчезали по предсказуемым правилам без race-условий, чтобы мне не казалось, что плеер «живёт своей жизнью».

#### Acceptance Criteria

1. The PlayerScreen shall hold at most one active expiry timer at any moment.
2. When the PlayerScreen transitions into a new UI visibility state, the PlayerScreen shall first cancel any previously active expiry timer before scheduling the new one.
3. While the PlayerScreen is in a UI visibility state that has a defined expiry duration (such as the auto-hide controls state, the brief OSD state, or the switch-preview state), the PlayerScreen shall transition to the hidden state automatically when that duration elapses.
4. While the PlayerScreen is in a state without an expiry duration (such as a fully-shown overlay like EPG or channels sidebar), the PlayerScreen shall not schedule any expiry timer.
5. When the PlayerScreen is disposed, the PlayerScreen shall cancel any active expiry timer.

### Requirement 3: Атомарный переход состояния

**Objective:** Как пользователь, я хочу, чтобы быстрые повторные нажатия (например, переключение каналов ⬆⬆⬆) не приводили к артефактам — не «застревал» preview предыдущего канала, не накладывались эффекты.

#### Acceptance Criteria

1. The PlayerScreen shall expose exactly one private method that mutates the UI visibility state, and all internal callers (key handlers, taps, timers, channel-open completions) shall route their state changes through that method.
2. When the PlayerScreen mutates the UI visibility state, the cancellation of the previous expiry timer, the assignment of the new state, and the scheduling of the new expiry timer (if any) shall happen within the same synchronous setState body, with no awaited operations between them.
3. When the user presses the quick-switch key (channel up or channel down) while a switch-preview is already pending, the PlayerScreen shall cancel the pending switch and start a new switch-preview based on the just-pending preview channel as the new origin.
4. When the user presses the quick-switch key three times in rapid succession (faster than the switch debounce), only one channel change shall ultimately be committed, and that channel shall be the third target.
5. While a switch-preview is being committed (the deferred channel change is firing), the PlayerScreen shall not start a new fetch for any new quick-switch input until the previous commit has either completed or been cancelled.

### Requirement 4: Идемпотентное и понятное поведение в основных сценариях

**Objective:** Как пользователь, я хочу, чтобы основные действия в плеере давали ровно тот эффект, который ожидается, и были одинаковыми каждый раз.

#### Acceptance Criteria

1. When the PlayerScreen opens for a channel, the PlayerScreen shall display the brief OSD (showing channel info) for approximately 3 seconds and then transition to the hidden state if no input occurred.
2. When the user presses any key while in the hidden state, the PlayerScreen shall display the controls overlay for approximately 4 seconds and then transition to the hidden state if no further input occurred.
3. When the user presses E (or its equivalent), I, L, or R while no overlay is shown, the PlayerScreen shall display the corresponding full overlay (EPG, Info, Channels, Similar) and shall not auto-hide it.
4. When the user presses the same overlay-toggle key while that overlay is already shown, the PlayerScreen shall hide the overlay and transition to the hidden state.
5. When the user presses BACK or ESC while an overlay is shown, the PlayerScreen shall hide that overlay and transition to the hidden state, consuming the key event.
6. When the user presses BACK or ESC while no overlay is shown, the PlayerScreen shall not consume the key event (allowing the system back action to pop the screen).
7. When the user presses channel-up or channel-down while no overlay is shown, the PlayerScreen shall enter the switch-preview state showing the next or previous channel for approximately 1.5 seconds and then commit the change.
8. When the user taps anywhere on the player while an overlay is shown, the PlayerScreen shall hide that overlay.
9. When the user taps anywhere on the player while no overlay is shown, the PlayerScreen shall display the controls overlay (re-arming the auto-hide).

### Requirement 5: Изолированный rebuild loading/error индикатора

**Objective:** Как разработчик, я хочу, чтобы тик стрима состояния плеера не вызывал ребилд всего экрана плеера — только маленького индикатора, который реально зависит от стрима.

#### Acceptance Criteria

1. The PlayerScreen shall isolate the StreamBuilder consuming the player engine state stream into its own widget subtree separate from the main Stack composition.
2. The PlayerScreen shall wrap that isolated subtree in a RepaintBoundary so that paint invalidations in it do not propagate to the video texture or to the overlay layers above.
3. While the player engine state stream emits values without a change in UI visibility state, the PlayerScreen body (the outer Stack and its non-stream children) shall not rebuild.
4. While the PlayerScreen is rendered idle on the reference TV device with no input from the user, the number of build events for the PlayerScreen body shall not exceed approximately 5 over a 30-second observation window (compared to the baseline of approximately 50 events in the same window before this change).

### Requirement 6: Тестируемость state-машины

**Objective:** Как разработчик, я хочу, чтобы переходы состояний были покрыты автотестами, чтобы регрессии в этой логике ловились до runtime.

#### Acceptance Criteria

1. The PlayerScreen shall expose its state-mutation method (or a thin wrapper around it) at a level that allows widget-test code to invoke transitions deterministically without manipulating Timer.
2. The project shall include unit tests asserting at least the following transitions: hidden → controls (on key press), controls → hidden (on timer), hidden → briefOsd (on channel open), briefOsd → hidden (on timer), hidden → overlay (on overlay-toggle key), overlay → hidden (on same overlay-toggle key), overlay → hidden (on BACK), hidden → switchPreview (on channel-up/down), switchPreview → channel-changed → briefOsd (on commit timer).
3. The project shall include widget tests asserting at least three integration scenarios: open the player and observe controls auto-hide, press a quick-switch key and observe the channel change after the debounce, press the EPG key and observe the EPG overlay become visible.
4. While the regression test suite is run, all 21 existing tests in `test/` shall continue to pass without modification.

### Requirement 7: Совместимость и регрессионная безопасность

**Objective:** Как пользователь, я хочу, чтобы рефакторинг не сломал ни одну существующую функцию плеера.

#### Acceptance Criteria

1. The PlayerScreen shall preserve the existing public route at `/player`, the existing constructor signature `PlayerScreen({Key? key})`, and the existing dependency on `currentChannelProvider`.
2. The PlayerScreen shall continue to invoke `_playerManager.activeEngine.buildVideoWidget(fit: BoxFit.contain)` (or the existing `Media3` initial path for `_openedViaMedia3`) without changes to the way the video widget is mounted.
3. The PlayerScreen shall preserve all currently supported key bindings: ESC and goBack, ENTER/SELECT and game button A and media play/pause/play/pause keys, channel-up family (arrowUp, channelUp, pageUp, mediaTrackPrevious), channel-down family (arrowDown, channelDown, pageDown, mediaTrackNext), arrowLeft/Right (currently absorbed when no overlay), E, I, L, R.
4. The PlayerScreen shall preserve the system UI mode change (`SystemUiMode.immersiveSticky` on enter, `SystemUiMode.edgeToEdge` on exit).
5. The PlayerScreen shall preserve the existing focus behavior — the player root focus node receives focus after the first frame.

### Requirement 8: Производительность остаётся в бюджете

**Objective:** Как пользователь TV, я хочу, чтобы рефакторинг не сделал плеер медленнее.

#### Acceptance Criteria

1. While the user opens the player and waits idle for 10 seconds on the reference TV device, the GPU thread average frame time recorded via VM Service timeline shall remain at or below 16.7 milliseconds.
2. While the user presses a quick-switch key on the reference TV device, the time between the key press and the visible appearance of the switch-preview shall not exceed 100 milliseconds, as observed in operator acceptance.
3. While the user toggles an overlay (E, I, L, R) on the reference TV device, the time between the key press and the overlay being fully visible shall not exceed 200 milliseconds, as observed in operator acceptance.
4. The reference test for the success of these performance criteria shall be a VM Service timeline capture (via `curl http://127.0.0.1:NNNNN/TOKEN/getVMTimeline`) plus subjective operator acceptance on the reference TV device.
