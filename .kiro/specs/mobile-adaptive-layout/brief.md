# Brief: mobile-adaptive-layout

## Source
GitHub Issue [#12](https://github.com/Romaxa55/MegaV-IPTV/issues/12) — read the issue body for full context (Симптом, Текущее поведение, Желаемое поведение, Boundary, Performance constraints, etc.).

To fetch issue body programmatically: `gh issue view 12`.

## Issue body (synced from GH)

## Симптом
Дизайн содержит **mobile artboard** (`mobile-v2.jsx`, ~700 строк) — 3 iPhone-фрейма (Главная / Карточка / Плеер). Текущая Flutter app фокусируется на TV; мобильная адаптация не реализована (нет адаптивного layout, нет mobile-specific tabbar, нет иконок системного назначения).

User в chat: «**И то и другое (адаптив)**» — явно хочет обе платформы. Но **TV — основной приоритет** («основной акцент на тв»).

## Текущее поведение
- Текущий Flutter app работает на любых platforms что Flutter поддерживает (Android, iOS, Linux, macOS, Windows, Web).
- Layout не адаптивный к узким экранам — TV-сетка `3/4/5 columns` от screen width 1280+.
- Нет mobile-specific UI (tab bar внизу, glass blur, status-bar reservation, swipe gestures).

## Желаемое поведение (из дизайна)
Эталон: [`mobile-v2.jsx`](.kiro/design/megav-iptv-handoff/project/screens/mobile-v2.jsx) (~700 строк).

### iOS frame 402×874 (iPhone 16 Pro)
3 экрана:

**1. MobileHome**:
- Status bar reserve (60px) + `MTopBar` с city/temp/time + brand mark.
- Hero card 380px portrait + paginator dots.
- Stacked rails (vertical scroll, не horizontal как на TV).
- Floating glass tab-bar внизу с 5 tabs: Home / TV / Search / Guide / Profile.

**2. MobileDetail**:
- Single-column layout (poster top + meta + actions).
- Smaller fonts (16-22px вместо 32-96 на TV).

**3. MobilePlayer**:
- Vertical-первый, controls overlay снизу + horizontal swipe для канал-switching («SWIPE ↔ КАНАЛ» hint).
- Pulse animation `@keyframes mvpulse` 1.5s на LIVE dot.

### Adaptive logic
- Trigger: `MediaQuery.sizeOf(context).width < 600` → mobile layout.
- 600-1280: tablet (~3 columns на home, mobile-first patterns).
- 1280+: TV (current 3/4/5 columns).

## Diff scope
**XL** — net-new mobile platform support, по сути 3 новых screen + adaptive routing layer.

## Boundary candidates
- `lib/features/home/home_mobile_screen.dart` (NEW)
- `lib/features/detail/detail_mobile_screen.dart` (NEW)
- `lib/features/player/player_mobile_screen.dart` (NEW — отдельный widget tree чем TV-плеер)
- `lib/core/layout/screen_kind.dart` (NEW — enum mobile/tablet/tv + provider)
- `lib/core/layout/adaptive_router.dart` (NEW — picks home_mobile vs home_screen by ScreenKind)
- `lib/features/<screen>/widgets/m_*` widgets (`MTopBar`, `MIconBtn`, `MTabBar`).

## Out of boundary
- Native iOS-specific features (haptics, share-sheet integration) — defer.
- Apple TV / tvOS — не Flutter target в этом repo.
- Adaptive logic для **закрытых** TV-спеков (`home-grid-*`, `player-overlay-*`) — TV-screens продолжают использовать `pickColumns 3/4/5`. Mobile получает свой widget tree.

## Adjacent expectations
- TV-флоу не меняется, mobile добавляется параллельно.
- Все 30 текущих тестов не должны сломаться.
- iOS deployment target — Flutter дефолт (iOS 12+).

## Performance constraints
- `backdropFilter: blur(28px)` на tab-bar — на mobile **OK** (мобильные GPU справляются), запрет был только для Mali-class TV-боксов. Steering doc уточнить.
- Pulse animation — `RepaintBoundary` обязателен.
- Glass blur tab-bar — single saveLayer per frame, mobile GPUs стерпят.

## Estimated effort
**XL** — 10-15 дней. 3 screens + adaptive routing + atoms.

## Action
```
/kiro-discovery mobile-adaptive-layout
```

**Lower priority** — после того как TV-флоу redesign закончен (issues #5-#11).

## Related
- Blocked-by: #4 (theming), #5/#7/#8 (TV equivalents должны быть готовы first для согласованной модели данных)


---

## Authoritative references for this spec

- This brief — high-level context.
- GitHub issue #12 — primary discussion / status.
- `.kiro/design/megav-iptv-handoff/` — handoff bundle (HTML + JSX prototypes + themes.css + atoms.jsx).
- `.kiro/steering/flutter-tv-perf.md` — proven performance rules (MUST follow).
- `.kiro/steering/roadmap.md` — full project roadmap with dependency graph.
- Closed kiro specs in `.kiro/specs/` (`home-grid-*`, `player-overlay-state-machine`) — do NOT modify, use as foundation.
