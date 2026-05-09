# Brief: epg-screen

## Source
GitHub Issue [#9](https://github.com/Romaxa55/MegaV-IPTV/issues/9) — read the issue body for full context (Симптом, Текущее поведение, Желаемое поведение, Boundary, Performance constraints, etc.).

To fetch issue body programmatically: `gh issue view 9`.

## Issue body (synced from GH)

## Симптом
EPG (электронный программный гид) **отсутствует** во Flutter. Нет ни экрана, ни виджета. User в chat явно работал над EPG: правил шрифт (Bitter → **Golos Text**), убирал курсив, расширял слоты до **180px/30мин**, переносил NOW-маркер «в начало а не в середину», менял `8-часовое окно` (chat1.md).

## Текущее поведение
- `lib/features/player/widgets/epg_overlay.dart` — overlay внутри плеера, показывает программы текущего канала (1D).
- Полноэкранный EPG (channels × time grid) **не существует**.

## Желаемое поведение (из дизайна)
Эталон: [`epg-v2.jsx`](.kiro/design/megav-iptv-handoff/project/screens/epg-v2.jsx) (549 строк).

### Layout
- Header: italic display 56px «Программа передач» + DayPicker (-2..+4 дня).
- Filter row: category pills (Все / Кино / Спорт / Новости / etc.).
- Main area: 2-col grid:
  - Channel column: `CH_W = 240px`, каждая ячейка = 38×38 colored badge + name + groupTitle.
  - Time grid: scrollable horizontal, **10 slots × 30 min = 5h window**.
- Slot dimensions: `SLOT_W = 180px`, `ROW_H = 88px`.
- **NOW marker**: vertical accent line + label, в **начале** видимого окна (не в середине).
- Preview strip снизу: sticky, 132×76 thumbnail + meta + actions.

### D-pad navigation
- ←→ time (через слоты программы)
- ↑↓ channel (через ряды)
- OK = открыть детали программы или переключиться на канал
- Auto-scroll: фокус всегда в viewport с padding 80px.
- Row-change snaps col to live-program index.

### Typography
- **Golos Text 14px / weight 500** для названий программ.
- **Без курсива** (user explicit).
- Mono для timestamps.

## Diff scope
**new** — XL net-new screen с virtualised time-grid + D-pad nav + data layer.

## Boundary candidates
- `lib/features/epg/epg_screen.dart` (NEW)
- `lib/features/epg/widgets/day_picker.dart` (NEW)
- `lib/features/epg/widgets/category_filter.dart` (NEW)
- `lib/features/epg/widgets/channel_cell.dart` (NEW)
- `lib/features/epg/widgets/program_cell.dart` (NEW)
- `lib/features/epg/widgets/now_marker.dart` (NEW)
- `lib/features/epg/widgets/preview_strip.dart` (NEW)
- `lib/core/epg/epg_data_provider.dart` (probably NEW or extend) — `loadEpgWindow(start, end, category?)`
- Router: `/epg` route entry.

## Out of boundary
- `epg_overlay.dart` внутри плеера (issue #8 — там она inline).
- Player.

## Adjacent expectations
- Использует `Channel` model + EPG model из `lib/core/playlist/models/`.
- API endpoint `/api/epg/...` (предположительно расширяется для batch fetch).
- D-pad model совместима с sealed-state-machine pattern (как в `player-overlay-state-machine`).

## Performance constraints
- **Virtualised time-grid**: 100+ каналов × 50+ слотов = 5000+ cells. Без virtualisation — фриз.
  - Use `ListView.builder` (axis vertical) внутри которого `ListView.builder` (axis horizontal) — стандартный 2D virtualised pattern.
  - cacheExtent: 800-1000px.
- NOW marker `boxShadow: 0 0 18px var(--accent-glow)` — drop blur ≤ 12.
- ProgramCell `transition: background .14s, transform .14s` — OK, GPU.
- Focused row `translateY(-1px)` — OK.

## Estimated effort
**XL** — 7-10 дней. Один из самых больших спеков.

## Action
```
/kiro-discovery epg-screen
```

## Related
- Blocked-by: #4 (theming), `lib/core/epg/*` data layer (existing)
- Sibling: #8 (player has inline mini-EPG; this is полноэкранный)


---

## Authoritative references for this spec

- This brief — high-level context.
- GitHub issue #9 — primary discussion / status.
- `.kiro/design/megav-iptv-handoff/` — handoff bundle (HTML + JSX prototypes + themes.css + atoms.jsx).
- `.kiro/steering/flutter-tv-perf.md` — proven performance rules (MUST follow).
- `.kiro/steering/roadmap.md` — full project roadmap with dependency graph.
- Closed kiro specs in `.kiro/specs/` (`home-grid-*`, `player-overlay-state-machine`) — do NOT modify, use as foundation.
