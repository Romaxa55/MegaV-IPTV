# Tasks — player-cinematic-redesign

Implementation tasks for the cinematic render refactor inside `ControlsState`. **Boundary annotations** point at owner specs; tasks marked `_Boundary: read-only_` may not modify those identifiers.

Foundation dependencies (all closed, status GO):
- `design-system-foundation` — palettes, typography, radii.
- `perf-safe-widgets` — `SafePill`, `SafeFocusRing`, `SafeBackdrop`, `ComputedColors`, `kSafeShadowBlurMax`.
- `design-system-atoms` — `MvTrack`, `MvIconButton`, `RemoteHint`, `Brand`, `Chip`, `Poster`, `MmLogo`.
- `player-overlay-state-machine` — sealed `PlayerUiState`, `_transition`, `_stateExpiryTimer`, `_quickSwitchInFlight`. **Read-only**.

---

## Phase 0 — Boundary sanity

### Task 0.1 — Document and assert PlayerUiState invariants

- [x] 0.1 Зафиксировать read-only-список идентификаторов из `player-overlay-state-machine` и проверить, что текущий `player_screen.dart` всё ещё их экспонирует.
  - Скан-grep на `sealed class PlayerUiState`, `_transition`, `_stateExpiryTimer`, `_quickSwitchInFlight`, `transitionForTest`. Зафиксировать SHA / line numbers в commit message первого PR.
  - Запустить `cd megav_iptv && flutter test` — baseline должен быть зелёный до начала работ.
  - Создать локальный artefact `.kiro/specs/player-cinematic-redesign/baseline-identifiers.txt` со списком (для последующей проверки в kiro-review).
  - _Boundary:_ read-only of `player-overlay-state-machine`.
  - _Requirements: Req 10, Req 11._

### Task 0.2 — Verify view-data providers exist (added during cross-spec review)

- [x] 0.2 Проверить наличие view-data providers, которые будет использовать render tree (из design.md §Data Models).
  - Список providers (REQUIRED): `currentChannelProvider`, `currentProgramProvider`, `adjacentChannelsProvider`, `playerBitrateLabelProvider`, `isPlayingProvider`, `hasActiveTextureProvider`.
  - Прогнать `grep -rn "Provider<\|StateProvider<\|StreamProvider<" megav_iptv/lib/core/providers/providers.dart megav_iptv/lib/core/playlist/ megav_iptv/lib/core/player/ megav_iptv/lib/core/epg/` и составить inventory: какие из 6 providers уже существуют, под каким именем.
  - Для каждого MISSING provider — добавить как **derived/computed** Provider в `lib/core/providers/providers.dart` (или ближайший подходящий файл foundation/data layer). Пример: `final isPlayingProvider = Provider<bool>((ref) => ref.watch(playerStateProvider).isPlaying);`. **Нельзя** добавлять новый state — только derive из existing.
  - Если provider существует под другим именем — добавить alias `final adjacentChannelsProvider = adjacentNearbyChannelsProvider;` (пример), не переименовывать оригинал.
  - **Запрещено**: модификация `lib/features/player/widgets/` (closed spec ownership), модификация `ControlsState` или sealed `PlayerUiState`, добавление новых state-mutating providers.
  - Наблюдаемое: после task 0.2 все 6 providers доступны через canonical имена; `flutter analyze` чисто; `flutter test` 94/94 (baseline).
  - _Boundary:_ `lib/core/providers/providers.dart` — additive only.
  - _Depends: 0.1._
  - _Requirements: Req 10, Req 12._

---

## Phase 1 — Foundation widgets (new files, no integration yet)

### Task 1.1 — `KenBurnsBackdrop`

- [ ] 1.1 Создать `lib/features/player/cinematic/ken_burns_backdrop.dart`.
  - `StatefulWidget` с `AnimationController(duration: 30s, vsync: this)..repeat(reverse: true)`.
  - `AnimatedBuilder` + `Transform.scale(scale: 1.0 + 0.05 * controller.value)` + `Image(image: imageProvider, fit: BoxFit.cover)`.
  - `Visibility(visible: active, maintainState: false)` обёртка; `didUpdateWidget` вызывает `repeat()` / `stop()`.
  - `dispose()` строго `controller.dispose()`.
  - Никаких `Opacity`, `BackdropFilter`, `ShaderMask`.
  - _Boundary:_ NEW; uses no foundation atoms.
  - _Requirements: Req 7, Req 9.1, Req 9.4._

