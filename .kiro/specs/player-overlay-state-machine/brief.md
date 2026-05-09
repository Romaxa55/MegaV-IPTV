# Brief: player-overlay-state-machine

## Problem

Оператор сообщает: «когда показываем что идёт и т.д.» — overlay'и плеера ведут себя «намудрено». На референсном TV-боксе (rtd2851a) plain perf-trace плеера показывает healthy GPU thread (avg 12.2 ms/frame, 95% кадров в бюджете 60 fps), то есть **проблема не в скорости рендеринга**, а в **сложности и непредсказуемости видимости overlay'ев** при использовании пультом.

Корни проблемы (видны прямо в `lib/features/player/player_screen.dart`, 372 строки):

1. **5 источников видимости** для UI поверх видео — три boolean (`_showControls`, `_showBriefOSD`), один enum (`_overlay: PlayerOverlayMode`), один nullable (`_switchPreview: Channel?`). Это даёт 2³×5×2 = 80 формальных комбинаций, из которых валидны единицы.
2. **Три независимых таймера** (`_hideTimer` 4с, `_osdTimer` 3с, `_switchTimer` 1.5с) — могут срабатывать одновременно или в нежелательном порядке. Например: пользователь нажал ⬆ (quick-switch), `_switchPreview` показывается, но в это же время `_hideTimer` тикнул и спрятал `_showControls`. Поведение зависит от последовательности микросекунд.
3. **Условие отрисовки bottom-info — три флага через ИЛИ + один через И** (строки 252-254): `(_showControls || _showBriefOSD || _switchPreview != null) && _overlay == none && (_switchPreview ?? channel) != null`. Это decidable, но не читается, и любая правка ломает интуицию.
4. **AnimatedOpacity с opacity: 1.0 константой** (строки 241-244 и 259-262) — только показывается/скрывается через `if`-conditional Stack child. Так что AnimatedOpacity ничего не анимирует — она fades только при mount, не при unmount. Это значит overlay'и **резко исчезают**, не fade-out.
5. **25 BUILD-событий за 16 секунд idle-плеера** (по timeline trace) — `setState(...)` срабатывает 1.5 раза в секунду даже когда оператор ничего не нажимает. Скорее всего, это `StreamBuilder<PlayerState>` подписан на `_playerManager.stateStream`, который тикает чаще нужного. Это безопасно (12 мс/build, не валит fps), но **избыточно**: ребилдится **весь Stack плеера**, в т.ч. видео-Texture, не только зависимый виджет (loading indicator).
6. **Race на quick-switch**: `_switchTimer` ждёт 1500ms перед фактическим переключением. За это время оператор может нажать ⬆/⬇ ещё раз → `_quickSwitch()` использует `_switchPreview` как базу, но **не отменяет** старый таймер последовательностью «отмена + новый». Вместо этого старый таймер срабатывает на старом next, а новый накладывается. В коде есть `_switchTimer?.cancel()` (строка 145), но оно не в начале, а после fetch — между `await api.getChannels(...)` и cancel'ом успевает отработать предыдущий таймер.

Вместе это даёт ощущение «плеер живёт своей жизнью» — overlay'и появляются/исчезают «не вовремя», bottom-info мигает, при быстром переключении каналов видны артефакты.

## Current State

После закрытия двух предыдущих спеков (`home-grid-optimization`, `home-grid-visual-polish`) сетка на главном экране отполирована и работает в 60+ fps на TV. Плеер же:
- `lib/features/player/player_screen.dart` — 372 строки, 5 state-флагов, 3 таймера, 1 enum.
- 6 overlay-виджетов: `PlayerControlsOverlay`, `PlayerBottomInfo`, `EpgOverlay`, `ChannelsSidebar`, `InfoOverlay`, `SimilarOverlay`.
- Native player (Media3 / media_kit / video_player через `_playerManager.activeEngine`) — **не трогаем**, он работает.
- Performance baseline: avg 12.2 ms/frame raster, max 27ms, 12 of 417 frames over budget — **зелёный показатель**.

Артефакты этого спека:
- `snapshots/baseline_player_open_trace.json` — 16.5 sec VM-Service trace открытия плеера и стационарного состояния (4.9 МБ, 32742 events). Из него видны 25 ребилдов, частота фреймов, отсутствие GC-стормов.

