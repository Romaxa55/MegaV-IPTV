# Brief: home-cinematic-redesign

## Source
GitHub Issue [#5](https://github.com/Romaxa55/MegaV-IPTV/issues/5) — read the issue body for full context (Симптом, Текущее поведение, Желаемое поведение, Boundary, Performance constraints, etc.).

To fetch issue body programmatically: `gh issue view 5`.

## Issue body (synced from GH)

## Симптом
Главный экран сейчас показывает «продолжить смотреть», но это **IPTV, не VOD** — нужно показывать что **сейчас идёт в эфире**. User explicit: «не сможем продолжить смотреть ты это по коду гита должен был понять» (chat1.md).

## Текущее поведение
- `lib/features/home/home_screen.dart` (404 строки) — Hero + ListView категорий + boot overlay + preview-видео.
- `lib/features/home/widgets/cinema_row.dart`, `cinema_card.dart`, `_card_poster.dart`, `_grid_tokens.dart` — закрытые специй `home-grid-optimization` + `home-grid-visual-polish`. Adaptive 3/4/5 cols, scale-only фокус, fade-edge, compact/full overlay split.
- Visual: чёрный фон, фиолетовый primary, кадры каналов с overlay'ями.

## Желаемое поведение (из дизайна)
Эталоны:
- [`home-cinematic.jsx`](.kiro/design/megav-iptv-handoff/project/screens/home-cinematic.jsx) (134 строки)
- [`cinematic-v2.jsx`](.kiro/design/megav-iptv-handoff/project/cinematic-v2.jsx) (348 строк) — версия с реальным data-flow.
- [`MegaV IPTV - Полный обзор.html`](.kiro/design/megav-iptv-handoff/project/MegaV%20IPTV%20-%20Полный%20обзор.html)

### Ключевые визуальные изменения
- Italic Bitter/Cormorant display titles `clamp(56–120px)` — `var(--font-display)` везде.
- Genre tabs: chip-strip с active-pill + count, mask-image fade-edges по краям.
- **Двойной rail**:
  - Continue rail: 300×170 landscape posters, hideText=true.
  - Now-on-air rail: 220×300 portrait, hideText=true.
- Backdrop: `mv-grain` + `mv-vignette` + radial accent-soft glow (видео плеера на фоне).
- RemoteHint footer: keycap-pills row (←→ ↑↓ OK BACK).
- Live progress bar (`mv-track`) с glow knob + ticks.
- Active rail bento: 1 large 460×300 + 5 maller 240×300.
- Movies row: 220×300 fixed.

### Layout grid
- **Conflict**: design использует фиксированные пиксельные ширины (`flex: "0 0 240px"`), не breakpoint-based `pickColumns 3/4/5`.
- **Решение**: сохраняем `pickColumns` как source of truth, но adapt aspect-ratios (landscape 16:9 vs portrait 2:3) под design.
- Continue rail = landscape 16:9, Now-on-air rail = portrait 2:3.

## Diff scope
**restructure** (cosmetic-heavy + 1 новая концепция «двойной rail»). Существующая модель focus + scroll + debounce остаётся.

## Boundary candidates
- `lib/features/home/home_screen.dart` (modify — добавить editorial masthead)
- `lib/features/home/widgets/cinema_row.dart` (modify — поддержка landscape/portrait aspect через row-level prop)
- `lib/features/home/widgets/cinema_card.dart` (modify — `hideText: true` режим без compact-overlay)
- `lib/features/home/widgets/genre_tabs.dart` (NEW)
- `lib/features/home/widgets/section_title.dart` (NEW)
- `lib/features/home/widgets/remote_hint.dart` (NEW)
- `lib/features/home/widgets/_grid_tokens.dart` (extend with aspectRatio toggle)

## Out of boundary
- **Не трогать** sealed `PlayerUiState` (issue #8 — отдельный спек).
- **Не возвращать** `BoxShadow.blurRadius=50` или `ShaderMask` (steering doc запрещает).
- Native player engines.
- Editorial layout (issue #5b — отдельный спек, см. ниже).

## Adjacent expectations
- Adaptive `pickColumns` 3/4/5 сохраняется (issue #4 → theming не должно ломать).
- `flutter-tv-perf.md` правила обязательны.
- Все 30 текущих тестов проходят без модификаций.

## Performance constraints (CRITICAL)
**Конфликты с steering doc**:
1. `mv-grain` SVG film-grain via `mix-blend-mode: overlay` — **fatal** на Mali. Митигация: bake static asset PNG, использовать только на boot/hero backdrop.
2. `mv-backdrop` blur(40px) — наш `flutter-tv-perf.md` запрещает blur > 12. Митигация: pre-render через `RepaintBoundary.toImage()` или CDN-pre-blur.
3. Multiple stacked gradients над hero video — свести в один `RadialGradient`.
4. Re-introducing `boxShadow blur` для focus glow — **запрещено** (регрессит home-grid spec Req 9.4).

## Estimated effort
**M** — 3-5 дней. Cosmetic refresh + двойной rail + genre-tabs + remote-hint.

## Action когда дойдут руки
```
/kiro-discovery home-cinematic-redesign
```
**ВАЖНО**: depends on issue #4 (theming) и #12 (perf-mitigations). Не запускать до них.

## Related
- Closed: `home-grid-optimization`, `home-grid-visual-polish` (визуальный язык наследуем, токены менять через #4)
- Blocked-by: #4, #12


---

## Authoritative references for this spec

- This brief — high-level context.
- GitHub issue #5 — primary discussion / status.
- `.kiro/design/megav-iptv-handoff/` — handoff bundle (HTML + JSX prototypes + themes.css + atoms.jsx).
- `.kiro/steering/flutter-tv-perf.md` — proven performance rules (MUST follow).
- `.kiro/steering/roadmap.md` — full project roadmap with dependency graph.
- Closed kiro specs in `.kiro/specs/` (`home-grid-*`, `player-overlay-state-machine`) — do NOT modify, use as foundation.
