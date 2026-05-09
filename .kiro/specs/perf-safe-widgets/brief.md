# Brief: perf-safe-widgets

## Source
GitHub Issue [#13](https://github.com/Romaxa55/MegaV-IPTV/issues/13) — read the issue body for full context (Симптом, Текущее поведение, Желаемое поведение, Boundary, Performance constraints, etc.).

To fetch issue body programmatically: `gh issue view 13`.

## Issue body (synced from GH)

## Симптом
Handoff bundle от Claude Design содержит 7 design choices которые **прямо нарушают** наш steering doc `.kiro/steering/flutter-tv-perf.md` (proven optimization rules от 3 закрытых спеков, измеренные на референсном TV `rtd2851a`). Без явных mitigations при имплементации — **гарантированный регресс perf** на TV-боксе («сильно тормозит» — главный pain пользователя).

Этот issue — **meta-spec** который определяет **safe replacements** для каждого конфликта. Все остальные screen-issues (#5-#12) ссылаются на этот issue и используют замены отсюда вместо verbatim CSS.

## 7 конфликтов (полный список из intake report)

### Conflict 1: `mv-grain` SVG film grain (FATAL)
```css
.mv-grain::after {
  background-image: url("data:image/svg+xml...feTurbulence...");
  mix-blend-mode: overlay;
}
```
Cost: full-screen `mix-blend-mode: overlay` = saveLayer per frame, **3-6 ms** на Mali. Применять на scrolling rows = 21 fps.

**Safe replacement**:
- (a) Bake static asset `assets/grain.png` (1024×1024 PNG с pre-applied noise+overlay), draw with `Opacity(0.08)`. Pure alpha, no blend mode. Pay cost once.
- (b) Apply ONLY to static layers (boot overlay, hero backdrop). Never on scrolling content.

### Conflict 2: `mv-backdrop blur(40px)` (FATAL для idle)
```css
.mv-backdrop .layer { filter: blur(40px) saturate(1.2); transform: scale(1.15); }
```
Steering rule: **blur > 12 запрещён** (доказано в `home-grid-visual-polish` ShaderMask regression).

**Safe replacement**:
- (a) Pre-render: при смене hero artwork, render 1 раз через `RepaintBoundary.toImage()` + `ImageFilter.blur(40, 40)` → save as `ui.Image` → display as static `Image`. Pay cost once per artwork change.
- (b) Server-side: ask CDN imgproxy для pre-blurred artwork URL.
- (c) Tiny image upscale: load 20×30 image, let GPU upscale to fullscreen — gaussian-equivalent cheap blur.

### Conflict 3: `backdrop-filter: blur` на pills/icon buttons (CATASTROPHIC поверх video)
```css
.mv-statusbar { backdrop-filter: blur(20px); }
.mv-iconbtn { backdrop-filter: blur(16px); }
```
Steering rule: **`BackdropFilter` поверх Texture-видео — категорически нет**. Дороже ShaderMask.

**Safe replacement**:
- Replace with **opaque-tint translucent fill**: `Color.fromRGBO(20, 20, 26, 0.85)` instead of `rgba(20,20,26,0.55) + blur(20px)`.
- Visually slightly less premium ("flat dark pill" vs "frosted pill") но **mandatory** для TV. На mobile (issue #12) backdrop filter **OK** — там Mali не bottleneck.

### Conflict 4: Multiple stacked gradients над hero video
```css
/* hero composition: 3 stacked gradients */
- vignette radial gradient
- bottom-shade linear gradient
- side-fade linear gradient
```
Cost: 3-5 ms / frame. Steering rule: **свести в один**.

**Safe replacement**:
- Combine vignette + bottom-shade в один `RadialGradient` с custom `stops` и `Alignment.bottomCenter`.
- Side-fade убрать или использовать одинаковый цвет фона как natural padding.

### Conflict 5: `outline-offset: 3px` focus ring
```css
.mv-poster.focus { outline: 3px solid var(--accent); outline-offset: 3px; }
```
Flutter `Container.decoration.border` рисует **inside** the box. Outline-offset = 3px gap **outside**.

**Safe replacement**:
- Use `BoxShadow(spreadRadius: 3, blurRadius: 0, color: AppColors.accent)` — рисует solid ring **outside** box. `blurRadius: 0` — это **не blur**, не триггерит rule «blur > 12». Visually identical to CSS outline-offset.

### Conflict 6: `color-mix(in oklab, ...)` (build-time issue, not perf)
```css
.mv-btn.primary:hover { background: color-mix(in oklab, var(--text) 92%, var(--accent) 8%); }
```
Dart Color не имеет equivalent.

**Safe replacement**:
- Pre-compute mixed colors at design-token import time. Effectively give us `text_accent_8 = Color(0x...)`, `text_accent_tint = Color(0x...)` as static constants.
- Issue #4 (theming foundation) генерирует этот static lookup table.

### Conflict 7: `text-shadow blur 18px` на section titles (REGRESSION)
```css
.section-title { text-shadow: 0 2px 18px rgba(0,0,0,0.55); }
```
Steering rule: **blur > 12 запрещён**. Section titles scroll → re-rasterize per frame.

**Safe replacement**:
- Drop to `Shadow(blurRadius: 8, ...)` — visually 90% identical, perf-safe.

## Эстраграция
Конфликты #5 и #6 не perf, а build-pattern issues. Группирую сюда для единого спека замен.

## Diff scope
**design-system spec** — определяет helper-utilities, не меняет существующий код. Implementation в каждом dependent spec'е происходит когда этот спек закрыт.

## Boundary candidates
- `lib/core/perf/perf_safe_widgets.dart` (NEW) — `SafeBackdrop`, `SafePill`, `SafeFocusRing`, `SafeFilmGrain` widgets.
- `assets/grain_overlay.png` (NEW asset).
- `lib/core/theme/computed_colors.dart` (NEW) — pre-mixed color constants.
- Documentation updates: `.kiro/steering/flutter-tv-perf.md` дополнить design-handoff conflicts section.

## Out of boundary
- Existing closed specs — не меняем (alias только если нужно).
- Mobile-specific: backdrop filter OK на mobile, perf-conflict только TV.

## Adjacent expectations
- Все остальные dependent issues (#5-#12) **должны импортировать** safe replacements отсюда вместо direct CSS-translation.
- Steering doc дополняется новой секцией «Design handoff conflicts → safe replacements» как single source of truth.

## Performance constraints
- Этот спек **существует чтобы соблюдать** existing constraints.

## Estimated effort
**M** — 3-4 дня. 4 widget'а + 1 asset + computed colors generator + steering doc update.

## Action
```
/kiro-discovery design-handoff-perf-mitigations
```

**HIGH PRIORITY** — должен быть закрыт **до** начала любого screen-redesign issue. Иначе каждый dependent спек придётся перепиливать на этапе validate-impl.

## Related
- Blocked-by: #4 (theming foundation)
- Blocks: #5, #6, #7, #8, #9, #10, #11 (все screen-redesigns)
- Steering: `.kiro/steering/flutter-tv-perf.md`


---

## Authoritative references for this spec

- This brief — high-level context.
- GitHub issue #13 — primary discussion / status.
- `.kiro/design/megav-iptv-handoff/` — handoff bundle (HTML + JSX prototypes + themes.css + atoms.jsx).
- `.kiro/steering/flutter-tv-perf.md` — proven performance rules (MUST follow).
- `.kiro/steering/roadmap.md` — full project roadmap with dependency graph.
- Closed kiro specs in `.kiro/specs/` (`home-grid-*`, `player-overlay-state-machine`) — do NOT modify, use as foundation.