### Task 1.2 — `InlineEpgBar`

- [ ] 1.2 Создать `lib/features/player/cinematic/inline_epg_bar.dart`.
  - Внешний `ConsumerWidget` принимает `startAt`, `endAt`, `programTitle`.
  - Внутренний `_TickStrip extends StatefulWidget` с `Ticker` (1Hz) обёрнутый в `RepaintBoundary`.
  - Layout: `Center(Text(programTitle ?? 'Программа не загружена'))` сверху + `Row(Text(start) | Expanded(MvTrack(progress)) | Text(end))`.
  - Если `startAt == null || endAt == null` → `MvTrack(value: 0)`.
  - Использовать `MegaVTextStyles.bodyS`.
  - _Boundary:_ NEW; reuses `MvTrack` from `design-system-atoms`.
  - _Requirements: Req 2, Req 9.4, Req 12.1._

### Task 1.3 — `CinematicTopBar`

- [ ] 1.3 Создать `lib/features/player/cinematic/cinematic_top_bar.dart`.
  - Row: `MvIconButton(arrow_back) → Brand → Chip(LIVE) → Expanded(Text title) → Chip(bitrateLabel)`.
  - `bitrateLabel == null` → bitrate Chip скрыт.
  - `programTitle` имеет `maxLines: 1`, `overflow: TextOverflow.ellipsis`.
  - Использовать `MegaVTextStyles.titleM`.
  - Параметр `focusNode` пробрасывается на `MvIconButton`.
  - _Boundary:_ NEW; uses `MvIconButton`, `Brand`, `Chip` from atoms.
  - _Requirements: Req 1, Req 12._

### Task 1.4 — `ChannelDeck` skeleton + slide-in

- [ ] 1.4 Создать `lib/features/player/cinematic/channel_deck.dart` с `_ChannelCard`.
  - `AnimatedSlide(offset: isOpen ? Offset.zero : Offset(1, 0), duration: 250ms, curve: Curves.fastOutSlowIn)`.
  - `Visibility(visible: isOpen || _justClosed, maintainState: false)` с hold-flag для fade-out.
  - `ListView.builder(scrollDirection: Axis.vertical, cacheExtent: 1500, addAutomaticKeepAlives: true, addRepaintBoundaries: true, clipBehavior: Clip.none)`.
  - `_ChannelCard`: `AnimatedScale(1.05 при focus)` + `SafeFocusRing` + `Poster(aspectRatio: 16/9)` + `MmLogo` + `Text(programTitle)` + `Text(remainingTime)` + `MvTrack(progress)`.
  - **НЕ использовать** `AnimatedContainer.width` для focus.
  - `Focus(onKey: ...)` — Enter/Select → `widget.onChannelSelected(channel)`.
  - _Boundary:_ NEW; calls `onChannelSelected` callback, не `_transition` напрямую.
  - _Requirements: Req 5, Req 9.3._

### Task 1.5 — `CinematicBottomPanel` glass wrapper

- [ ] 1.5 Создать `lib/features/player/cinematic/cinematic_bottom_panel.dart`.
  - Outer `SafePill(borderRadius: AppRadius.l, padding: ...)`. Никаких `BackdropFilter`.
  - Tint цвет — `ComputedColors.from(palette).panelTint` (или эквивалент, согласовать с foundation API).
  - Column: `InlineEpgBar` → `_ActionRow` → `RemoteHint`.
  - `_ActionRow` — Row из `MvIconButton`s: PlayPause, Audio, Subs, Info, ChannelsToggle.
  - Каждая кнопка обёрнута в `SafeFocusRing` для фокуса.
  - Параметры callback'ов проброшены наружу.
  - _Boundary:_ NEW; SafePill from `perf-safe-widgets`, RemoteHint/MvIconButton from atoms.
  - _Requirements: Req 3, Req 4, Req 8, Req 9.1, Req 12._

---

## Phase 2 — Widget tests (new files)

### Task 2.1 — `cinematic_top_bar_test`

- [ ] 2.1 Создать `megav_iptv/test/features/player/cinematic/cinematic_top_bar_test.dart`.
  - Test: bitrate chip скрыт при `bitrateLabel == null`.
  - Test: длинный title обрезается через ellipsis.
  - Test: tap на back-кнопке вызывает callback.
  - _Boundary:_ NEW test directory.
  - _Requirements: Req 1, Req 13._

