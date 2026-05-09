# Brief: detail-screen-fullbleed

## Source
GitHub Issue [#7](https://github.com/Romaxa55/MegaV-IPTV/issues/7) — read the issue body for full context (Симптом, Текущее поведение, Желаемое поведение, Boundary, Performance constraints, etc.).

To fetch issue body programmatically: `gh issue view 7`.

## Issue body (synced from GH)

## Симптом
Карточка канала / детальный экран отсутствует во Flutter. Дизайн представляет 3 варианта (Full-bleed / Split / Minimal). User explicit choice (chat1.md): **«карточка номер один круче»** — Full-bleed; Split вариант признан ненужным («EPG в split-варианте бесполезна когда программа только началась»).

## Текущее поведение
- При тапе на плитку в home → `context.push('/player')` (см. `home_screen.dart:235`).
- **Промежуточного detail-экрана нет.**

## Желаемое поведение (из дизайна)
Эталоны:
- [`detail.jsx`](.kiro/design/megav-iptv-handoff/project/screens/detail.jsx) (170 строк, v1)
- [`detail-variants.jsx`](.kiro/design/megav-iptv-handoff/project/screens/detail-variants.jsx) (3 варианта)
- [`MegaV IPTV - Card v1.html`](.kiro/design/megav-iptv-handoff/project/MegaV%20IPTV%20-%20Card%20v1.html)

### Variant A (Full-bleed) — финальный
- Full-bleed video poster background.
- Hero meta bottom-left: italic display 96px title + meta row + summary.
- Action row: [Play/Fav/Trailer/EPG/More] с focus-ring D-pad.
- Hero shared element transition (badge `HERO TRANSITION ↗`).

### Compositions
- `Poster`, `Chip`, italic 96px display title, mono 12px caps meta
- Cast avatars (radial gradient circles 36×36)
- `mv-track` (live progress)
- Action button row (5 actions)

## Diff scope
**new** — net-new screen.

## Boundary candidates
- `lib/features/detail/detail_screen.dart` (NEW)
- `lib/features/detail/widgets/hero_meta.dart` (NEW)
- `lib/features/detail/widgets/action_row.dart` (NEW)
- `lib/features/detail/widgets/cast_avatars.dart` (NEW)
- Router: insert `/channel/:id` between `/` and `/player`.

## Out of boundary
- Variants B (Split) и C (Minimal) — user отверг Split, Minimal — низкий приоритет.
- Player (issue #8).

## Adjacent expectations
- Hero shared element с home → detail должен использовать Flutter `Hero` widget, не custom transition.
- D-pad focus row sealed-state-machine pattern (как в plyr-overlay).

## Performance constraints
- Full-bleed background image — pre-blur server-side или single-shot blur.
- `text-shadow blur 18px` на title → drop до 8 (steering doc rule).

## Estimated effort
**M** — 3-5 дней. Один новый screen + atoms + Hero transition.

## Action
```
/kiro-discovery detail-screen-fullbleed
```

## Related
- Blocked-by: #4 (theming)
- Connects: #5 (home tap entry) + #8 (Play action → player)


---

## Authoritative references for this spec

- This brief — high-level context.
- GitHub issue #7 — primary discussion / status.
- `.kiro/design/megav-iptv-handoff/` — handoff bundle (HTML + JSX prototypes + themes.css + atoms.jsx).
- `.kiro/steering/flutter-tv-perf.md` — proven performance rules (MUST follow).
- `.kiro/steering/roadmap.md` — full project roadmap with dependency graph.
- Closed kiro specs in `.kiro/specs/` (`home-grid-*`, `player-overlay-state-machine`) — do NOT modify, use as foundation.