## Desired Outcome

1. **Один источник истины** для видимости UI поверх видео — например, sealed-class или enum с N валидными состояниями (`hidden`, `briefOsd`, `controlsVisible`, `switchPreview`, `overlay(EpgOverlay/ChannelsSidebar/InfoOverlay/SimilarOverlay)`). Невозможно представить невалидную комбинацию.
2. **Один центральный таймер** или явный state-machine: при переходе в одно из таймерных состояний (briefOsd, controlsVisible) указывается длительность, по истечению — переход в `hidden`. Старый таймер при новом переходе **гарантированно** отменяется первой инструкцией.
3. **Bottom-info рендерится без race**: при quick-switch отображается preview без мигания (быстрая смена ⬆⬆⬆ показывает последовательно три preview без артефактов). Эффект: пользователь чувствует «плеер слушается», не «плеер тормозит и моргает».
4. **AnimatedOpacity**, если оставляется, реально анимирует (показ + скрытие). Иначе — заменяется на conditional rendering без обёртки, чтобы не вводить в заблуждение.
5. **StreamBuilder для loading/error state не ребилдит весь Stack**: вынесен в отдельный sub-widget, обёрнут в `RepaintBoundary`. Целевой эффект: BUILD-событий в idle ≤ 5 за 30 секунд (вместо текущих ~50 за 30 сек).
6. **Поведение детерминировано**: для каждой последовательности нажатий пультом результат предсказуем. Никаких «иногда работает, иногда нет».
7. **Сохраняется** вся текущая функциональность: BACK, EPG (E), Info (I), Channels (L), Similar (R), quick-switch ⬆⬇, OK/play-pause, click-to-toggle.

## Approach

**Подход «явный state machine»** — выбран среди трёх рассмотренных.

Заменить 5 разрозненных полей в `_PlayerScreenState` одним `PlayerUiState`:

```dart
sealed class PlayerUiState {
  const PlayerUiState();
}
class HiddenState extends PlayerUiState { const HiddenState(); }
class ControlsState extends PlayerUiState {
  final DateTime hideAt;
  const ControlsState({required this.hideAt});
}
class BriefOsdState extends PlayerUiState {
  final DateTime hideAt;
  const BriefOsdState({required this.hideAt});
}
class SwitchPreviewState extends PlayerUiState {
  final Channel previewChannel;
  final DateTime commitAt;
  const SwitchPreviewState({required this.previewChannel, required this.commitAt});
}
class OverlayState extends PlayerUiState {
  final PlayerOverlayMode mode;
  const OverlayState({required this.mode});
}
```

Один `Timer? _stateExpiryTimer` отменяется и пересоздаётся при каждой смене state. На expiry — переход в `HiddenState`.

Метод `_transition(PlayerUiState newState)` — единственная точка изменения. Он:
1. Отменяет `_stateExpiryTimer`.
2. `setState(() => _uiState = newState)`.
3. Если у нового состояния есть expiry (`hideAt`/`commitAt`) — запускает новый Timer на ту же длительность.

В `build()` — единственный `switch` по `_uiState`, отрисовка определяется явно для каждого состояния.

Quick-switch получает свой sealed-метод: `_transition(SwitchPreviewState(...))` отменит и `_hideTimer`-эквивалент, и любой предыдущий switchPreview, в одном setState.

`StreamBuilder<PlayerState>` выносится в отдельный stateful sub-widget `_LoadingErrorIndicator`, обёрнутый в `RepaintBoundary`. Tex Texture + Stack в `build()` `_PlayerScreenState` больше не ребилдятся при тике state-stream.

## Scope

