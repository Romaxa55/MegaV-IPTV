# Brief: player-cinematic-redesign

## Source
GitHub Issue [#8](https://github.com/Romaxa55/MegaV-IPTV/issues/8) — read the issue body for full context (Симптом, Текущее поведение, Желаемое поведение, Boundary, Performance constraints, etc.).

To fetch issue body programmatically: `gh issue view 8`.

## Issue body (synced from GH)

## Симптом
User в chat явно сказал убрать кнопочную панель из плеера и заменить её на «**плитку 5 других каналов 16:9**» внизу экрана с логотипами и live-progress. Цель: переключиться на другой канал в одно нажатие OK без открытия sidebar.

## Текущее поведение
- `lib/features/player/player_screen.dart` (481 строка) — закрытый спек `player-overlay-state-machine`.
- Sealed `PlayerUiState` с 5 вариантами: `HiddenState / ControlsState / BriefOsdState / SwitchPreviewState / OverlayState`.
- `OverlayState` имеет 4 моды: `epg / channels / info / similar`.
- Channel switching через ⬆⬇ → SwitchPreviewState (1.5с) → commit.
- `ChannelsSidebar` открывается клавишей L (overlay).

## Желаемое поведение (из дизайна)
Эталон: [`player-v2.jsx`](.kiro/design/megav-iptv-handoff/project/screens/player-v2.jsx) (192 строки).

### Изменения относительно текущего
- **Top status bar** при `ControlsState`: back button + brand chip + LIVE chip + program title + bitrate (вместо текущего OSD с info).
- **Bottom glass-panel** с inline EPG progress bar:
  - EPG bar: start/now/end timestamps, progress fill (`mv-track` style).
  - Action buttons: `[Play/Pause | Next | Audio | Subs | Info | spacer | Channels deck toggle]`.
- **Channel deck**: правая сторона, slide-in via `transform: translateX(0%)` когда `focus === "channels"`. Это **новая визуализация** существующего `ChannelsSidebar`:
  - 5 channels visible at once.
  - Each entry: 16:9 thumbnail + channel logo + program title + remaining time + LIVE progress bar.
  - Press OK → инициирует `SwitchPreviewState`.
- **Ken-burns slow-zoom** на BG fallback (когда видео не grueża).
- D-pad hint legend в bottom strip: keys + actions.

### State-machine — НЕ ЛОМАТЬ
- `PlayerUiState` 5 вариантов **сохраняются** все 5.
- Design покрывает только 3 моды (Hidden / Controls / OverlayState.channels) — `BriefOsd` и `SwitchPreview` остаются как Flutter-side QoL.
- `OverlayState.epg / info / similar` остаются — design имеет кнопки на bottom panel что вызывают `_toggleOverlayKey(...)`.
- `_transition()` атомарность сохраняется. `_quickSwitchInFlight` guard сохраняется.

## Diff scope
**restructure** — `_buildControls()` render expansion для нового `ControlsState` UI; новый `ChannelDeck` widget; ken-burns BG.

## Boundary candidates
- `lib/features/player/player_screen.dart` (modify — `_buildControls()` render)
- `lib/features/player/widgets/player_top_bar.dart` (NEW — back+brand+LIVE+title+bitrate)
- `lib/features/player/widgets/player_bottom_panel.dart` (NEW — EPG bar + action buttons)
- `lib/features/player/widgets/inline_epg_bar.dart` (NEW — start/now/end + progress)
- `lib/features/player/widgets/channel_deck.dart` (NEW — replaces `channels_sidebar.dart` или дополняет; решить в design phase)
- `lib/features/player/widgets/ken_burns_backdrop.dart` (NEW)

## Out of boundary
- Sealed `PlayerUiState` (NOT REMOVE — extend if needed, не replace).
- Native player engines (`lib/core/player/*`).
- Quick-switch race-fix (`_quickSwitchInFlight`) — сохранить.

## Adjacent expectations
- 30 текущих тестов проходят без модификаций.
- `transitionForTest` API сохраняется.
- BriefOsd 3s + SwitchPreview 1.5s timings сохраняются.
- `_LoadingErrorIndicator` остаётся как есть.

## Performance constraints (CRITICAL)
- **`backdrop-filter: blur(20px)`** на bottom panel — **запрещено** (steering doc). Замена: opaque-tint translucent fill `Color.fromRGBO(20,20,26, 0.85)`.
- **`backdrop-filter: blur(16px)`** на icon buttons — same rule, opaque-tint.
- Ken-burns transform (slow scale 1→1.05 over 30s) — GPU-only, OK.
- Channel deck slide animation — GPU transform, OK.

## Estimated effort
**M** — 3-5 дней. Render expansion ControlsState + 4 новых widget'а + ken-burns.

## Action
```
/kiro-discovery player-cinematic-redesign
```

## Related
- Closed: `player-overlay-state-machine` (НЕ ЛОМАТЬ)
- Blocked-by: #4 (theming)
- Sibling: existing #3 (PlayerManager retry)


---

## Authoritative references for this spec

- This brief — high-level context.
- GitHub issue #8 — primary discussion / status.
- `.kiro/design/megav-iptv-handoff/` — handoff bundle (HTML + JSX prototypes + themes.css + atoms.jsx).
- `.kiro/steering/flutter-tv-perf.md` — proven performance rules (MUST follow).
- `.kiro/steering/roadmap.md` — full project roadmap with dependency graph.
- Closed kiro specs in `.kiro/specs/` (`home-grid-*`, `player-overlay-state-machine`) — do NOT modify, use as foundation.
