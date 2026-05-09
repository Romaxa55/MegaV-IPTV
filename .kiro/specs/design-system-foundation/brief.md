# Brief: design-system-foundation

## Source
GitHub Issue [#4](https://github.com/Romaxa55/MegaV-IPTV/issues/4) — read the issue body for full context (Симптом, Текущее поведение, Желаемое поведение, Boundary, Performance constraints, etc.).

To fetch issue body programmatically: `gh issue view 4`.

## Issue body (synced from GH)

## Симптом
После handoff от Claude Design проект получил полную дизайн-систему: 6 swappable палитр (Plum/Ivory/**Cobalt**/Pitch/Crimson/Modern), 6 шрифтовых пар (cinema/russian/brutalist/geologica/modern/editorial), новый набор radius-токенов и атомов. Текущая Flutter-реализация имеет один `static const AppColors`, единственный шрифт Inter и нет `AppRadius` класса. Без миграции theming-инфраструктуры все остальные screen-redesign issues #5-#11 не смогут применить design verbatim.

User explicit choice (chat1.md): **default Noir Cobalt** (синий нуар) + опциональный Crimson Reel; для русской локали `font-cinema` (Cormorant Garamond + Golos Text + JetBrains Mono).

## Текущее поведение
- `lib/core/theme/app_colors.dart` — один `static const` palette, `background = #08080F`, `primary = #6366F1`, `textPrimary = #FFFFFF`. Не поддерживает runtime swap.
- `lib/core/theme/app_theme.dart` — `GoogleFonts.inter()` для всего; нет italic display, нет mono.
- `lib/features/home/widgets/_grid_tokens.dart` — содержит `gapDp/horizontalPaddingDp/focusBorderWidth/durations/curves` но не radius.
- `pubspec.yaml` — `google_fonts` уже подключён, новых пакетов не нужно.

## Желаемое поведение (из дизайна)
Эталоны:
- [`themes.css`](.kiro/design/megav-iptv-handoff/project/themes.css) — 6 палитр + 6 шрифтовых пар.
- [`styles.css`](.kiro/design/megav-iptv-handoff/project/styles.css) — radius xs/sm/md/lg/xl, button styles, mv-* atoms.

### Палитра Noir Cobalt (default)
| Token | Value |
|---|---|
| `--bg` | `#06060A` (vs наш `#08080F` — drift 3pt, можно sync или оставить) |
| `--bg-warm` | `#0A0809` (NEW) |
| `--surface` | `#0F0F14` (vs наш `#12121E`) |
| `--surface-2` | `#15151C` (vs наш `#1A1A2E` — расхождение, наш более фиолетовый) |
| `--line` | `rgba(255,240,220,0.08)` (warm cream tint, NEW) |
| `--line-strong` | `rgba(255,240,220,0.16)` (NEW) |
| `--text` | `#F4F1E9` (warm cream, vs наш `#FFFFFF` — **brand-defining drift**) |
| `--text-dim` | `rgba(244,241,233,0.62)` |
| `--text-mute` | `rgba(244,241,233,0.38)` |
| `--accent` | `#6E56F7` (vs наш `#6366F1` — close, ΔE~5) |
| `--accent-glow` | `rgba(110,86,247,0.45)` (NEW) |
| `--accent-soft` | `rgba(110,86,247,0.16)` (NEW) |
| `--gold` | `#E8B96A` (NEW, brass) |
| `--gold-soft` | `rgba(232,185,106,0.16)` (NEW) |
| `--live` | `#FF3B5C` (vs `#EF4444`, более pink-coral) |
| `--live-soft` | `rgba(255,59,92,0.18)` (NEW) |
| `--good` | `#22D3A8` (close to `#00B894`) |

### Шрифты для RU локали (`font-cinema`)
- Display / italic (`Cormorant Garamond`) — кириллицу поддерживает.
- UI body (`Golos Text`) — built for cyrillic, **без italic** в EPG (user explicit).
- Mono / metadata (`JetBrains Mono`) — uppercase, letter-spacing 0.08–0.32em.
- **Сейчас Inter везде** — потерян editorial/cinematic feel.

### Radius scale
- `--r-xs: 6px`, `--r-sm: 10px`, `--r-md: 14px` (vs наш 12px), `--r-lg: 20px`, `--r-xl: 28px`. Нет `AppRadius` класса.

### Theme switching
- Нужен `ThemePalette` через Riverpod вместо `static const`.
- Default: Noir Cobalt. Доступны: Plum, Ivory, Cobalt, Pitch, Crimson, Modern.
- User управляет через Settings v2 (issue #10).

## Diff scope
**restructure** — `app_colors.dart` рефакторится из `static const` → instance-class через provider; добавляется `AppRadius`; `app_theme.dart` переделывается под `font-cinema` для RU. Это **prerequisite** для всех остальных screen-issues.

## Boundary candidates
- `lib/core/theme/app_colors.dart` (rewrite as palette class + provider)
- `lib/core/theme/app_radius.dart` (NEW)
- `lib/core/theme/app_palettes.dart` (NEW — 6 palette definitions)
- `lib/core/theme/app_theme.dart` (font-cinema setup)
- `lib/core/theme/theme_provider.dart` (NEW — Riverpod provider for current palette)
- `lib/features/home/widgets/_grid_tokens.dart` — может потерять часть токенов в пользу `AppRadius`

## Out of boundary
- Любые screen-implementations (отдельные issues #5-#11).
- Native player engines.
- Закрытые специй (`home-grid-*`, `player-overlay-*`) — не трогать; токены замапятся через alias.

## Adjacent expectations
- Существующие 30 тестов должны продолжать проходить — ломать существующий API `AppColors.primary/background/etc` нельзя без alias.
- Цветовые ссылки в `cinema_card.dart`, `cinema_row.dart`, `_card_poster.dart`, `home_screen.dart`, `player_screen.dart` остаются валидными (через aliases).

## Performance constraints
- Theme switch через provider — runtime cost минимальный (rebuilds через `Consumer`/`ref.watch`).
- Никаких new performance-conflicts.

## Estimated effort
**M** — 2-3 дня. Refactor + 6 palette definitions + font setup + tests.

## Action когда дойдут руки
```
/kiro-discovery design-system-foundation
```

## Related
- Design bundle files: themes.css, styles.css, atoms.jsx
- Closed specs: `home-grid-optimization`, `home-grid-visual-polish`, `player-overlay-state-machine` (все требуют валидных color aliases)
- Blocks: issues #5-#11 (все screen-redesigns зависят от theming)


---

## Authoritative references for this spec

- This brief — high-level context.
- GitHub issue #4 — primary discussion / status.
- `.kiro/design/megav-iptv-handoff/` — handoff bundle (HTML + JSX prototypes + themes.css + atoms.jsx).
- `.kiro/steering/flutter-tv-perf.md` — proven performance rules (MUST follow).
- `.kiro/steering/roadmap.md` — full project roadmap with dependency graph.
- Closed kiro specs in `.kiro/specs/` (`home-grid-*`, `player-overlay-state-machine`) — do NOT modify, use as foundation.