- **In**:
  - Рефакторинг `lib/features/player/player_screen.dart`: вытеснение 5 флагов + 3 таймеров в один `sealed class PlayerUiState` и один `_stateExpiryTimer`.
  - Введение метода `_transition(PlayerUiState)` как единственной точки изменения видимости.
  - Вынос `StreamBuilder<PlayerState>` в отдельный `_LoadingErrorIndicator` с `RepaintBoundary`.
  - Конвертация `if`-conditional `AnimatedOpacity` в **либо** реально-анимирующий `AnimatedSwitcher`/полный `AnimatedOpacity` цикл, **либо** простое условное rendering без обёртки (выбираем что проще).
  - Безопасный quick-switch: первая инструкция `_quickSwitch()` отменяет предыдущий switch до асинхронных операций.
  - Юнит-тесты state-machine (transition table: для каждого `from-state, event` определённый `to-state`).
  - Widget-тесты на 3 интеграционных сценария: open → idle 4s → controls hidden; quick-switch ⬆ → preview → 1.5s → channel changed; press E → EPG visible.
  - After-trace на TV для подтверждения уменьшения BUILD-событий.

- **Out**:
  - Native player (Media3 / media_kit / video_player engines в `lib/core/player/`).
  - Внутренности 6 overlay-виджетов (EpgOverlay, ChannelsSidebar, InfoOverlay, SimilarOverlay, PlayerControlsOverlay, PlayerBottomInfo) — их публичные API сохраняются, тела не правятся.
  - Сетка на главном экране (закрыта).
  - Стримы / API клиента / Riverpod-провайдеры.
  - HDR / DRM / зелёные полосы / channel switching сетевые проблемы.
  - 4K perf вне overlay'ев.

- **Adjacent expectations**:
  - `_playerManager.activeEngine.buildVideoWidget(...)` остаётся неизменным — наш state-machine не управляет видео-плеером, только UI поверх него.
  - `currentChannelProvider`, `currentChannelIndexProvider`, `apiClientProvider`, `decoderConfigProvider` — read-only зависимости.
  - `PlayerOverlayMode` enum (определён в `widgets/player_overlay.dart`) сохраняется, но используется только внутри `OverlayState`.

## Boundary Candidates

- **State-машина видимости** (`_PlayerScreenState`): `_uiState` + `_transition()`.
- **Loading/error sub-widget** (`_LoadingErrorIndicator`): отдельный `RepaintBoundary` для StreamBuilder.
- **Quick-switch race-fix** (`_quickSwitch()`): атомарное отмена-и-перезапуск.
- **Тесты state-machine** (`test/features/player/`): unit + widget.

## Out of Boundary

- Native player engines.
- 6 overlay-виджетов внутренности.
- Сетка на главном экране.
- HDR / DRM / 4K / зелёные полосы / зависимости от Realtek SoC.

## Upstream / Downstream

- **Upstream**:
  - `lib/core/player/player_manager.dart` — read-only API.
  - `lib/core/player/player_engine.dart` — read-only PlayerState enum.
  - `lib/core/playlist/models/channel.dart` — модель.
  - `lib/core/api/api_client.dart` — `getChannels`, `getBestStreamUrl`.
  - Riverpod providers — read-only.
- **Downstream**:
  - Будущий спек на 4K perf / зелёные полосы / DRM — наследует чистую state-машину.
  - Будущий спек на overlay-styling (если потребуется) — наследует sealed UiState contract.

## Existing Spec Touchpoints

- **Extends**: ничего (плеер не был покрыт ни одним из закрытых спеков).
- **Adjacent**: `home-grid-optimization` и `home-grid-visual-polish` — закрытые спеки на сетке. Не трогаем, кроме того что после `OK` на плитке в сетке открывается `PlayerScreen`. Контракт открытия не меняется.

## Constraints

- **Stack**: Flutter + Riverpod (как везде). Никаких новых пакетов.
- **Платформа**: Android TV-бокс (rtd2851a). Тесты — на той же установке через `flutter run --profile -d 192.168.100.8:5555`.
- **Совместимость**: все 21 существующих автотестов проекта должны продолжать проходить. Новые тесты добавляются в `test/features/player/`.
- **Performance budget**:
  - BUILD-events в idle ≤ 5 за 30 sec (текущий baseline ~50 за 30 sec).
  - GPU avg ≤ 16.7 ms/frame в любых сценариях открытия/закрытия overlay'ев.
  - Никакой новой регрессии в существующих метриках сетки.
- **Принцип**: «детерминированность важнее полировки». Сначала state-machine очевидно правильная, потом полировка (анимации, RepaintBoundary).
- **Без изменений** в `pubspec.yaml`.
