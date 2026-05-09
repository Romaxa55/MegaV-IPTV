# Requirements — player-cinematic-redesign

## Введение

Текущий `lib/features/player/player_screen.dart` (≈481 строка) реализует кинематографический плеер на закрытом sealed `PlayerUiState` (см. спек `player-overlay-state-machine`, GO). Визуально UI собран как набор overlay'ов: top OSD, bottom info, sidebar каналов через `ChannelsSidebar`, плюс overlay-листы (`epg / info / similar`). Пользователь явно потребовал убрать «кнопочную панель» и поставить вниз **плитку 5 каналов 16:9** с лого, прогрессом и live-метаданными, чтобы переключение шло **в одно нажатие OK**, без открытия sidebar.

Этот спек переписывает **только рендер** в режиме `ControlsState` — добавляет channel deck, inline EPG strip, glass-panel controls на базе `SafePill`, brief OSD с кинотипографикой, MvTrack progress, MvIconButton seek/play, и ken-burns подложку. **State-машина не трогается**: sealed `PlayerUiState`, `_transition()`, `_stateExpiryTimer`, `_quickSwitchInFlight`, и весь набор существующих 5 вариантов состояния остаются неизменными.

Спек принадлежит Wave 1 redesign-цикла 2026 (см. `roadmap.md`). Foundation-зависимости (`design-system-foundation`, `perf-safe-widgets`, `design-system-atoms`) закрыты со статусом GO; этот спек **обязан** использовать их API и **не имеет права** дублировать токены/виджеты внутри `lib/features/player/`. Все perf-правила из `flutter-tv-perf.md` обязательны.

## Boundary Context

### In-scope (что меняется)

- **Render expansion в `ControlsState`** внутри `PlayerScreen._buildControls()` (или эквивалентный приватный helper) — без изменения сигнатуры `PlayerUiState`.
- **Новые виджеты** под `lib/features/player/cinematic/`:
  - `cinematic_top_bar.dart` — back button + brand chip + LIVE chip + program title + bitrate.
  - `cinematic_bottom_panel.dart` — glass-panel-обёртка вокруг inline EPG bar + action row + remote hint.
  - `inline_epg_bar.dart` — start/now/end timestamps + live progress (на базе `MvTrack`).
  - `channel_deck.dart` — вертикальная/горизонтальная плитка 5 каналов с poster 16:9, лого, программой, прогрессом.
  - `ken_burns_backdrop.dart` — медленный slow-zoom over fallback image (GPU-only `Transform.scale`).
- Расширение `_buildControls()` чтобы дёргать новые виджеты вместо текущих `player_bottom_info.dart` и `_PlayerOsd`.
- Импорты атомов: `MvTrack`, `MvIconButton`, `RemoteHint`, `Brand`, `Chip`, `Poster`, `MegaVTextStyles`, `SafePill`, `SafeFocusRing`, `ComputedColors`, `AppRadius`, `combinedHeroGradient`.

### Out-of-scope (что строго не трогается)

