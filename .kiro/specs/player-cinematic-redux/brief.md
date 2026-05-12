# Brief: player-cinematic-redux

## Problem

Пользователь сказал (2026-05-12): «и потом плеер делаем — самое
важное». Это значит после Cinematic + onboarding + skeleton — основной
focus переходит на полировку плеер-экрана.

Закрытый spec `player-cinematic-redesign` (Wave 1) уже частично
реализовал визуальную часть (glass-panel controls, channel deck,
inline EPG), но user знает что там «беда коненчо» (его слова, прошлая
сессия) — реальное воспроизведение каналов на rtd2851a не stable.

## Current State

- `lib/features/player/` — экран существует, layout от
  `player-cinematic-redesign`.
- `lib/core/player/player_manager.dart` + `player_engine.dart` —
  движок воспроизведения, использует `media_kit` 1.2.6 + native
  MPV / video_player платформенные плагины.
- Закрытый spec `player-overlay-state-machine` — sealed
  `PlayerUiState` (idle/buffering/playing/paused/error/seeking),
  не открывать.
- Reported issues (на основе предыдущих сессий):
  - 3 retry attempts on DNS failure → каналы умирают (Issue #3 в
    backlog).
  - media_kit web build broken (Issue #16) — не критично, но
    блокирует visual-feedback-pipeline.
  - User says: «плеер беда» — нестабильность на реальном устройстве.

## Desired Outcome

1. **Стабильность**: каналы запускаются reliably на rtd2851a.
   Retry-policy умнее (>3 попыток, exponential backoff на DNS/network
   ошибках).
2. **Скорость**: time-to-first-frame ≤ 2 сек для уже cached
   stream-URL, ≤ 5 сек для нового.
3. **Visual**: текущий cinematic layout сохраняется, но debug
   findings из новых сессий внедряются.
4. **EPG inline**: программа на канале видна сразу при playback
   (закрытый spec уже это сделал — проверить что не сломалось).
5. **Channel switch**: ↑/↓ переключает каналы без kill-restart
   движка (если возможно — re-use player session).
6. **Error states**: graceful UI вместо «чёрный экран навсегда».

## Approach

**Stability-first**: глубокий audit `player_manager.dart` +
`player_engine.dart` на flaky retry + error-handling. Возможно
понадобится написать новый retry-controller или поменять engine
(media_kit → exoplayer-direct?).

**Plan**:
1. Open issues backlog (`gh issue list --state open`) — собрать
   все player-related findings.
2. Audit current `PlayerManager` на:
   - retry-policy
   - timeout values
   - error → next-stream logic
   - resource cleanup (memory leaks на rtd2851a).
3. Decide: incremental fixes (current engine) vs engine swap
   (heavier rewrite).
4. Implement + test against real rtd2851a (юзерская проверка
   обязательна).

## Scope

### In
- `lib/core/player/player_manager.dart` retry-policy rewrite.
- `lib/core/player/player_engine.dart` error handling.
- `lib/features/player/` UI states для error / buffering.
- Тесты: integration test (offline → online) — если возможно
  через mock.

### Out
- Backend changes (channel URL provisioning, EPG sync).
- Cinematic home screen — не трогаем (уже Wave 5).
- Detail screen — не трогаем.
- Native player plugin internals.

## Boundary Candidates
- `PlayerRetryController` — новый owner retry-policy.
- `PlayerErrorMapper` — translates engine errors to UI states.
- `PlayerSessionReuse` — переключение каналов без kill.
- `lib/features/player/widgets/player_error_overlay.dart` (новый
  или existing).

## Out of Boundary
- `PlayerUiState` sealed type (owned by closed
  `player-overlay-state-machine` — не трогаем).
- Cinematic visual layout (`player-cinematic-redesign` — не
  открываем).

## Upstream / Downstream

**Upstream**:
- `player-cinematic-redesign` — UI layout.
- `player-overlay-state-machine` — sealed state.
- `home-unified-grid-scroll` — entry point (юзер запускает плеер
  из home).
- `media_kit` package.

**Downstream**:
- Detail screen (passes channel context to player).
- EPG screen (deep-link to channel playback).
- Mobile player (отдельная mount-точка).

## Constraints
- TV-perf: hot-path во время playback не должен делать allocations.
- rtd2851a: 512 MB RAM — не больше одной активной texture в момент.
- Russian-first error messages.
- Robust offline behaviour: показывать ошибку, не вешать UI.

## Existing Spec Touchpoints
- **Extends** (poss. open для small changes): `player-cinematic-redesign`
  если UI bug fixes нужны.
- **Strict adjacent (read-only)**: `player-overlay-state-machine` —
  sealed type. Расширяет render trees внутри ControlsState, не
  добавляет новых state-вариантов.

## Direct Implementation Candidates
- Bump `media_kit` patch version если есть upstream fix для
  rtd2851a-class ARM.
- Tighten existing retry — это может оказаться 10-line patch.

## Pre-work
- `gh issue list --state open --json number,title,body | jq` —
  собрать все player-related findings (Issue #3 retry, etc.) перед
  планированием.
