# Brief: search-screen

## Source
GitHub Issue [#10](https://github.com/Romaxa55/MegaV-IPTV/issues/10) — read the issue body for full context (Симптом, Текущее поведение, Желаемое поведение, Boundary, Performance constraints, etc.).

To fetch issue body programmatically: `gh issue view 10`.

## Issue body (synced from GH)

## Симптом
Поиск **отсутствует** во Flutter. Дизайн предлагает TV-grade поиск с экранной кириллической клавиатурой 6×6 + utility row, для D-pad навигации без physical keyboard.

## Текущее поведение
- Поиск-экрана нет.
- В home-screen нет search-affordance.

## Желаемое поведение (из дизайна)
Эталон: [`search-v2.jsx`](.kiro/design/megav-iptv-handoff/project/screens/search-v2.jsx) (582 строки).

### Layout
- Header: italic display 56px «Найти что-то стоящее» + filter pills (Все / Фильмы / Сериалы / Каналы).
- SearchBar: 32px text + blinking accent caret.
- 2-col body:
  - Left 360px: `KB_ROWS` 6×6 cyrillic + utility row (Пробел / Стереть / RU/EN switch) + recent-queries list.
  - Right 1fr: results.

### Compositions
- TV keyboard 6×6 cells:
  - Row 1: А Б В Г Д Е
  - Row 2: Ё Ж З И Й К
  - Row 3: Л М Н О П Р
  - Row 4: С Т У Ф Х Ц
  - Row 5: Ч Ш Щ Ъ Ы Ь
  - Row 6: Э Ю Я + 3 utility
- `SearchBar` с blinking caret (`@keyframes mvblink`).
- `CountChip × 3` (фильмов / сериалов / каналов).
- `TopResult` 180×256 poster + body с «ЛУЧШИЙ РЕЗУЛЬТАТ» badge.
- `ResultRow` 60×84 mini posters.

### D-pad
- Keyboard navigation через `focusRow / focusCol` (0..5 × 0..5).
- OK на клавише → append char.
- Right arrow от последней колонки → переход в results pane.
- Left arrow от первой колонки в results → возврат в keyboard.

## Diff scope
**new** — net-new screen с TV-keyboard + 2-col layout + results.

## Boundary candidates
- `lib/features/search/search_screen.dart` (NEW)
- `lib/features/search/widgets/tv_keyboard.dart` (NEW — 6×6 cyrillic)
- `lib/features/search/widgets/search_bar.dart` (NEW — text + blinking caret)
- `lib/features/search/widgets/count_chip.dart` (NEW)
- `lib/features/search/widgets/top_result.dart` (NEW)
- `lib/features/search/widgets/result_row.dart` (NEW)
- `lib/core/api/api_client.dart` extension: `searchChannels(query, kind)` если ещё нет.
- Router: `/search`.

## Out of boundary
- Voice search (нет в дизайне).
- Search-suggestions через `prefix` API (опциональная фича — не в scope).

## Adjacent expectations
- Search-affordance в home-screen header (clickable mag-glass icon → push '/search').
- Sealed-state for keyboard focus model.

## Performance constraints
- Blinking caret через `AnimationController` + `RepaintBoundary` — изолированно, не ребилдит whole screen.
- Keyboard 6×6 cells — 36 виджетов. Не страшно.
- Results paginated (initial 20, lazy-load).

## Estimated effort
**L** — 5-7 дней.

## Action
```
/kiro-discovery search-screen
```

## Related
- Blocked-by: #4 (theming)


---

## Authoritative references for this spec

- This brief — high-level context.
- GitHub issue #10 — primary discussion / status.
- `.kiro/design/megav-iptv-handoff/` — handoff bundle (HTML + JSX prototypes + themes.css + atoms.jsx).
- `.kiro/steering/flutter-tv-perf.md` — proven performance rules (MUST follow).
- `.kiro/steering/roadmap.md` — full project roadmap with dependency graph.
- Closed kiro specs in `.kiro/specs/` (`home-grid-*`, `player-overlay-state-machine`) — do NOT modify, use as foundation.
