# Brief: onboarding-remote-cheatsheet

## Problem

После первого запуска приложения юзер видит главный экран без любых
объяснений: как двигаться (D-pad ↑/↓/←/→), что делает OK, как
вернуться (Back), где поиск/EPG/settings. На TV-боксе это не
очевидно, особенно для тех кто привык к Smart-TV-овским гайдам типа
«нажмите ▲ для меню».

Пользователь сказал (2026-05-12): «в фьюче юзер никогда не увидит
инструкцию как управлять всем добром».

## Current State

- `CinematicRemoteHintFooter` есть, отображается под последней row
  (`cinematic_home_screen.dart:453`). Это **bottom HUD** с
  иконками: «←→ каналы», «OK смотреть», «≡ EPG». Хорошая контекстная
  подсказка но **юзер её ещё не видит** при первом запуске (она ниже
  fold, появляется только после прокрутки вниз).
- Никакого **первого запуска tutorial / overlay tour** нет.
- Никакого «нажми любую кнопку чтобы начать» сценария.
- Settings содержит секцию help/about? — надо проверить, скорее
  нет.

## Desired Outcome

1. **Первый запуск**: лёгкий dismissible overlay/tour (1-3 экрана):
   - «Используй D-pad ←/→/↑/↓ для навигации».
   - «OK = играть. Back = выйти».
   - «MENU = поиск / EPG / settings».
2. **Persistent shortcut**: подсказка «❓Помощь» доступна в
   settings или через комбо (например, долгое нажатие OK на hero).
3. **Локализация**: оба экрана на русском (default project language).
4. **TV-safe**: focusable buttons, нет mouse-only events; работает с
   keyboard клавишами на macOS и D-pad на rtd2851a.
5. **Dismissable**: «Понятно» крупная focusable кнопка; запоминается
   через `SharedPreferences` чтобы не показывать снова.
6. **Skip-able**: «Пропустить» в каждом шаге.

## Approach

**Overlay tour**: при mount `CinematicHomeScreen`, если
`SharedPreferences.getBool('onboarding-shown') != true` — показать
full-screen overlay с tour. Tour — `PageView` из 3 страниц с
D-pad navigation. После «Понятно» — `setBool('onboarding-shown',
true)` и dismiss.

Альтернатива (проще): **single overlay** с одной карточкой
«вот как управлять» + 4 ключевых сценария (←/→, ↑/↓, OK, Back),
без PageView.

## Scope

### In
- Новый widget `OnboardingTourOverlay` (full-screen ExcludeFocus
  поверх Cinematic при первом запуске).
- `SharedPreferences` (`shared_preferences` уже в pubspec.yaml)
  для persistent flag `onboarding-shown`.
- Опциональный route `/settings/onboarding-reset` (debug-only)
  чтобы сбросить флаг для тестирования.
- Локализация RU контент.
- Тест: первый запуск показывает tour, второй — не показывает.

### Out
- Полноценный help-screen с всеми экранами — отдельный спек если
  понадобится.
- Видео-tour — слишком тяжёлый для rtd2851a.
- Hint-bubbles на каждой row («это категория», «это плитка») —
  слишком шумно.

## Boundary Candidates
- `OnboardingTourOverlay` (новый widget в
  `lib/features/onboarding/`).
- `OnboardingState` provider (Riverpod) — flag из SharedPreferences,
  reset-action.
- Integration point: `cinematic_home_screen.dart` build mount.

## Out of Boundary
- Settings, EPG, Search экраны — не трогаем.
- Backend / API.

## Upstream / Downstream

**Upstream**:
- `home-unified-grid-scroll` — overlay mount-точка внутри
  CinematicHomeScreen.
- `design-system-atoms` — `MvButton.primary` для CTA, `Chip` для
  иконок ←/→/OK.
- `shared_preferences` package (уже подключен).

**Downstream**:
- Settings spec может добавить «Reset onboarding» action.
- Будущие экраны могут использовать тот же overlay-pattern для
  feature-specific tour.

## Constraints
- TV-perf: overlay не использует BackdropFilter; полупрозрачный
  background через `Colors.black.withValues(alpha: 0.85)` +
  `DecoratedBox`.
- Realtek `rtd2851a`: SharedPreferences дёшев, overlay рендерится
  ≤ 5 ms.
- Russian-first.
- Single-shot: tour не должен раздражать после первого dismiss.

## Existing Spec Touchpoints
- **Adjacent**: `home-cinematic-redesign` (visual layer, не
  открываем).
- **Adjacent**: `settings-redesign` (reset-action может быть
  добавлено в будущей итерации).
