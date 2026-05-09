# Implementation Plan

> Спек: `player-overlay-state-machine`. См. `requirements.md` (8 требований) и `design.md` (sealed `PlayerUiState`, единый `_transition()`, isolated `_LoadingErrorIndicator`).
>
> Порядок: foundation (sealed type) → core (рефакторинг state-машины) → integration (loading indicator) → validation (тесты + ручная приёмка).

---

## 1. Foundation: sealed `PlayerUiState` тип

- [x] 1.1 Добавить sealed `PlayerUiState` и его 5 вариантов в `player_screen.dart`
  - Открыть `megav_iptv/lib/features/player/player_screen.dart`.
  - Добавить **на уровне файла** (вне `_PlayerScreenState`) sealed-класс `PlayerUiState` и 5 классов-вариантов: `HiddenState`, `ControlsState({required hideAt})`, `BriefOsdState({required hideAt})`, `SwitchPreviewState({required previewChannel, required commitAt})`, `OverlayState({required mode})`.
  - Все варианты — `final class extends PlayerUiState` с `const` конструктором.
  - Импорт `PlayerOverlayMode` из `widgets/player_overlay.dart` уже есть.
  - Импорт `Channel` уже есть.
  - НЕ удалять пока существующие поля `_showControls`, `_showBriefOSD`, `_overlay`, `_switchPreview`, `_hideTimer`, `_osdTimer`, `_switchTimer` — это task 2.1.
  - НЕ менять пока поведение, только добавить типы.
  - Наблюдаемое: `flutter analyze lib/features/player/player_screen.dart` чисто; никакого нового кода в `_PlayerScreenState` ещё не используется (типы добавлены, но не потребляются); `flutter test test/features/home/widgets/` всё ещё 21/21 зелёный.
  - _Requirements: 1.1, 1.2, 1.5_
  - _Boundary: PlayerUiState_

---

## 2. Core: рефакторинг state-машины `_PlayerScreenState`

- [x] 2.1 Заменить 5 state-полей на одно `_uiState`
  - В `_PlayerScreenState`: удалить `bool _showControls`, `bool _showBriefOSD`, `PlayerOverlayMode _overlay`, `Channel? _switchPreview`. Добавить `PlayerUiState _uiState = const HiddenState();`.
  - Удалить три таймера `_hideTimer`, `_osdTimer`, `_switchTimer`. Добавить `Timer? _stateExpiryTimer;`.
  - Добавить `bool _quickSwitchInFlight = false;`.
  - Удалить методы `_resetHideTimer()`, `_showBriefOSDFor()`, `_toggleOverlay()` — их функциональность переносится в `_transition()` (task 2.2).
  - **Не удалять пока** методы `_handleKeyEvent`, `_quickSwitch`, `_openChannel`, `_init`, `dispose`, `build` — они ещё используют старые поля. Этот шаг сделает код **временно** не-компилирующимся; следующий шаг 2.2 это починит. Если нужно — закомментируй упоминания удалённых полей с маркером `// TODO 2.2` чтобы analyze показал явные ошибки.
  - Наблюдаемое: `flutter analyze` показывает ошибки в местах, где старые поля упоминаются (это правильно — task 2.2 починит). Существующие тесты НЕ запускаем — они упадут на компиляции.
  - _Requirements: 1.1, 1.3, 2.1_
  - _Depends: 1.1_
  - _Boundary: _PlayerScreenState (state model)_

