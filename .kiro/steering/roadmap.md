# Roadmap — MegaV IPTV redesign 2026 cycle

## Overview

После handoff от Claude Design (`.kiro/design/megav-iptv-handoff/`, 40 файлов, 9 экранов прототипов на HTML/JSX) проект переходит к **большой переписке UI** во всю Cinematic + Noir Cobalt эстетику. User explicit goal (chat1.md): «**переплюнуть Netflix с пульта**», главный pain — «**сильно тормозит**».

Проект уже имеет **3 закрытых kiro-спека** (`home-grid-optimization`, `home-grid-visual-polish`, `player-overlay-state-machine`) и **steering doc `flutter-tv-perf.md`** с proven performance rules для Realtek `rtd2851a` TV-бокса.

Этот roadmap декомпозирует design-import в **2 foundation спека + 8 screen спеков**, с явным dependency graph чтобы избежать blocking-цепочек.

## Approach Decision

- **Chosen**: layered foundation-first, screen-by-screen рефакторинг с переиспользованием atoms.
- **Why**:
  - Design-bundle вводит **6 swappable палитр + 6 шрифтовых пар + 13 atoms** — без centralized infrastructure каждый screen-спек будет дублировать.
  - **7 perf-конфликтов** с `flutter-tv-perf.md` обязывают определить safe replacements **до** начала screens, иначе каждый screen-спек будет переоткрывать существующие perf-fixes.
  - Сохраняем закрытые специй (`home-grid-*`, `player-overlay-*`) как foundation — design-redesign их **не ломает**, лишь меняет визуал поверх.
- **Rejected alternatives**:
  - Single mega-spec на весь redesign — невозможно validate как unit, 3-4 недели работы без feedback gate.
  - Screen-first без foundation — каждый screen-спек copy-paste atoms + open theming questions.
  - Adopting design CSS verbatim — регрессит `home-grid-optimization` Req 9.4 (boxShadow blur removed) и `home-grid-visual-polish` Req 5.x (ShaderMask removed).

## Scope

### In
- 2 foundation спеки: theming infrastructure + perf-safe widgets + atoms.
- 8 screen-redesign спеков: Cinematic Home, Editorial Home, Detail, Player, EPG, Search, Settings, Mobile.
- Все спеки соблюдают `flutter-tv-perf.md` правила.
- Sealed `PlayerUiState`, adaptive `pickColumns 3/4/5`, `_LoadingErrorIndicator` сохраняются нетронутыми.

### Out
- Native player engines (`lib/core/player/*`) — read-only.
- API/data layer (`lib/core/api/*`, `lib/core/playlist/*`, `lib/core/epg/*`) — read-only кроме новых endpoint'ов для search и EPG-batch.
- Account / subscription backend (если нет — Settings показывает stub).
- Voice search.
- iOS/macOS specific features.

## Constraints

