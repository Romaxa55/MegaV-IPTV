# Brief: home-editorial-redesign

## Source
GitHub Issue [#6](https://github.com/Romaxa55/MegaV-IPTV/issues/6) — read the issue body for full context (Симптом, Текущее поведение, Желаемое поведение, Boundary, Performance constraints, etc.).

To fetch issue body programmatically: `gh issue view 6`.

## Issue body (synced from GH)

## Симптом
В дизайне есть **альтернативная** версия главного экрана — `home-editorial.jsx`. Это **бенто-grid-вариант** для пользователей которым нравится плотная газетная подача (vs. cinematic full-bleed). User не сделал явного финального выбора между Cinematic и Editorial — Cinematic был помечен как "вариант а нравится", но Editorial остался в Полном обзоре как opt-in.

## Текущее поведение
- Editorial layout **отсутствует** во Flutter — все home-screen работы шли по cinematic линии.

## Желаемое поведение (из дизайна)
Эталон: [`home-editorial.jsx`](.kiro/design/megav-iptv-handoff/project/screens/home-editorial.jsx) (228 строк).

### Layout
- **Editorial masthead**: «Главная сегодня · 9 МАЯ 2026 · ВЫПУСК №127» — газетный заголовок.
- 2-col grid `auto 1fr`: portrait poster `Poster 420×620` + meta (дата, заголовки, summary).
- GenreTabs снизу masthead.
- **Bento grid**: `repeat(6, 1fr)` rows-220, cards с разными `cols/rows` (1×1, 1×2, 2×1, 2×2).
- Film-reel strip: 18 frames 16:9 horizontally scrolled (`mv-strip`).

### Compositions
- `Poster` (portrait и landscape)
- `SideCard`, `BentoCard` — разной разметки внутри bento.
- `Chip` (live/brand/gold) на cards.
- `mv-strip` (CSS-defined film-reel scroller).

## Diff scope
**new** — net-new screen, никакого конфликта с cinematic (это отдельная страница / альтернативный маршрут).

## Boundary candidates
- `lib/features/home/home_editorial_screen.dart` (NEW — альтернативный entry point)
- `lib/features/home/widgets/editorial_masthead.dart` (NEW)
- `lib/features/home/widgets/bento_grid.dart` (NEW)
- `lib/features/home/widgets/film_reel_strip.dart` (NEW)
- Routing: добавить toggle в Settings (issue #10) или в Header.

## Out of boundary
- Cinematic home (issue #5 — отдельный спек).
- Player / EPG / Search / Settings.

## Adjacent expectations
- Совместимо с `pickColumns` (мобильный rotates → 3 cols, на TV 4-6).
- Использует те же atoms что #5 (Genre, Poster, Chip).

## Performance constraints
- Bento grid с фотографиями — будет много image decodes. Нужен `cached_network_image` или серверный imgproxy.
- Параллакс / ken-burns на masthead poster — **только** static crop, не video.

## Estimated effort
**L** — net-new screen, 5-7 дней.

## Action
```
/kiro-discovery home-editorial-screen
```
**Lower priority** — после Cinematic (#5). User не сделал explicit выбор; делать opt-in.

## Related
- Blocked-by: #4 (theming)
- Sibling-of: #5 (cinematic home)


---

## Authoritative references for this spec

- This brief — high-level context.
- GitHub issue #6 — primary discussion / status.
- `.kiro/design/megav-iptv-handoff/` — handoff bundle (HTML + JSX prototypes + themes.css + atoms.jsx).
- `.kiro/steering/flutter-tv-perf.md` — proven performance rules (MUST follow).
- `.kiro/steering/roadmap.md` — full project roadmap with dependency graph.
- Closed kiro specs in `.kiro/specs/` (`home-grid-*`, `player-overlay-state-machine`) — do NOT modify, use as foundation.