### Task 2.2 — `inline_epg_bar_test`

- [ ] 2.2 Создать `megav_iptv/test/features/player/cinematic/inline_epg_bar_test.dart`.
  - Test: `progress = (now - start) / (end - start)` для известного диапазона.
  - Test: placeholder text при `startAt == null`.
  - Test: ticker корректно diposes при unmount.
  - _Boundary:_ NEW.
  - _Requirements: Req 2, Req 13.3._

### Task 2.3 — `channel_deck_test`

- [ ] 2.3 Создать `megav_iptv/test/features/player/cinematic/channel_deck_test.dart`.
  - Test: 5 карточек видны при `isOpen=true`.
  - Test: OK на focused card → `onChannelSelected(channel)` вызван с правильным Channel.
  - Test: `cacheExtent: 1500`, `clipBehavior: Clip.none`, `addAutomaticKeepAlives: true` set.
  - Test: navigation ← возвращает фокус наружу (через Focus event report).
  - _Boundary:_ NEW.
  - _Requirements: Req 5, Req 13.2, Req 14._

### Task 2.4 — `ken_burns_backdrop_test`

- [ ] 2.4 Создать `megav_iptv/test/features/player/cinematic/ken_burns_backdrop_test.dart`.
  - Test: при `active=false` controller остановлен.
  - Test: при unmount controller `disposed`.
  - Test: при `active=true → false → true` controller корректно перезапускается.
  - _Boundary:_ NEW.
  - _Requirements: Req 7, Req 13.4._

---

## Phase 3 — Integration into PlayerScreen

### Task 3.1 — Add focus nodes to `_PlayerScreenState`

- [ ] 3.1 В `_PlayerScreenState` добавить три новых поля: `_topBarFocus: FocusNode`, `_actionFocusScope: FocusScopeNode`, `_channelDeckFocus: FocusScopeNode`.
  - Initialize в `initState()`.
  - Dispose в существующем `dispose()` (НЕ ломая существующий dispose таймера).
  - Эти поля **не являются** state-machine полями; никаких новых вариантов `PlayerUiState`.
  - _Boundary:_ extend `_PlayerScreenState` only with focus management; do not modify `_state`, `_transition`, `_stateExpiryTimer`, `_quickSwitchInFlight`.
  - _Requirements: Req 10, Req 14.5._

### Task 3.2 — Replace `_buildControls()` body

- [ ] 3.2 Переписать тело `_buildControls()` в `player_screen.dart` по design pseudocode.
  - Stack layers: `_VideoLayer` → `KenBurnsBackdrop` → `_LoadingErrorIndicator` (existing const) → `Align(top, CinematicTopBar)` → `Align(bottom, CinematicBottomPanel)` → `Align(right, ChannelDeck)`.
  - Все callback'ы пробрасываются в существующие helper-методы: `_togglePlayPause`, `_toggleOverlayKey(OverlayKey.x)`, `_initiateChannelSwitch`.
  - **НЕ** добавлять прямых вызовов `_transition()` — только через существующие wrappers.
  - **НЕ** менять сигнатуру `_buildControls()`.
  - _Boundary:_ modify only render body; respects all 6 invariants from spec.json.
  - _Requirements: Req 1, Req 2, Req 3, Req 4, Req 5, Req 7, Req 10.3._

### Task 3.3 — Brief OSD typography upgrade

- [ ] 3.3 В `_buildBriefOsd()` (или эквиваленте для `BriefOsdState`) заменить текстовые стили на `MegaVTextStyles.displayItalicM` (channel number) + `MegaVTextStyles.titleS` (program title).
  - Никаких новых таймеров: `_stateExpiryTimer` уже управляет 3000ms timeout.
  - Использовать `AnimatedSwitcher` (key-based) для fade-in 250ms / fade-out 325ms.
  - _Boundary:_ render-only edit inside existing helper.
  - _Requirements: Req 6._

### Task 3.4 — D-pad navigation graph

- [ ] 3.4 Настроить `FocusTraversalGroup` для top-bar / EPG / action row / channel deck.
  - Action row ↑ → EPG bar (или top-bar, если EPG скрыт).
  - Action row ↓ → выйти из panel (`_clearControlsFocus()` или request focus на video Texture wrapper).
  - Channel deck ← → возврат в action row (через сохранённый `_lastActionFocusNode`).
  - Top-bar BACK → `Navigator.maybePop(context)`.
  - _Boundary:_ pure focus traversal; no state-machine touch.
  - _Requirements: Req 14._