- **Reference device**: Realtek `rtd2851a` Android TV-бокс.
- **Perf budget**: avg `GPURasterizer::Draw ≤ 16.7 ms` при scroll. Rules из `.kiro/steering/flutter-tv-perf.md`.
- **No new packages** в `pubspec.yaml` если возможно. `google_fonts` уже есть; `cached_network_image` отложен в отдельный спек если нужен.
- **All 30 existing tests** должны проходить throughout the cycle.
- **Dependency direction**: foundation (#4, #13, #14) → screens (#5-#12). Any screen-spec обязан декларировать `_Depends:_` на нужные foundation-специй.
- **Russian-first localization**: для шрифтов выбран `font-cinema` (Cormorant Garamond + Golos Text) с full Cyrillic coverage.

## Boundary Strategy

- **Why this split**:
  - Foundation специй (#4, #13, #14) — это infrastructure которая не зависит от конкретного экрана. Можно делать параллельно (если 2 разных импл-агента).
  - Screen-специй (#5-#12) — каждый имеет чёткий boundary (одна `feature/<screen>/` директория) + минимальный shared state.
  - User mode (TV vs mobile) разделён через issue #12 — TV экраны (#5-#11) не trogают mobile widgets, и наоборот.
- **Shared seams to watch**:
  - `lib/core/theme/*` — owned by #4. Все screens используют через provider, но не модифицируют.
  - `lib/core/ui/atoms/*` — owned by #14. Screens import, не extend.
  - `lib/features/home/widgets/_grid_tokens.dart` — закрыт `home-grid-optimization`, screens используют через alias.
  - `PlayerUiState` sealed type — owned by `player-overlay-state-machine`. Screen #8 extends rendering, не state-machine.
  - Router (`go_router`) — каждый screen добавляет свой route entry; нет central modification.

## Existing Spec Updates

- `home-grid-optimization` — НЕ ОТКРЫВАТЬ. `pickColumns 3/4/5` сохраняется. Aliases для color tokens создаются в #4.
- `home-grid-visual-polish` — НЕ ОТКРЫВАТЬ. Fade-edge через DecoratedBox остаётся.
- `player-overlay-state-machine` — НЕ ОТКРЫВАТЬ. Sealed `PlayerUiState` остаётся. Screen #8 расширяет render trees внутри `ControlsState`, не добавляет новых state-вариантов.

## Direct Implementation Candidates

Нет — все 11 issues этого roadmap (#3 + #4-#14) требуют kiro-спека.

Existing issue #3 (PlayerManager retry) — out of scope этого roadmap (network resilience), отдельный backlog.

## Specs (dependency order)

### Wave 0 — Foundation (parallel-capable, можно делать batch)

- [x] **design-system-foundation** — theming infrastructure (6 palettes via Riverpod + AppRadius + font-cinema). Issue #4. Dependencies: none. ✅ implemented + GO.
- [x] **perf-safe-widgets** — `SafeBackdrop`, `SafePill`, `SafeFocusRing`, `SafeFilmGrain` + computed_colors + steering doc update. Issue #13. Dependencies: design-system-foundation. ✅ implemented + GO.
- [x] **design-system-atoms** — 13 atoms (Brand, Chip, Poster, GenreTabs, etc.) + golden tests. Issue #14. Dependencies: design-system-foundation, perf-safe-widgets. ✅ implemented + GO.

### Wave 1 — Primary screens (parallel-capable после Wave 0)

- [x] **home-cinematic-redesign** — Cinematic A с двойным rail, italic display, live эфир. Issue #5. Dependencies: design-system-foundation, perf-safe-widgets, design-system-atoms. ✅ implemented + GO (5.4 rollout flag flip deferred for manual TV smoke).
- [ ] **detail-screen-fullbleed** — Full-bleed Card с action row, hero transition, cast avatars. Issue #7. Dependencies: design-system-foundation, perf-safe-widgets, design-system-atoms. 📋 spec ready_for_implementation.
- [x] **player-cinematic-redesign** — channel deck, inline EPG, glass-panel controls. Issue #8. Dependencies: design-system-foundation, perf-safe-widgets, design-system-atoms; **does not modify** sealed `PlayerUiState`. ✅ implemented + GO (4.3/4.5 manual TV smoke deferred).
- [ ] **settings-redesign** — sidebar nav + 6 sections + live perf metrics + custom toggles. Issue #11. Dependencies: design-system-foundation, perf-safe-widgets, design-system-atoms. 📋 spec ready_for_implementation.

### Wave 2 — Big new screens (sequential, требует backend extensions)

- [ ] **epg-screen** — time-grid programme guide. Issue #9. Dependencies: design-system-foundation, perf-safe-widgets, design-system-atoms; **may extend `lib/core/epg/*` data layer**. 📋 spec ready_for_implementation.
- [ ] **search-screen** — TV-grade поиск с 6×6 кириллической клавиатурой. Issue #10. Dependencies: design-system-foundation, perf-safe-widgets, design-system-atoms; **may extend `lib/core/api/api_client.dart`** (`searchChannels`). 📋 spec ready_for_implementation.

### Wave 3 — Optional / lower-priority

- [ ] **home-editorial-redesign** — Editorial B (bento grid). Issue #6. Dependencies: home-cinematic-redesign (sibling); user не сделал explicit выбор Editorial vs Cinematic. 📋 spec ready_for_implementation.
- [ ] **mobile-adaptive-layout** — 3 mobile screens + tabbar. Issue #12. Dependencies: home-cinematic-redesign, detail-screen-fullbleed, player-cinematic-redesign (нужны TV equivalents). 📋 spec ready_for_implementation.

## Pilot strategy

Для **первого end-to-end pilot** через `/kiro-impl` рекомендуется выбрать **`design-system-foundation` (issue #4)**:
- Нет user-visible изменений (purely infrastructure refactor).
- Закрытые специй продолжают работать через aliases.
- Покрывает 90% theming-вопросов для всех остальных спеков.
- Effort: **M** (2-3 дня).

После pilot foundation готов — Wave 1 batch может стартовать параллельно.
