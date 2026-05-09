# Requirements Document — detail-screen-fullbleed

## Introduction

`detail-screen-fullbleed` — Wave 1 screen-redesign спек. Реализует **новый промежуточный detail-экран** между home и player по дизайну **Variant A (Full-bleed)** из handoff bundle. User explicit choice (chat1.md): «карточка номер один круче»; Variant B (Split) и C (Minimal) сознательно отвергнуты.

Сейчас (`home_screen.dart:237/249`) при тапе на плитку идёт сразу `context.push('/player')` — детального экрана **нет**. Этот спек добавляет route `/channel/:id` (или `/detail/:id`), куда home переходит сначала, и откуда уже запускается player.

Экран — pure presentation поверх данных, которые home уже резолвит (`Channel`, `NowPlayingItem`, EPG). Никаких новых fetch'ей в data layer не вводится; если данных нет — соответствующая секция не рендерится (Requirement 11).

Foundation deps (ВСЕ ЗАКРЫТЫ):
- `design-system-foundation` (#4) — `AppPalette`, `AppRadius`, `MegaVTextStyles`, `AppColors`.
- `perf-safe-widgets` (#13) — **`SafeBackdrop`** критичен для full-bleed hero (pre-rendered cached blur заменяет CSS `filter: blur(40px)`); `SafeFocusRing`, `SafePill`, `combinedHeroGradient`.
- `design-system-atoms` (#14) — `Poster`, `MvButton` (primary + ghost), `Chip`, `MvIconButton`, `SectionTitle`, `MvTrack`, барель `package:megav_iptv/core/ui/atoms/atoms.dart`.

НЕ модифицирует: closed специй (`home-grid-*`, `player-overlay-state-machine`), data layer (`lib/core/api/*`, `lib/core/playlist/*`, `lib/core/epg/*`), native player engines (`lib/core/player/*`), routing logic кроме добавления одного route entry.

Целевое устройство: Realtek `rtd2851a` Android TV-бокс. Performance budget из `flutter-tv-perf.md` обязателен.

См. `brief.md`, GH issue #7, `.kiro/design/megav-iptv-handoff/project/screens/detail.jsx` (170 строк, source of truth).

## Boundary Context

- **In scope** (NEW в `lib/features/detail/`):
  - `detail_screen.dart` — root экрана, layout-only (Stack: SafeBackdrop → content slivers).
  - `widgets/hero_meta.dart` — title (italic display 96px) + meta row + synopsis блок.
  - `widgets/action_row.dart` — focusable row из 4-5 действий: Play (primary) + Favorite/Trailer/Share/EPG (ghost).
  - `widgets/cast_avatars.dart` — горизонтальная row 36×36 круглых аватаров с именами (gradient fallback по индексу — реальные фото вне scope).
  - `widgets/related_rail.dart` — горизонтальный rail Poster атомов (похожий контент / следующие в группе).
  - `widgets/detail_breadcrumb.dart` — back-button + "Главная / Кино / {title}" mono caps trail.
  - `providers/detail_arguments.dart` — `DetailArgs` data class (channelId, optional preloaded `NowPlayingItem`) для передачи через GoRouter `extra`.
  - Route entry в `lib/app.dart`: `GoRoute(path: '/channel/:id', ...)` между `/home` и `/player`.
  - Hero shared element: `Hero(tag: 'channel-poster-${channelId}')` обёртка над постером в home + detail.
  - Modify `home_screen.dart` `_playNowPlaying` / channel-tile `onPressed` → переход на `/channel/:id` вместо `/player`.

- **In scope** (MODIFY existing — minimal):
  - `lib/app.dart` — добавить route entry (3-5 строк).
  - `lib/features/home/home_screen.dart` — заменить `context.push('/player')` на `context.push('/channel/${channel.id}', extra: DetailArgs(...))` в 2 местах (lines 237, 249). Обернуть постер в Hero для shared transition.
  - `lib/features/home/widgets/_card_poster.dart` (или эквивалент) — обернуть в `Hero(tag: ...)` без изменения визуала.

- **Out of scope**:
  - Variants B (Split) и C (Minimal) — пользователь явно отверг.
  - Player route logic — issue #8 (`player-cinematic-redesign`); detail только вызывает `context.push('/player')` с current channel state.
  - Backend / data-layer modifications: detail читает то, что home уже загрузил.
  - Поиск по cast / переход на актёра — не нужны (handoff не предусматривает).
  - EPG full screen — issue #9 (`epg-screen`); detail показывает только короткий EPG-strip из переданных данных, кнопка «Вся программа» делает `context.push('/epg')` (если такой route появится позже — иначе no-op в этой spec).
  - Trailer player — отдельный feature, кнопка «Трейлер» в этой spec — visual-only (логирует tap, no-op).
  - Mobile layout (issue #12) — этот спек целит TV (1920×1080 designSize).
  - Любые изменения `home-grid-*` или `player-overlay-state-machine` (closed specs).

- **Adjacent expectations**:
  - Closed specs продолжают работать без модификаций.
  - 65+ существующих тестов остаются зелёными.
  - Все atoms используются через barrel `package:megav_iptv/core/ui/atoms/atoms.dart` (без relative imports).
  - Все perf-safe primitives используются через `lib/core/perf/perf_safe_widgets.dart`.
  - Hero transition работает в обоих направлениях (push + pop) без visible jank.

## Requirements

### Requirement 1: Route entry & navigation contract

**Objective:** Как разработчик home screen, я хочу один новый route `/channel/:id`, куда я могу `context.push` с минимальным аргументом (`DetailArgs`), чтобы открыть detail-экран.

#### Acceptance Criteria

1. The Application Router shall declare a new `GoRoute` with path `/channel/:id` registered inside the existing `ShellRoute` between `/home` and `/player` in `lib/app.dart`.
2. The Detail Screen shall accept a `DetailArgs` payload via `GoRouterState.extra`, containing at minimum `channelId: String`, optional `preloadedNowPlaying: NowPlayingItem?`, and optional `posterImageProvider: ImageProvider?`.
3. While `extra` is null or not a `DetailArgs`, the Detail Screen shall fall back to resolving the channel by `state.pathParameters['id']` from existing providers without crashing.
4. The Home Screen shall replace its existing `context.push('/player')` call sites with `context.push('/channel/<id>', extra: DetailArgs(...))` in the channel-tap handler.
5. The Detail Screen shall expose a "Smotret" / Play action that calls `context.push('/player')` (existing route untouched), preserving the current player navigation contract.
6. While the user presses the system Back / D-pad Back on the detail screen, the router shall pop back to `/home` without re-fetching home data.

### Requirement 2: Full-bleed hero artwork via SafeBackdrop

**Objective:** Как пользователь TV, я хочу видеть кинематографичный full-bleed бэкграунд кадра с постера канала, без runtime-blur (TV-Mali не вытягивает), но с pre-rendered cached blur через `SafeBackdrop`.

#### Acceptance Criteria

1. The Detail Screen shall render a full-bleed background layer behind all content using `SafeBackdrop` from `lib/core/perf/perf_safe_widgets.dart`, sized to the screen viewport via `Positioned.fill`.
2. The `SafeBackdrop` shall receive the channel poster `ImageProvider` (from `DetailArgs.posterImageProvider` or resolved via providers) and shall not apply any runtime `BackdropFilter` or `ImageFilter.blur`.
3. The Detail Screen shall overlay a single `combinedHeroGradient(palette)` layer above the backdrop to ensure title legibility, with no more than one stacked `LinearGradient` over the hero (per `flutter-tv-perf.md` rule on stacked gradients over hero).
4. While the channel has no resolvable poster image, the Detail Screen shall fall back to a solid `AppPalette.background` color without crashing or showing a broken-image placeholder.
5. The hero layer shall be wrapped in a `RepaintBoundary` to isolate its repaints from the scrollable content above.
6. The Detail Screen shall not introduce any `BackdropFilter`, `ImageFilter.blur`, `ShaderMask`, `mix-blend-mode` analog, or `BoxShadow.blurRadius > kSafeShadowBlurMax` anywhere in its widget tree.

### Requirement 3: Hero meta block (title + meta row + synopsis)

**Objective:** Как пользователь, я хочу видеть итальянский display title, мета-строку (рейтинг / год / жанр / длительность / сезоны) и синопсис в нижней-левой зоне экрана, как на эталоне `detail.jsx`.

#### Acceptance Criteria

1. The Hero Meta widget shall render the channel / content title using the active palette's display font in italic style at a logical size of 96 px (per design handoff), with `letterSpacing: -0.02em` and `lineHeight: 0.95`.
2. The Hero Meta widget shall render a meta row directly below the title containing rating (gold star + score), year, genre, duration, and optional seasons label, using `MegaVTextStyles.metaMono` (mono caps).
3. The Hero Meta widget shall render an optional synopsis paragraph below the meta row, using `MegaVTextStyles.body` (or comparable), constrained to `maxWidth ≈ 720 dp`.
4. While the title text uses a drop shadow for legibility, its `Shadow.blurRadius` shall not exceed `kSafeShadowBlurMax` (12.0).
5. While any meta field is null or empty, the Hero Meta widget shall omit it from the row without leaving residual separators.
6. While the synopsis is null, the Hero Meta widget shall omit the paragraph element entirely.

### Requirement 4: Action row with MvButton variants

**Objective:** Как пользователь TV с пультом, я хочу горизонтальный ряд из 4-5 кнопок действий — Play (primary), Favorite, Trailer, Share, EPG (ghost) — с D-pad навигацией и видимым focus ring.

#### Acceptance Criteria

1. The Action Row widget shall render exactly one `MvButton.primary` button labelled "Smotret" / "Play" with a play-icon leading widget, as the first focusable item in left-to-right order.
2. The Action Row widget shall render up to four `MvButton.ghost` buttons after the primary: Favorite ("В избранное"), Trailer ("Трейлер"), Share ("Поделиться"), and optional EPG ("Программа").
3. The Action Row widget shall arrange buttons in a `Row` with `spacing: 12 dp` (horizontal `gap`) and `crossAxisAlignment: center`.
4. While focus is on any button, the focused `MvButton` shall display a `SafeFocusRing` (provided by the atom per design-system-atoms Req 10.6) — the action row shall not add its own glow / shadow.
5. The Action Row widget shall route D-pad arrowLeft / arrowRight between siblings via the default `FocusTraversalPolicy`, and arrowDown shall move focus to the cast row or related rail (whichever is next visually).
6. The Action Row widget shall expose callbacks `onPlay`, `onFavorite`, `onTrailer`, `onShare`, `onEpg`; null callbacks shall hide the corresponding button instead of rendering a disabled state.
7. While `onPlay` is invoked, the Detail Screen shall call `context.push('/player')` after applying any required state changes (e.g. setting `currentChannelProvider`); the Action Row widget itself shall not call `context.push` directly.

### Requirement 5: Hero shared element transition (home → detail)

**Objective:** Как пользователь, я хочу плавный shared-element переход постера канала из home grid в detail screen, без custom transition packages — только Flutter `Hero` widget.

#### Acceptance Criteria

1. The Home Screen shall wrap the channel poster widget (in `_card_poster.dart` or its replacement) in a `Hero` widget with `tag: 'channel-poster-${channel.id}'`.
2. The Detail Screen shall wrap its primary poster widget (large 460×680 portrait `Poster`) in a `Hero` with the same tag format using the channel id from `DetailArgs`.
3. The Detail Screen shall not implement a custom `PageRouteBuilder` transition; the standard GoRoute transition combined with the `Hero` widget shall provide the shared-element animation.
4. While the user navigates Home → Detail, the Hero animation shall complete within 300 ms (default `MaterialPageRoute` transition; per `flutter-tv-perf.md` no requirement to override).
5. While a Hero with the same tag is mounted in both routes, no two distinct widgets shall claim the same tag in a single visible frame except during the in-flight transition.
6. The Hero `flightShuttleBuilder` shall not be customized in this spec (default behaviour acceptable); if visual jank is observed in implementation, the implementer may add a minimal shuttle that preserves the `Poster` atom, documented in `design.md` revision.

### Requirement 6: Cast avatars row

**Objective:** Как пользователь, я хочу видеть актёров блок с круглыми 36×36 аватарами (gradient fallback) и именами под секционным заголовком «В ролях», как на эталоне.

#### Acceptance Criteria

1. The Cast Avatars widget shall render a horizontal `Wrap` (or `Row` if single line fits) of cast entries; each entry shall be a 36×36 circular avatar followed by the actor name.
2. The Cast Avatars widget shall use a deterministic gradient fallback per index (driven from a fixed palette table) when no avatar `ImageProvider` is supplied — real photo loading is **out of scope**.
3. The Cast Avatars widget shall display a `SectionTitle` atom with text "В ролях" / "Cast" with no count and no «more →» action, immediately above the row.
4. While the cast list is empty or null, the entire cast section (title + row) shall be omitted from the layout — no empty placeholder.
5. The Cast Avatars widget shall be non-focusable (decorative only); D-pad traversal shall skip it.
6. The Cast Avatars widget shall not perform any network fetch in this spec; cast strings are passed as `List<String>` from the screen-level provider.

### Requirement 7: Related-content rail

**Objective:** Как пользователь, я хочу горизонтальный rail из 5-8 постеров «Похожие» под основным content-блоком, чтобы D-pad-фокусом перейти в другой канал без возврата на home.

#### Acceptance Criteria

1. The Related Rail widget shall render a `SectionTitle` atom with text "Похожие" + italic emphasis "по настроению" + numeric count, followed by a horizontal `ListView.builder` of `Poster` atoms.
2. The `ListView.builder` shall be configured with `cacheExtent: 1500`, `addAutomaticKeepAlives: true`, `addRepaintBoundaries: true`, and `clipBehavior: Clip.none` (per `flutter-tv-perf.md` row defaults).
3. Each poster shall have orientation `PosterOrientation.portrait` and a fixed logical width ≈ 200 dp.
4. While a poster is focused, it shall apply scale `GridTokens.focusedScale` (1.08) via `Transform.scale`, never via `AnimatedContainer.width`.
5. While the user activates (presses OK / Enter on) a focused poster, the Detail Screen shall replace itself via `context.pushReplacement('/channel/<otherId>', extra: ...)` so back-navigation returns to home, not chain-stacks detail screens.
6. While the related-content list is empty or null, the entire related rail shall be omitted from the layout.
7. The related rail data shall be sourced from a screen-level provider that derives from existing home providers (e.g., siblings in the same `groupTitle`); no new API call shall be introduced.

### Requirement 8: Focus management & D-pad traversal

**Objective:** Как пользователь TV, я хочу детерминированный focus-flow: при открытии screen фокус на Play, arrowDown переходит на cast/related, arrowUp возвращается на Play, Back возвращается на home.

#### Acceptance Criteria

1. The Detail Screen shall request initial focus on the primary "Play" `MvButton` of the action row when the screen first becomes visible (`autofocus: true` or equivalent `FocusNode.requestFocus()` on first frame).
2. The Detail Screen shall use the default `FocusTraversalPolicy` (`ReadingOrderTraversalPolicy` or `OrderedTraversalPolicy`) without registering a custom policy class.
3. The Detail Screen shall not introduce any `Shortcuts` / `Actions` mappings that override system Back; the existing `PopScope` in `app.dart` `ShellRoute` shall handle Back globally.
4. While the user holds D-pad arrowDown from the action row, focus shall progress to the related rail (or cast row if related is empty), skipping non-focusable cast avatars and decorative widgets.
5. While the user presses D-pad arrowLeft from the leftmost action button (Play), the focus shall stay on Play (no wrap-around to far-right element).
6. The Detail Screen shall not trigger any heavy async work (network fetch, file read, isolate spawn) within `initState` or first build; any such work shall be deferred to providers already populated by home.

### Requirement 9: Performance compliance (TV-Mali budget)

**Objective:** Как пользователь TV-бокса rtd2851a, я хочу чтобы detail-экран открывался плавно и скроллился без drop в fps ниже 60.

#### Acceptance Criteria

1. The Detail Screen shall not introduce any `BackdropFilter`, `ImageFilter.blur`, `ShaderMask`, or `mix-blend-mode` analog anywhere in its widget tree, in alignment with `flutter-tv-perf.md` TL;DR rule 1.
2. The Detail Screen shall not use `BoxShadow.blurRadius > kSafeShadowBlurMax` (12.0) anywhere in its widget tree.
3. The Detail Screen shall not stack more than one `LinearGradient` `DecoratedBox` over the hero backdrop layer.
4. The Detail Screen shall wrap any `StreamBuilder` / `ValueListenableBuilder` (e.g., live-progress on `MvTrack`) in a `RepaintBoundary` and place it under a `const` parent or isolated `ConsumerWidget` per `flutter-tv-perf.md` "Постоянная подписка на стримы".
5. The Detail Screen shall use `Transform.scale` (not `AnimatedContainer.width`) for any focus-state size change.
6. While measured via `getVMTimeline` on rtd2851a in `--profile` build over a 5-second open-screen scenario after warmup, average `GPURasterizer::Draw` shall be ≤ 16.7 ms; this measurement is recommended in tasks (not gating) — gating measure is the static `grep` audit for forbidden APIs.
7. The Detail Screen shall use atoms via the barrel `package:megav_iptv/core/ui/atoms/atoms.dart` and shall not re-implement equivalents of `Poster`, `MvButton`, `Chip`, `SectionTitle`, `MvIconButton`, `MvTrack`.

### Requirement 10: Backward compatibility (closed specs untouched)

**Objective:** Как maintainer 65+ закрытых тестов, я хочу чтобы добавление detail-экрана не сломало ни один call-site закрытых спеков.

#### Acceptance Criteria

1. The Detail Screen feature shall not modify files under `lib/features/home/widgets/_grid_tokens.dart`, `lib/features/home/widgets/cinema_card.dart`, `lib/features/home/widgets/cinema_row.dart`, `lib/features/home/widgets/_card_poster.dart` other than (optionally) wrapping the inner poster in a `Hero` widget that preserves the original visual constraints.
2. The Detail Screen feature shall not modify files under `lib/features/player/` (player overlay state-machine — closed spec).
3. The Detail Screen feature shall not modify files under `lib/core/api/`, `lib/core/playlist/`, `lib/core/epg/`, or `lib/core/player/`.
4. The Detail Screen feature shall not introduce a new state variant in any sealed `PlayerUiState` class (closed spec ownership).
5. While the existing test suite runs after this spec is implemented, all 65+ pre-existing tests shall pass without modification.
6. The Detail Screen feature shall not add any new package to `pubspec.yaml`.

### Requirement 11: Graceful degradation when data missing

**Objective:** Как пользователь, открывший detail для канала с минимальными метаданными, я хочу видеть валидный экран без пустых блоков и без crash.

#### Acceptance Criteria

1. While the channel has no synopsis, the Detail Screen shall omit the synopsis paragraph and tighten layout (no empty space).
2. While the channel has no cast list, the Detail Screen shall omit the entire cast section.
3. While the channel has no related-content list, the Detail Screen shall omit the entire related rail.
4. While the channel has no current EPG entry, the Detail Screen shall omit the optional EPG-strip / progress block.
5. While the channel has no resolvable poster image, the Detail Screen shall render a solid `AppPalette.background` background, an empty `Poster` atom (using its built-in fallback per design-system-atoms Req 5.2), and shall still render title and action row.
6. While `DetailArgs.preloadedNowPlaying` is null but the route is reachable, the Detail Screen shall display title from `Channel.name`, accept null synopsis/cast/related, and remain interactive (Play action functional).

### Requirement 12: Testability

**Objective:** Как разработчик, я хочу widget tests которые ловят регрессии в layout, focus initialization и hero-tag contract.

#### Acceptance Criteria

1. The project shall include a widget test pumping `DetailScreen` with a stub `DetailArgs`, asserting that the primary "Smotret" / "Play" `MvButton` is present and has initial focus on first frame.
2. The project shall include a widget test asserting that the Hero widget on the detail screen has a tag matching `'channel-poster-<id>'` for the supplied channel id.
3. The project shall include a widget test asserting that, given a stub channel with empty cast and empty related lists, neither section renders any `SectionTitle` atom (Req 11.2, 11.3).
4. The project shall include a widget test asserting that pressing the Play action invokes `context.push('/player')` exactly once (mocked router).
5. The project shall include a static audit (e.g., a grep-based test or inline comment instructing the reviewer) verifying zero occurrences of `BackdropFilter`, `ShaderMask`, `ImageFilter.blur`, and zero `blurRadius:` numeric literals greater than 12 within `lib/features/detail/`.
6. The project shall include a regression assertion that all pre-existing tests continue to pass (ran in CI / local — no test code change required, but the implementer shall confirm in task observation).
