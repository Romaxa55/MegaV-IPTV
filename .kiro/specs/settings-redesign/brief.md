# Brief: settings-redesign

## Source
GitHub Issue [#11](https://github.com/Romaxa55/MegaV-IPTV/issues/11) — read the issue body for full context (Симптом, Текущее поведение, Желаемое поведение, Boundary, Performance constraints, etc.).

To fetch issue body programmatically: `gh issue view 11`.

## Issue body (synced from GH)

## Симптом
Существующий `settings_screen.dart` не совпадает с дизайном вообще. User explicit (chat1.md): «ты жаловался на лаги, это надо вынести в UI» — настройки должны иметь secured **Performance** секцию с live GPU/FPS метрикой и переключателями Impeller / ABR / parallax.

## Текущее поведение
- `lib/features/settings/settings_screen.dart` — текущий простой экран (не читал в детали для этого issue).

## Желаемое поведение (из дизайна)
Эталон: [`settings-v2.jsx`](.kiro/design/megav-iptv-handoff/project/screens/settings-v2.jsx) (~500 строк).

### Layout
- **Sidebar nav** 300px с 6 разделами:
  1. Воспроизведение (decoder mode, ABR, audio passthrough)
  2. Плейлисты M3U (URL, headers, cache)
  3. Производительность (Impeller toggle, parallax toggle, **live perf metrics**)
  4. Жесты и пульт (key bindings, debounce timing)
  5. Подписки и аккаунт
  6. Об устройстве

### Performance section (особо важно)
- `PerformanceHero` 4-tile grid:
  - GPU FPS (live counter)
  - Кадры пропущенные (live)
  - Память (live)
  - Буфер (live, для активного потока)
- Custom Toggles (44×24 pill, accent glow when on):
  - Impeller engine on/off
  - ABR (Adaptive Bitrate)
  - Parallax effects
- Picker pill rows для discrete options (decoder mode: HW/SW/Auto).

### Atoms
- `SLabel` (section label, italic display 32px)
- `StatTile` (label + 44px display value + sub-text + trend pill ↑/↓)
- `Toggle` (custom 44×24, transition: left 200ms ease, accent glow)
- `Picker` (option chips with 1 active accent)

## Diff scope
**restructure** (полная переписка current settings_screen, основная логика toggle/decoder/abr/etc уже в `decoder_config.dart` через Riverpod).

## Boundary candidates
- `lib/features/settings/settings_screen.dart` (rewrite as sidebar shell)
- `lib/features/settings/widgets/sidebar_nav.dart` (NEW)
- `lib/features/settings/widgets/section_playback.dart` (NEW)
- `lib/features/settings/widgets/section_playlists.dart` (NEW)
- `lib/features/settings/widgets/section_performance.dart` (NEW — самая объёмная)
- `lib/features/settings/widgets/section_remote.dart` (NEW)
- `lib/features/settings/widgets/section_account.dart` (NEW)
- `lib/features/settings/widgets/section_about.dart` (NEW)
- `lib/features/settings/widgets/perf_hero.dart` (NEW — 4-tile grid)
- `lib/features/settings/widgets/stat_tile.dart` (NEW)
- `lib/features/settings/widgets/toggle.dart` (NEW — custom, не Switch)
- `lib/features/settings/widgets/picker.dart` (NEW — option pills)
- `lib/core/perf/perf_metrics_provider.dart` (NEW — Riverpod stream provider для live FPS/memory/buffer)

## Out of boundary
- Native player engine logic (`lib/core/player/*`) — settings only **выставляет флаги**, не меняет engines.
- Account / subscription backend (если нет, то Settings показывает stub «Скоро»).

## Adjacent expectations
- Existing `decoder_config.dart` Riverpod provider используется напрямую.
- Live perf metrics: использует `WidgetsBinding.instance.addTimingsCallback` для FPS + `dart:io` `ProcessInfo.maxRss` (или Flutter perf overlay через VM Service).

## Performance constraints
- Toggle anim 200ms — OK.
- Live perf metrics ребилдит только StatTile через `Selector` / split provider — не весь экран.
- Sidebar D-pad navigation: `Focus` + `FocusTraversalGroup`.

## Estimated effort
**M-L** — 5-7 дней. 6 sections × ~1 день + perf-metrics provider + atoms.

## Action
```
/kiro-discovery settings-redesign
```

## Related
- Blocked-by: #4 (theming)
- Connects to: live perf metrics provider — может стать переиспользуемой инфраструктурой для CI dashboard.


---

## Authoritative references for this spec

- This brief — high-level context.
- GitHub issue #11 — primary discussion / status.
- `.kiro/design/megav-iptv-handoff/` — handoff bundle (HTML + JSX prototypes + themes.css + atoms.jsx).
- `.kiro/steering/flutter-tv-perf.md` — proven performance rules (MUST follow).
- `.kiro/steering/roadmap.md` — full project roadmap with dependency graph.
- Closed kiro specs in `.kiro/specs/` (`home-grid-*`, `player-overlay-state-machine`) — do NOT modify, use as foundation.