- **Sealed `PlayerUiState`** — никаких новых state-вариантов, никаких новых полей в существующих вариантах. `HiddenState / ControlsState / BriefOsdState / SwitchPreviewState / OverlayState` остаются по 1-в-1.
- **`_transition(PlayerUiState newState)`** — atomic mutation point; сигнатура и тело не модифицируются.
- **`_stateExpiryTimer`** — single-timer invariant сохраняется.
- **`_quickSwitchInFlight`** re-entry guard — не трогать.
- **Native player engines** (`lib/core/player/*`) — read-only.
- **Backend / API / EPG data layer** (`lib/core/api/*`, `lib/core/epg/*`) — read-only; данные для inline-EPG берутся через существующие провайдеры.
- **Mobile player UI** (`mobile-adaptive-layout`, issue #12) — out of boundary.
- **`channels_sidebar.dart` overlay** через клавишу L — остаётся как есть для обратной совместимости (overlay-режим `OverlayState.channels` использует тот же data source, рендер мигрируется на `ChannelDeck`).

### Boundary invariants (ровно те, что в `spec.json`)

1. PlayerUiState sealed type is read-only — no new variants, no field mutations.
2. `_transition(PlayerUiState)` atomic mutation point preserved.
3. `_stateExpiryTimer` single-timer invariant preserved.
4. `_quickSwitchInFlight` guard preserved.
5. Native player engines (`lib/core/player/*`) unchanged.
6. All 30+ existing tests in `megav_iptv/test/` continue passing without modification.

## Requirements

### Requirement 1 — Cinematic top bar при ControlsState

**User Story:** Как пользователь TV-плеера, я хочу видеть в верхней части экрана названия канала, программы, и live-индикатор, чтобы понимать что играет сейчас, без визуального шума.

#### Acceptance Criteria (EARS)

1. WHEN player находится в `ControlsState` THEN система SHALL рендерить top-bar с компонентами: back button (`MvIconButton`), brand chip (`Brand`), LIVE chip (`Chip` variant=live), program title (`MegaVTextStyles.titleM`), bitrate badge.
2. WHEN player НЕ находится в `ControlsState` (`HiddenState`, `BriefOsdState`, `SwitchPreviewState`) THEN top-bar SHALL быть скрыт через `Visibility(visible: false, maintainState: false)` для исключения rebuild.
3. WHILE top-bar видим THE program title SHALL обрезаться через `TextOverflow.ellipsis` и не превышать `maxLines: 1`.
4. WHERE доступна метрика битрейта THE bitrate badge SHALL показывать значение в формате `1080p · 4.2 Mbps`; иначе SHALL быть скрыт.

### Requirement 2 — Inline EPG progress strip

**User Story:** Как пользователь, я хочу видеть прогресс текущей программы (start / now / end + bar), чтобы понимать сколько осталось до конца передачи без открытия full EPG.

#### Acceptance Criteria

1. WHEN `ControlsState` активен AND текущий канал имеет EPG-данные THEN система SHALL рендерить inline EPG strip с timestamps (`HH:MM` start, `HH:MM` now, `HH:MM` end) и progress bar на базе `MvTrack`.
2. WHEN EPG-данные отсутствуют (`epg == null`) THEN inline strip SHALL показывать placeholder "Программа не загружена" в `MegaVTextStyles.bodyS` и `MvTrack.value = 0`.
3. WHILE strip видим THE progress fill SHALL обновляться раз в секунду через изолированный `StreamBuilder` или `Ticker`, обёрнутый в `RepaintBoundary` чтобы не ребилдить parent.
4. THE timestamps SHALL быть выровнены: start — left, now — center, end — right.

### Requirement 3 — Glass-panel controls на базе SafePill

**User Story:** Как пользователь, я хочу glass-look нижней панели управления, но без TV-бокс лагов от backdrop blur.

#### Acceptance Criteria

1. WHEN bottom panel рендерится THEN система SHALL использовать `SafePill` (опаковый tint, 0% blur) вместо CSS-эквивалента `backdrop-filter: blur(20px)`.
2. THE bottom panel SHALL соблюдать `flutter-tv-perf.md` правило #3 (опаковый tint over video Texture); никаких `BackdropFilter`, `ShaderMask`, `BoxShadow.blurRadius > 12`.
3. WHERE требуется тёмный fill THE цвет SHALL вычисляться через `ComputedColors.from(palette).panelTint` (или эквивалент из `design-system-foundation`), не hardcoded RGBA.
4. THE panel SHALL иметь `AppRadius.l` радиус углов и vertical padding `16dp` (использовать `.h` на use-site).

### Requirement 4 — Action row с MvIconButton

**User Story:** Как пользователь, я хочу D-pad-доступную линейку действий (Play/Pause, Audio, Subs, Info, Channels), чтобы быстро переключать модальные overlay'ы.

#### Acceptance Criteria

1. THE action row SHALL содержать кнопки: `Play/Pause`, `Audio`, `Subs`, `Info`, `Channels deck toggle`, реализованные через `MvIconButton`.
2. WHEN пользователь нажимает OK на `Info / Audio / Subs` THEN система SHALL вызывать **существующий** helper переключения overlay (например `_toggleOverlayKey(OverlayKey.info)`), который под капотом вызывает `_transition(OverlayState(...))`.
3. WHEN пользователь нажимает OK на `Channels deck toggle` THEN focus SHALL перейти на channel deck (Req 5) без вызова `_transition` — visibility deck'а управляется через `ControlsState` extra rendering, не state-machine.
4. WHILE focus на любой кнопке action row THE focus ring SHALL рендериться через `SafeFocusRing` (правило #5 perf-safe).
5. THE action row SHALL поддерживать D-pad navigation: ←→ перемещают focus между кнопками; ↑ переходит в EPG strip / top-bar; ↓ выходит из panel (focus вне controls).

### Requirement 5 — Channel deck с 5 каналами 16:9

**User Story:** Как пользователь, я хочу видеть плитку 5 других каналов с poster 16:9, лого, программой и live-progress, чтобы переключиться одним нажатием OK без открытия full sidebar.

#### Acceptance Criteria

1. WHEN focus передан на channel deck (через action button или ⬇ из EPG bar) THEN система SHALL рендерить 5 channel-карточек, каждая содержащая: 16:9 thumbnail (`Poster` aspect=16:9), channel logo (`MmLogo`), program title, remaining time, live progress bar (`MvTrack`).
2. THE deck SHALL быть позиционирован справа и slide-in через `Transform.translate` (GPU-only); CSS-эквивалент `transform: translateX(0%)` имплементируется как Flutter `AnimatedSlide(offset: deckOpen ? Offset.zero : Offset(1, 0), duration: 250ms, curve: Curves.fastOutSlowIn)`.
3. WHEN пользователь нажимает OK на channel-карточке THEN система SHALL вызывать **существующий** trigger `_initiateChannelSwitch(targetChannel)`, который под капотом запускает `_transition(SwitchPreviewState(...))` — НЕ изобретать новый путь.
4. WHILE deck видим THE active card SHALL подсвечиваться через `AnimatedScale(scale: 1.05)` + `SafeFocusRing`, без `AnimatedContainer.width` (правило #3 TL;DR).
5. THE deck list SHALL использовать `ListView.builder` с `cacheExtent: 1500`, `addAutomaticKeepAlives: true`, `addRepaintBoundaries: true`, `clipBehavior: Clip.none`.
6. WHEN deck НЕ открыт THE deck subtree SHALL быть обёрнут в `Visibility(visible: false, maintainState: false)` чтобы исключить build для 5 неактивных карточек.

### Requirement 6 — Brief OSD с кинотипографикой

**User Story:** Как пользователь, я хочу краткий OSD при `BriefOsdState` (3s) с программой, временем и канал-номером, набранный в кинотипографике (Cormorant Garamond italic display + Golos Text body).

#### Acceptance Criteria

1. WHEN player находится в `BriefOsdState` THEN система SHALL рендерить компактный OSD с channel number (`MegaVTextStyles.displayItalicM`), program title (`MegaVTextStyles.titleS`), и `now` time.
2. THE OSD SHALL автоматически скрыться через 3000ms (Leanback `lb_playback_controls_show_time_ms`) — таймаут управляется существующим `_stateExpiryTimer`, новый код не добавляет таймеров.
3. THE OSD SHALL использовать fade-in 250ms и fade-out 325ms через `AnimatedSwitcher` или `AnimatedOpacity` без unmount-fade проблемы (см. правило `flutter-tv-perf.md`).

### Requirement 7 — Ken-burns backdrop fallback

**User Story:** Как пользователь, я хочу видеть медленно-zooming фон (постер канала) когда видео ещё грузится или fallback, чтобы экран не выглядел пустым.

#### Acceptance Criteria

1. WHEN player находится в loading/error state AND video Texture не активен THEN система SHALL рендерить ken-burns backdrop поверх fallback image.
2. THE ken-burns эффект SHALL имплементироваться через `AnimatedBuilder` + `Transform.scale(scale: 1.0 → 1.05)` over 30s, looped через `AnimationController(reverse: true)`.
3. WHEN video Texture становится активен THEN ken-burns backdrop SHALL drop из дерева через `Visibility(visible: false)`, а `AnimationController` SHALL быть `dispose()`'нут или поставлен на `stop()` чтобы не тратить CPU.
4. THE ken-burns SHALL не использовать `Opacity(opacity: <1)`, `BackdropFilter`, `ShaderMask` (правила perf).

### Requirement 8 — RemoteHint в bottom panel

**User Story:** Как пользователь, я хочу всегда видеть hint строку с key-bindings (OK, ⬆⬇, ←→, INFO, BACK), чтобы запоминать D-pad mapping без RTFM.

#### Acceptance Criteria

1. WHEN bottom panel видим THEN система SHALL рендерить `RemoteHint` (atom) внизу панели с актуальными key-bindings для текущего focus context.
2. WHEN focus в action row THE hint SHALL показывать: `OK — выбрать`, `←→ — кнопки`, `↑ — EPG`, `↓ — выйти`.
3. WHEN focus в channel deck THE hint SHALL показывать: `OK — переключить`, `⬆⬇ — каналы`, `← — назад в controls`.

### Requirement 9 — Performance compliance (TV-Mali)

**User Story:** Как разработчик, я хочу гарантию что новый рендер не откатывает perf-достижения закрытых спеков.

#### Acceptance Criteria

1. THE new rendering SHALL NOT использовать `BackdropFilter`, `ShaderMask`, `ImageFilter.blur` нигде в hot-path.
2. THE all `BoxShadow.blurRadius` values SHALL быть ≤ 12 (`kSafeShadowBlurMax` constant).
3. THE focus animations SHALL использовать `Transform.scale` или `AnimatedScale`, НЕ `AnimatedContainer.width`.
4. THE all `StreamBuilder` / `Ticker` подписки SHALL быть изолированы в отдельные `ConsumerWidget` / `StatefulWidget` с `const` ctor у parent'а и `RepaintBoundary` обёрткой (правило #2 TL;DR).
5. WHEN measured через `getVMTimeline` на rtd2851a THE avg `GPURasterizer::Draw` SHALL быть ≤ 16.7 ms при `ControlsState` idle и при channel-deck slide-in.
6. WHEN measured BUILD events count SHALL быть ≤ 5 за 30s idle в `ControlsState`.

### Requirement 10 — PlayerUiState не модифицируется

**User Story:** Как мейнтейнер закрытого спека `player-overlay-state-machine`, я хочу гарантию что новый рендер не вторгается в state-машину.

#### Acceptance Criteria

1. THE player rendering refactor SHALL NOT introduce new state variants in `PlayerUiState`.
2. THE refactor SHALL NOT add or remove fields from `HiddenState`, `ControlsState`, `BriefOsdState`, `SwitchPreviewState`, `OverlayState`.
3. THE refactor SHALL NOT modify the body of `_transition(PlayerUiState newState)` — только вызывать его из новых виджетов через существующие helper-методы (`_toggleOverlayKey`, `_initiateChannelSwitch`, и т.д.).
4. THE refactor SHALL NOT add new `Timer` fields в `_PlayerScreenState`; все timing управляется через `_stateExpiryTimer`.
5. THE refactor SHALL NOT touch `_quickSwitchInFlight` boolean.
6. WHEN audited via `git diff` THE list of modified state-machine identifiers SHALL be empty (verified by reviewer subagent в kiro-review).

### Requirement 11 — Backward compatibility (existing tests)

**User Story:** Как мейнтейнер тестового набора, я хочу гарантию что 30+ существующих тестов в `megav_iptv/test/` продолжают проходить без модификации.

#### Acceptance Criteria

1. THE refactor SHALL NOT modify any test file under `megav_iptv/test/`.
2. THE `transitionForTest` API of `_PlayerScreenState` (или эквивалент) SHALL remain callable with same signature.
3. WHEN running `flutter test` from `megav_iptv/` THEN all existing 30+ tests SHALL pass.
4. THE timings `BriefOsdState = 3000ms` and `SwitchPreviewState = 1500ms` SHALL be preserved.

### Requirement 12 — Foundation reuse (no duplication)

**User Story:** Как мейнтейнер foundation-спеков, я хочу гарантию что новый код использует foundation API, не дублирует токены.

#### Acceptance Criteria

1. THE new code SHALL import `MvTrack`, `MvIconButton`, `RemoteHint`, `Brand`, `Chip`, `Poster`, `MmLogo` из `lib/core/ui/atoms/` и НЕ создавать локальные альтернативы.
2. THE new code SHALL import `SafePill`, `SafeFocusRing`, `SafeBackdrop` из `lib/core/perf/perf_safe_widgets.dart`.
3. THE new code SHALL импортировать палитру через `ref.watch(palettеProvider)` или эквивалент из `design-system-foundation`, НЕ hardcode цветов.
4. THE new code SHALL использовать `MegaVTextStyles` для всех текстовых стилей.
5. THE new code SHALL использовать `AppRadius.s/m/l/xl` для всех corner-radius значений.

### Requirement 13 — Testability of new widgets

**User Story:** Как разработчик, я хочу widget-тесты на новые cinematic-виджеты, чтобы регрессии ловились автоматически.

#### Acceptance Criteria

1. EACH new widget under `lib/features/player/cinematic/` SHALL иметь golden test или widget test в `megav_iptv/test/features/player/cinematic/`.
2. THE channel deck SHALL иметь test, проверяющий что нажатие OK на карточке вызывает `onChannelSelected` callback с правильным channel ID.
3. THE inline EPG bar SHALL иметь test, проверяющий что progress fill соответствует `(now - start) / (end - start)`.
4. THE ken-burns backdrop SHALL иметь test, проверяющий что `AnimationController` останавливается когда widget выходит из дерева.

### Requirement 14 — D-pad navigation graph

**User Story:** Как пользователь TV-пульта, я хочу предсказуемую D-pad навигацию между top-bar / EPG strip / action row / channel deck.

#### Acceptance Criteria

1. THE focus traversal SHALL быть deterministic: top-bar back ⇄ action row ⇄ channel deck (когда открыт) ⇄ EPG strip.
2. WHEN focus в action row AND user presses ↑ THEN focus SHALL move to inline EPG bar (или top-bar, если EPG скрыт).
3. WHEN focus в channel deck AND user presses ← THEN focus SHALL return to last-focused action button.
4. WHEN focus в top-bar AND user presses BACK THEN system SHALL вызывать существующий `Navigator.pop()` или эквивалент — без модификации route layer.
5. THE navigation SHALL использовать Flutter `FocusTraversalGroup` + `FocusNode`, НЕ ручное keyboard listener'ом (если возможно).
