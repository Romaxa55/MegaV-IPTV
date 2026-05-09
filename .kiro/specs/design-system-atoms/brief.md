# Brief: design-system-atoms

## Source
GitHub Issue [#14](https://github.com/Romaxa55/MegaV-IPTV/issues/14) — read the issue body for full context (Симптом, Текущее поведение, Желаемое поведение, Boundary, Performance constraints, etc.).

To fetch issue body programmatically: `gh issue view 14`.

## Issue body (synced from GH)

## Симптом
Дизайн вводит **9 новых атомов** (`Brand`, `StatusBar`, `Chip`, `MMLogo`, `GenreTabs`, `SectionTitle`, `RemoteHint`, `mv-track`, `mv-strip`, `mv-key`) которые переиспользуются между всеми screen-redesigns (#5-#12). Без centralized atoms package каждый screen-spec будет копировать widgets, и любой change в визуальном языке потребует касаться 7 файлов.

## Текущее поведение
- Существующие cross-cutting widgets разбросаны по `lib/features/*/widgets/`.
- Нет `lib/core/ui/atoms/` или `design_system/` директории.
- Кнопки реализованы только частично (`glass_button.dart` ≈ ghost variant).

## Желаемое поведение (из дизайна)
Эталоны:
- [`atoms.jsx`](.kiro/design/megav-iptv-handoff/project/atoms.jsx) (149 строк) — все base atoms.
- [`styles.css`](.kiro/design/megav-iptv-handoff/project/styles.css) — `mv-btn` (3 variants), `mv-iconbtn`, `mv-track`, `mv-strip`, `mv-key`, `mv-grain`, `mv-vignette`, `mv-backdrop`.

### Список новых atoms
1. **Brand** — мини-логотип (gradient square + cutout + bar) + wordmark.
2. **StatusBar** — city/temp/time pill с flag (упрощённая версия).
3. **Chip** unified — variants: `live`, `brand`, `gold`, `ghost`, default.
4. **Poster** — landscape & portrait variants, hideText opt, badge slots TL/TR, progress bar.
5. **MMLogo** — small "M" channel badge (38×38).
6. **GenreTabs** — horizontal tab strip с underline-on-active.
7. **SectionTitle** — H3 + italic em + count + "more →".
8. **RemoteHint** — keycap pills row (стрелки/OK/BACK).
9. **mv-btn** primary / ghost / accent — 3 variants + sizes.
10. **mv-iconbtn** — 38×38 rounded icon button.
11. **mv-track** — progress bar с glow knob (для контента, EPG, settings).
12. **mv-strip** — filmstrip frames (для editorial home).
13. **mv-key** — keycap (single key visual для RemoteHint).

### Existing widgets для рефакторинга (alignment)
- `glass_button.dart` → переименовать в `MvButton.ghost`, добавить `.primary` и `.accent` variants.
- `_card_poster.dart` → align styling с design `Poster` atom (уже content-equivalent).
- `channel_quality_badge.dart` → консолидировать в `Chip` unified.
- `hero_badges.dart` → split на `Chip` + `MMLogo`.

## Diff scope
**design-system spec** — net-new directory + refactor 4 existing widgets. Не trivially merge with theming spec #4 чтобы избежать XL спека.

## Boundary candidates
- `lib/core/ui/atoms/` (NEW directory):
  - `brand.dart`, `status_bar.dart`, `chip.dart`, `poster.dart`, `mm_logo.dart`, `genre_tabs.dart`, `section_title.dart`, `remote_hint.dart`, `mv_button.dart`, `mv_icon_button.dart`, `mv_track.dart`, `mv_strip.dart`, `mv_key.dart`.
- Refactor: `glass_button.dart` → wrapper для legacy callers, deprecation note.
- Refactor: `channel_quality_badge.dart` → use `Chip` underneath.

## Out of boundary
- Screen-level layouts (issues #5-#12).
- Theming infrastructure (issue #4) — но atoms используют theme tokens отсюда.

## Adjacent expectations
- Atoms должны быть pure-presentation, не имеют bizz logic.
- Каждый atom test: golden test + unit test для variants.
- API stable — добавление variant'ов через named ctor `MvButton.primary({...})`.

## Performance constraints
- Atoms используют `const` constructors где возможно.
- `Chip` с `live` variant имеет `_pulse` animation — обёрнут в `RepaintBoundary` (steering doc rule).
- `mv-track` (progress bar) — animates `widthFactor`, не layout.

## Estimated effort
**L** — 5-7 дней. 13 atoms + golden tests + refactor 4 existing.

## Action
```
/kiro-discovery design-system-atoms
```

## Related
- Blocked-by: #4 (theming) + #13 (perf-safe widgets)
- Blocks: #5, #6, #7, #8, #9, #10, #11, #12 (все используют atoms)


---

## Authoritative references for this spec

- This brief — high-level context.
- GitHub issue #14 — primary discussion / status.
- `.kiro/design/megav-iptv-handoff/` — handoff bundle (HTML + JSX prototypes + themes.css + atoms.jsx).
- `.kiro/steering/flutter-tv-perf.md` — proven performance rules (MUST follow).
- `.kiro/steering/roadmap.md` — full project roadmap with dependency graph.
- Closed kiro specs in `.kiro/specs/` (`home-grid-*`, `player-overlay-state-machine`) — do NOT modify, use as foundation.
