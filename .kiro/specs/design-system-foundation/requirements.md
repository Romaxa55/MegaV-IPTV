# Requirements Document

## Introduction

`design-system-foundation` — это foundation-spec для всего цикла MegaV IPTV redesign 2026 (см. `roadmap.md`). Handoff bundle от Claude Design вводит swappable палитры, новые шрифтовые пары и расширенные design-токены, которые **переиспользуются всеми остальными screen-redesign спеками** (issues #5-#12). Без centralized theming infrastructure каждый screen-spec будет дублировать code, и любое изменение визуального языка потребует касаться 7+ файлов.

Этот спек выполняет **infrastructure refactor только**: переписывает `lib/core/theme/*` под model «runtime-swappable palette + font pair + radius scale через Riverpod», добавляет 6 готовых палитр и 1 готовую шрифтовую пару (`font-cinema` для RU локали), но **не вносит ни одного user-visible изменения**. Закрытые специй (`home-grid-optimization`, `home-grid-visual-polish`, `player-overlay-state-machine`) продолжают компилироваться и работать через aliases на старые `AppColors.primary`/`background`/etc.

Целевое устройство неизменно: Realtek `rtd2851a` Android TV-бокс. Performance budget из `flutter-tv-perf.md` соблюдается: theme switch через `ref.watch` Riverpod-провайдера дешёвый (rebuilds локализованы внутри theme consumers).

Все 30 существующих автотестов должны продолжать проходить без модификаций. Новые тесты добавляются для палитр, radius scale, провайдера.

## Boundary Context

- **In scope**:
  - Refactor `lib/core/theme/app_colors.dart`: `static const` поля → instance-class `AppPalette` с 6 готовыми именованными вариантами (`AppPalette.noirCobalt`, `crimsonReel`, etc.).
  - Новый `lib/core/theme/app_radius.dart` — token-класс с 5 значениями (`xs/sm/md/lg/xl` = 6/10/14/20/28).
  - Новый `lib/core/theme/app_palettes.dart` — 6 палитр согласно дизайну.
  - Новый `lib/core/theme/theme_provider.dart` — Riverpod-провайдер текущей палитры + persisted preference.
  - Новая шрифтовая пара `font-cinema` (Cormorant Garamond + Golos Text + JetBrains Mono) подключённая через `google_fonts` (пакет уже в pubspec).
  - Updates `lib/core/theme/app_theme.dart`: использовать активную палитру из провайдера + новые шрифты.
  - Backward-compatible aliases: существующие call-sites `AppColors.primary` / `background` / etc. продолжают работать.
  - Юнит-тесты: палитры (наличие всех токенов), radius scale (точные значения), провайдер (default = noirCobalt, switch меняет state).

- **Out of scope**:
  - Применение нового theming к screen-widgets (это owner отдельных screen-redesign спеков).
  - User-visible UI для смены палитры — Settings UI сделает issue #11.
  - Persisted storage layer (`shared_preferences` интеграция) — может быть скаффолд stub, реальная persistence — отдельный спек.
  - Native player engines, providers, models, API.
  - Mobile-specific theming differences — issue #12 решит.

- **Adjacent expectations**:
  - Closed kiro specs (`home-grid-*`, `player-overlay-state-machine`) продолжают компилироваться и проходить тесты с aliases.
  - GitHub issue #4 — primary discussion / progress tracking для этого спека.

## Requirements

### Requirement 1: Single source of truth для color tokens (palette class)

**Objective:** Как разработчик MegaV IPTV, я хочу один class который хранит все color tokens текущей палитры и подписывается через Riverpod-провайдер, чтобы при необходимости подменить палитру (Noir Cobalt → Crimson Reel) не менять call-sites.

#### Acceptance Criteria

1. The Theme Foundation shall define a class named `AppPalette` (or equivalent) holding all color tokens of one palette (background, surface, text, accent, gold, live, etc.).
2. The Theme Foundation shall provide a Riverpod-style provider that returns the current `AppPalette` and is read by widgets via `ref.watch`.
3. The Theme Foundation shall ship with at least the 6 palettes from the handoff bundle (Plum, Ivory, **Noir Cobalt** as default, Pitch, Crimson Reel, Modern), each with the same token surface (no missing fields between palettes).
4. While the application is running, when the active palette changes (via the provider's setter or equivalent API), all widgets that read the palette via `ref.watch` shall rebuild with the new colors within the next frame.
5. The Theme Foundation shall ship with **Noir Cobalt** as the default palette on first launch, before any user override is loaded.

### Requirement 2: Backward compatibility с существующими call-sites

**Objective:** Как maintainer, я хочу чтобы рефакторинг theming не сломал ни один из ~50 существующих call-sites `AppColors.primary` / `AppColors.background` / etc., чтобы closed specs продолжали работать без модификаций.

#### Acceptance Criteria

1. The Theme Foundation shall keep all existing public API of `AppColors` callable from existing files (`cinema_card.dart`, `cinema_row.dart`, `_card_poster.dart`, `home_screen.dart`, `player_screen.dart`, `_LoadingErrorIndicator`, etc.) without code changes in those files.
2. While the application is running with the default palette, all existing widgets shall render visually identical to the pre-refactor state, allowing for negligible color drift introduced by the new design palette (e.g., text turning warm cream `#F4F1E9` instead of pure white `#FFFFFF`).
3. While the regression test suite runs, all 30 existing automated tests in `test/` shall pass without modification.

### Requirement 3: Radius scale как single source of truth

**Objective:** Как разработчик нового screen, я хочу обращаться к `AppRadius.md` (или эквиваленту) вместо магического числа `BorderRadius.circular(12)` или `(14)` или `(16)`, чтобы все экраны имели согласованный набор радиусов.

#### Acceptance Criteria

1. The Theme Foundation shall define a class `AppRadius` with at least 5 named constants: `xs`, `sm`, `md`, `lg`, `xl`.
2. The values shall be: `xs = 6`, `sm = 10`, `md = 14`, `lg = 20`, `xl = 28` (logical pixels), matching the design's `--r-*` tokens.
3. The Theme Foundation shall expose helper methods or properties to obtain `BorderRadius` from these constants (e.g., `AppRadius.brSm` returns `BorderRadius.circular(10)`).

### Requirement 4: `font-cinema` пара для Russian локали

**Objective:** Как пользователь видящий текст в приложении на русском, я хочу editorial-cinematic typography (display serif italic + UI sans + mono для метаданных), которая корректно отображает кириллицу.

#### Acceptance Criteria

1. The Theme Foundation shall configure three font families for the application: a display serif (italic-capable) with full Cyrillic coverage, a UI sans family with full Cyrillic coverage, and a monospaced family for metadata.
2. The Theme Foundation's default selection for the Russian locale shall be: display = `Cormorant Garamond`, UI = `Golos Text`, mono = `JetBrains Mono`.
3. The display font shall support italic style for headings (allowing emphasis via italic-style display titles).
4. The Theme Foundation shall NOT apply italic to the EPG screen's body text (per user explicit instruction in chat1.md: «курсив не надо в едк не смотрится»).
5. While the application uses these fonts, no new package shall be added to `pubspec.yaml` — `google_fonts` is already a dependency and shall provide all three families.
6. The Theme Foundation shall provide `Theme` extension methods or convenience accessors (e.g., `Theme.of(context).extension<MegaVTextStyles>()?.displayItalic`) to apply font styles consistently.

### Requirement 5: Theme switching API

**Objective:** Как Settings screen (issue #11), я хочу один публичный метод чтобы сменить активную палитру, чтобы пользовательское переключение через UI работало без специальных хуков.

#### Acceptance Criteria

1. The Theme Foundation shall expose a public API method to switch the active palette by name or enum (e.g., `ref.read(themeProvider.notifier).setPalette(AppPaletteName.crimsonReel)`).
2. When the active palette is switched programmatically, the provider's state shall update immediately, and all consumers via `ref.watch` shall rebuild on the next frame.
3. The Theme Foundation shall provide an enumeration of available palette names so consumers can iterate (e.g., for a settings picker UI).
4. While the user has not yet expressed a preference, the Theme Foundation shall return Noir Cobalt as the active palette.

### Requirement 6: Persisted preference stub (interface only)

**Objective:** Как пользователь, я ожидаю что выбранная мной палитра сохраняется между сессиями приложения, так что мне не нужно перевыбирать её при каждом запуске.

#### Acceptance Criteria

1. The Theme Foundation shall accept an optional persistence adapter at provider construction (an interface with `read()` / `write(name)` methods).
2. While no persistence adapter is provided, the Theme Foundation shall use in-memory state only and reset to default on app restart (acceptable for this spec — actual persistence is a follow-up).
3. While a persistence adapter is provided, the Theme Foundation shall read the persisted palette name during provider initialization and use it as the active palette (falling back to Noir Cobalt if not present or invalid).
4. While the user changes the active palette, the Theme Foundation shall call `write(name)` on the persistence adapter (if provided) to persist the choice.

### Requirement 7: Performance budget

**Objective:** Как пользователь TV-бокса, я хочу чтобы theming-инфраструктура не вызывала избыточных перерисовок.

#### Acceptance Criteria

1. While a widget reads `ref.watch(themeProvider)` and the active palette has not changed, the widget shall not rebuild on unrelated state changes.
2. While the active palette is changed, only widgets that explicitly subscribe via `ref.watch` shall rebuild — widgets that read color via static `AppColors.X` aliases shall not rebuild (compatibility with non-reactive call-sites).
3. The Theme Foundation shall not introduce any operation that violates `flutter-tv-perf.md` rules: no `BackdropFilter`, no `BoxShadow.blurRadius > 12`, no `ShaderMask`.

### Requirement 8: Тестируемость

**Objective:** Как разработчик, я хочу чтобы все 6 палитр и весь radius scale были покрыты автотестами, чтобы регрессии в этой инфраструктуре ловились до runtime.

#### Acceptance Criteria

1. The project shall include a unit test that asserts every named palette has all required tokens populated (no nulls, no missing keys).
2. The project shall include a unit test that asserts each palette name from the enum maps to a unique palette instance (no duplicates, no missing).
3. The project shall include a unit test that asserts `AppRadius` constants have the exact specified values (6, 10, 14, 20, 28).
4. The project shall include a widget test that asserts switching the palette via the provider's API causes a `Consumer` widget to rebuild with the new color.
5. The project shall include a widget test that asserts existing static `AppColors` aliases continue to return non-null `Color` values without runtime errors.