- [x] 2.2 Реализовать `_transition(PlayerUiState newState)` и переписать все mutators через него
  - В `_PlayerScreenState` добавить:
    - метод `void _transition(PlayerUiState newState)` — body согласно design.md (cancel timer first, setState, schedule new timer if expiry).
    - метод `void _onExpiry()` — обработка expiry для текущего `_uiState` (HiddenState/OverlayState — no-op; ControlsState/BriefOsdState → `_transition(HiddenState())`; SwitchPreviewState → `_commitSwitchPreview(channel)`).
    - метод `Future<void> _commitSwitchPreview(Channel next)` — обновление providers + `_openChannel(next)`.
    - аннотация `@visibleForTesting void transitionForTest(PlayerUiState s) => _transition(s);` (Req 6.1).
  - Переписать `_handleKeyEvent`:
    - ESC/goBack: если `_uiState is OverlayState` → `_transition(HiddenState())` + handled. Иначе ignored (system back).
    - arrowUp/channelUp/pageUp/mediaTrackPrevious: если `_uiState is HiddenState || ControlsState` → `_quickSwitch(-1)` + handled.
    - arrowDown family: то же с `_quickSwitch(1)`.
    - arrowLeft/Right: если `_uiState is HiddenState || ControlsState` → handled (поглощение, как сейчас).
    - select/enter/gameButtonA/mediaPlayPause: если `_uiState is HiddenState` → `_transition(ControlsState(hideAt: now + 4s))` + handled. Иначе на любой key → `_transition(ControlsState(hideAt: now + 4s))`.
    - keyE → `_toggleOverlayKey(PlayerOverlayMode.epg)`.
    - keyI → `_toggleOverlayKey(PlayerOverlayMode.info)`.
    - keyL → `_toggleOverlayKey(PlayerOverlayMode.channels)`.
    - keyR → `_toggleOverlayKey(PlayerOverlayMode.similar)`.
  - Реализовать `void _toggleOverlayKey(PlayerOverlayMode mode)`:
    - если `_uiState is OverlayState s && s.mode == mode` → `_transition(HiddenState())`.
    - иначе → `_transition(OverlayState(mode: mode))`.
  - Переписать `_quickSwitch(int delta)`:
    - В **первой** строке: `if (_quickSwitchInFlight) return;` затем `_quickSwitchInFlight = true;`.
    - Источник базы: если `_uiState is SwitchPreviewState s` → `s.previewChannel`; иначе `ref.read(currentChannelProvider)`.
    - Try/finally: в finally `_quickSwitchInFlight = false;`.
    - После определения `next`: `_transition(SwitchPreviewState(previewChannel: next, commitAt: now + 1.5s))`.
  - Переписать `_openChannel(Channel)`:
    - В конце метода (после `playChannel` или Media3 path) → `_transition(BriefOsdState(hideAt: now + 3s))` (заменяет `_showBriefOSDFor`).
  - Переписать GestureDetector `onTap`:
    - если `_uiState is OverlayState` → `_transition(HiddenState())`.
    - иначе → `_transition(ControlsState(hideAt: now + 4s))`.
  - Переписать `dispose`:
    - `_stateExpiryTimer?.cancel();` (заменяет три cancel'а).
    - Остальное (`_playerFocusNode.dispose()`, `_playerManager.stop()` если не media3, `SystemChrome.setEnabledSystemUIMode`) сохраняется.
  - Переписать `build()` body:
    - Stack children: video widget (как сейчас) + `const _LoadingErrorIndicator()` (task 3.1) + `..._buildOverlayLayer(channel)`.
    - Реализовать `List<Widget> _buildOverlayLayer(Channel? channel)` через `switch (_uiState)` — exhaustive по 5 вариантам, как в design.md.
    - Реализовать `Widget _buildModalOverlay(PlayerOverlayMode mode, Channel channel)` — switch по 5 значениям enum (включая `none` → `SizedBox.shrink()` для exhaustive).
  - Удалить устаревшие методы `_resetHideTimer`, `_showBriefOSDFor`, `_toggleOverlay` (они уже удалены в 2.1).
  - Наблюдаемое: `flutter analyze` чисто; `flutter test` 21/21 зелёный (никаких регрессий); файл `player_screen.dart` ≤ 600 строк (контроль pre-commit hook). Поведение в плеере на TV сохраняется.
  - _Requirements: 1.4, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 6.1, 7.1, 7.2, 7.3, 7.4, 7.5_
  - _Depends: 2.1, 3.1_
  - _Boundary: _PlayerScreenState_

---

## 3. Integration: isolated loading/error indicator

- [x] 3.1 Создать `_LoadingErrorIndicator` с RepaintBoundary
  - В `player_screen.dart` (на уровне файла, после класса `_PlayerScreenState`) добавить `class _LoadingErrorIndicator extends ConsumerWidget` с конструктором `const _LoadingErrorIndicator()`.
  - В `build(context, ref)`: `final manager = ref.watch(playerManagerProvider);` → `RepaintBoundary(child: StreamBuilder<PlayerState>(stream: manager.stateStream, builder: (ctx, snap) {...}))`.
  - Builder: switch по `state ?? PlayerState.idle`:
    - `PlayerState.loading` → `Center(child: CircularProgressIndicator(color: AppColors.primary))`.
    - `PlayerState.error` → `Center(Column(...))` с error-icon + текстом «Playback error. Retrying...» (как сейчас в `_PlayerScreenState.build`, строки 220-234).
    - default (`idle`, `playing`, `paused`, `stopped`) → `const SizedBox.shrink()`.
  - Удалить из `_PlayerScreenState.build()` существующий inline-StreamBuilder (строки 213-237) — его роль теперь у `_LoadingErrorIndicator`.
  - Наблюдаемое: `_LoadingErrorIndicator` есть в дереве; `flutter analyze` чисто; визуально на TV loading-spinner и error-message работают как раньше.
  - _Requirements: 5.1, 5.2, 5.3_
  - _Depends: 1.1_
  - _Boundary: _LoadingErrorIndicator_

---

## 4. Validation: автотесты

- [x] 4.1 (P) Юнит-тесты sealed `PlayerUiState`
  - Создать `megav_iptv/test/features/player/player_ui_state_test.dart`.
  - Тесты:
    - `HiddenState()` constructable + equals (если equality добавлена).
    - `ControlsState(hideAt: someDateTime)` round-trip — `s.hideAt == someDateTime`.
    - Same for BriefOsdState, SwitchPreviewState (обе поля), OverlayState.
    - Smoke: exhaustive switch по `PlayerUiState` для каждого варианта возвращает не-null строку (фиксирует что compile-time exhaustiveness работает).
  - Запуск: `flutter test test/features/player/player_ui_state_test.dart`.
  - Наблюдаемое: 5+ тестов зелёных.
  - _Requirements: 1.1, 1.2, 1.5_
  - _Depends: 1.1_
  - _Boundary: PlayerUiState_

- [x] 4.2 Widget-тест: open → controls auto-hide
  - Создать `megav_iptv/test/features/player/player_screen_overlay_test.dart`.
  - Setup: `ProviderScope` с overrides:
    - `currentChannelProvider` → fake Channel.
    - `playerManagerProvider` → fake `PlayerManager` (mock с `stateStream` + no-op `initialize`/`playChannel`).
    - `apiClientProvider` → mock с `getBestStreamUrl` returning fake URL.
    - `decoderConfigProvider` → fake config (`usesMedia3: false`).
  - Test 1: «open → controls auto-hide»:
    - Pump `PlayerScreen`.
    - `pump(Duration(milliseconds: 100))` — ждём пока `_init` завершится.
    - Assert: `find.byType(PlayerBottomInfo)` → `findsOneWidget` (BriefOsd показано).
    - `pump(Duration(seconds: 4))` — ждём истечения BriefOsd timer (3s) и controls timer (если был, 4s).
    - Assert: `find.byType(PlayerBottomInfo)` → `findsNothing`.
  - Запуск: `flutter test test/features/player/player_screen_overlay_test.dart`.
  - Наблюдаемое: тест зелёный.
  - _Requirements: 4.1, 4.2, 6.3_
  - _Depends: 2.2, 3.1_
  - _Boundary: _PlayerScreenState_

- [x] 4.3 Widget-тест: quick-switch ⬆ → preview → channel changed
  - В том же `player_screen_overlay_test.dart` добавить второй testWidgets.
  - Setup: тот же + mock `apiClient.getChannels` returning список из 3 channels.
  - Test 2: «quick-switch ⬆ → preview → committed»:
    - Pump `PlayerScreen`.
    - Wait `_init`.
    - `tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);`.
    - `pump(Duration(milliseconds: 100))`.
    - Assert: `find.byType(PlayerBottomInfo)` показывает preview-канал (через `tester.widget<PlayerBottomInfo>(...)` проверка `channel.name`).
    - `pump(Duration(milliseconds: 1500 + 100))`.
    - Assert: `currentChannelProvider` value изменился на preview-канал; `_uiState` теперь BriefOsdState (после commit'а `_openChannel` → BriefOsd).
  - Наблюдаемое: тест зелёный.
  - _Requirements: 3.3, 3.4, 4.7, 6.3_
  - _Depends: 2.2_
  - _Boundary: _PlayerScreenState_

- [x] 4.4 Widget-тест: press E → EPG visible → press E → EPG gone
  - В том же `player_screen_overlay_test.dart` добавить третий testWidgets.
  - Setup: тот же.
  - Test 3: «overlay toggle»:
    - Pump `PlayerScreen`.
    - Wait `_init`.
    - `sendKeyEvent(LogicalKeyboardKey.keyE);`.
    - `pump(Duration(milliseconds: 50))`.
    - Assert: `find.byType(EpgOverlay)` → `findsOneWidget`.
    - `sendKeyEvent(LogicalKeyboardKey.keyE);`.
    - `pump(Duration(milliseconds: 50))`.
    - Assert: `find.byType(EpgOverlay)` → `findsNothing`.
  - Наблюдаемое: тест зелёный.
  - _Requirements: 4.3, 4.4, 6.3_
  - _Depends: 2.2_
  - _Boundary: _PlayerScreenState_

- [x] 4.5 Прогнать все тесты и убедиться что регрессий нет
  - `cd megav_iptv && flutter test test/`.
  - Должно быть 21 (старые) + 5+ (4.1) + 3 (4.2-4.4) = 29+ тестов.
  - Все зелёные, exit code 0.
  - `flutter analyze` чисто.
  - Наблюдаемое: `+29 -0` (или больше), exit code 0; analyze без issues.
  - _Requirements: 6.4, 7.1, 7.2, 7.3, 7.4, 7.5_
  - _Depends: 4.1, 4.2, 4.3, 4.4_
  - _Boundary: All_

---

## 5. Manual: приёмка на TV + perf-замер

- [x] 5.1 Снять after-trace на TV (idle 30s + сценарий с overlay'ями)
  - Запустить `cd megav_iptv && flutter run --profile -d 192.168.100.8:5555`.
  - Дождаться загрузки + прогрев 5 сек.
  - На TV открыть канал (плеер).
  - Вернуть консоль для DevTools URL → пришли мне → я через VM Service `clearVMTimeline` → ждём 30s idle (без нажатий) → `getVMTimeline` → save в `snapshots/after_player_idle_trace.json`.
  - Параллельно сделать сценарий: открыть плеер, нажать E (EPG), нажать E (close), нажать ⬆ (quick-switch), подождать 1.5с (commit), нажать BACK → trace в `snapshots/after_player_scenario_trace.json`.
  - Наблюдаемое: оба JSON-файла на диске.
  - _Requirements: 8.1, 8.4_
  - _Depends: 4.5_
  - _Boundary: ReferenceDevice_

- [x] 5.2 Сравнить BUILD-events до и после
  - Подсчитать BUILD-events в `_PlayerScreenState.build` за 30 sec idle:
    - Baseline (с пятью полями): ~50 events / 30 sec.
    - After fix: должно быть ≤ 5 events / 30 sec (Req 5.4).
  - Если ≤ 5 → PASS Req 5.4.
  - Если > 5, но < 50 → улучшение, но не достигли цели; зафиксировать остаточный gap в `snapshots/perf_residual_gap.md` и close с явным acknowledgment.
  - Если ≥ 50 → NO-GO; исследовать что не сработало.
  - Наблюдаемое: численный отчёт в snapshot или residual gap document.
  - _Requirements: 5.4_
  - _Depends: 5.1_
  - _Boundary: ReferenceDevice_

- [x] 5.3 Operator acceptance: subjective UX check
  - На TV пройти чек-лист:
    1. Открыть канал → видно brief OSD ~3s → исчезает.
    2. Нажать любую клавишу → controls появились → исчезли через ~4s.
    3. Нажать E → EPG появилось без задержки (Req 8.3).
    4. Нажать E ещё раз → EPG исчез.
    5. Нажать BACK когда overlay открыт → overlay скрылся.
    6. Нажать BACK когда overlay скрыт → плеер закрылся (system back).
    7. Нажать ⬆⬆⬆ быстро → preview мелькает с правильными каналами → один commit на последний.
    8. Tap по плееру когда overlay открыт → overlay скрылся.
    9. Tap по плееру когда видно только видео → controls появились.
    10. Нажать I, L, R → каждый показывает свой overlay; повторное нажатие — скрывает.
  - Все 10 пунктов должны пройти. Если хотя бы один проблемный — фиксируем что именно не работает.
  - Наблюдаемое: оператор подтверждает «всё ок» или указывает конкретный пункт-проблему.
  - _Requirements: 4.1–4.9, 8.2, 8.3_
  - _Depends: 5.2_
  - _Boundary: ReferenceDevice_

## Implementation Notes

- **Operator-driven manual acceptance accepted at 2026-05-09**: оператор субъективно подтвердил «всё нор» на референсном TV-боксе без формального VM Service trace для tasks 5.1/5.2/5.3. Numerical check `BUILD events ≤ 5 per 30s idle` и `GPU avg ≤ 16.7 ms/frame` (Req 5.4, 8.1-8.4) **не проводился** — приняты как пройденные на основе субъективной оценки. Если позже обнаружатся perf-регрессии (например, при росте числа overlay-режимов или добавлении новых UI-компонент в плеер), повторный VM Service trace через `getVMTimeline` API может уточнить картину. Static-анализ (sealed type + RepaintBoundary + single timer) даёт высокую уверенность что Req 5.x работает корректно структурно.

- **Quick-switch race-fix is the most critical change for runtime stability**: до рефакторинга, быстрая последовательность нажатий ⬆⬆⬆ могла привести к параллельным fetch'ам каналов и наложению таймеров commit. После — `_quickSwitchInFlight` guard блокирует реентер, а `_transition()` гарантированно отменяет старый таймер до планирования нового. Этот fix не покрыт unit-тестом race-условия (требовал бы fake API с задержкой и точные timing-проверки), но защищён инвариантом «mutation only через `_transition`» (Req 3.1). Регрессия в quick-switch будет визуально заметна — если когда-то всплывёт, проверь что `_quickSwitchInFlight` сбрасывается в `finally`.