---

## Phase 4 — Compatibility and perf verification

### Task 4.1 — Existing tests regression

- [ ] 4.1 Запустить полный `cd megav_iptv && flutter test` и подтвердить, что все 30+ существующих тестов проходят без модификаций.
  - Если падает хоть один — НЕ модифицировать тест. Откатить изменение в `_buildControls()` и продебажить через `kiro-debug`.
  - Зафиксировать вывод `flutter test` в commit message.
  - _Boundary:_ tests are read-only artefacts of closed specs.
  - _Requirements: Req 11._

### Task 4.2 — Static check: foundation reuse, no hardcoded perf-killers

- [ ] 4.2 Grep `lib/features/player/cinematic/` на запрещённые паттерны.
  - `BackdropFilter` — должно быть 0 occurrences.
  - `ShaderMask` — должно быть 0 occurrences.
  - `ImageFilter.blur` — должно быть 0 occurrences.
  - `BoxShadow.*blurRadius:` — каждое occurrence ≤ 12 (или ≤ `kSafeShadowBlurMax`).
  - `AnimatedContainer.*width:` — должно быть 0 occurrences.
  - `Color(0xFF...)` / hardcoded RGBA — 0 occurrences (использовать палитру через `ref.watch`).
  - Зафиксировать вывод grep в commit.
  - _Boundary:_ enforces flutter-tv-perf.md rules.
  - _Requirements: Req 9, Req 12._

### Task 4.3 — VM Service performance trace

- [ ] 4.3 На rtd2851a в `--profile` сборке снять `getVMTimeline` snapshot для двух сценариев.
  - Сценарий A: `ControlsState` idle, 30s.
  - Сценарий B: open channel deck, scroll between 5 cards, 15s.
  - Парсить и сохранить avg / p95 / max `GPURasterizer::Draw` под `.kiro/specs/player-cinematic-redesign/snapshots/`.
  - Acceptance: avg ≤ 16.7 ms, BUILD events ≤ 5 / 30s в idle.
  - _Boundary:_ measurement only; no code changes.
  - _Requirements: Req 9.5, Req 9.6._

### Task 4.4 — PlayerUiState invariant audit

- [ ] 4.4 Запустить `git diff master -- megav_iptv/lib/features/player/player_screen.dart` и убедиться, что в diff нет:
  - Изменений в `sealed class PlayerUiState`.
  - Изменений в `HiddenState`, `ControlsState`, `BriefOsdState`, `SwitchPreviewState`, `OverlayState`.
  - Изменений в теле `_transition(...)`.
  - Новых `Timer` полей в `_PlayerScreenState`.
  - Изменений в `_quickSwitchInFlight`.
  - Сравнить актуальный список идентификаторов с `baseline-identifiers.txt` (Task 0.1).
  - _Boundary:_ verifies the core invariant.
  - _Requirements: Req 10._

### Task 4.5 — Final regression: full test + smoke run

- [ ] 4.5 Финальная регрессия.
  - `cd megav_iptv && flutter test` — зелёно.
  - `flutter analyze` — без новых warnings.
  - `flutter run -d <rtd2851a>` smoke: открыть плеер, потоптать deck D-pad'ом, переключить канал, открыть info overlay, дождаться brief OSD, подождать ken-burns на loading.
  - Зафиксировать видео/screenshots в `.kiro/specs/player-cinematic-redesign/snapshots/`.
  - _Boundary:_ end-to-end gate.
  - _Requirements: Req 9, Req 11._

---

## Notes for implementer

- **Priority of invariants**: PlayerUiState read-only > test compat > foundation reuse > new visual fidelity. Если возникает конфликт — режь визуальную фичу, не state-машину.
- **No new packages** в `pubspec.yaml`.
- Используй `_focusJustLost` hold-flag паттерн из `flutter-tv-perf.md` для unmount-fade на ChannelDeck.
- Не оптимизируй preemptively — измерь через `getVMTimeline` сначала, потом фикси.
- В первом PR — только Phase 0 + Phase 1 (виджеты в изоляции, без интеграции). Это даёт reviewer узкий surface для review.
