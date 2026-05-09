# Requirements Document — settings-redesign

## Introduction

`settings-redesign` — Wave 1 экран настроек, переписывающий текущий 150-строчный `settings_screen.dart` (плоский `ListView` с 2 опциями) в полноразмерный sidebar-driven shell с **6 секциями** согласно дизайн-handoff (`settings-v2.jsx`, ~500 строк). Спек **владеет видимым UI палитро-переключателя**, который вызывает `ref.read(themeProvider.notifier).setPalette(name)` из `design-system-foundation` (#4) — это та самая «Settings UI sees this in #11» доводка, которую foundation оставил без UI.

Помимо палитры, новый экран открывает доступ к уже существующему `decoderConfigProvider` через кастомные toggles/pickers, добавляет live-метрики производительности (FPS/память/skipped frames) на правую панель Performance-секции, и формализует D-pad навигацию: вертикальный sidebar слева → правая «scroll body» панель справа, с чёткими `FocusTraversalGroup` границами.

Целевое устройство — Realtek `rtd2851a` Android TV-бокс. Все правила из `flutter-tv-perf.md` обязательны: никаких `BackdropFilter`/`ShaderMask`, `BoxShadow.blurRadius ≤ 12`, scroll/focus анимации Leanback-таймингов (150/250/400 мс), live-метрики изолированы в `RepaintBoundary`-обёрнутые consumers чтобы тики FPS-стрима не ребилдили весь экран.

Foundation специй (закрыты, GO-валидированы): `design-system-foundation` (#4 — `themeProvider` + 6 палитр + `MegaVTextStyles` + `AppRadius`), `perf-safe-widgets` (#13 — `SafePill`, `SafeFocusRing`, `kSafeShadowBlurMax`, `ComputedColors`), `design-system-atoms` (#14 — `MvButton`, `MvIconButton`, `Chip`, `SectionTitle`, `RemoteHint`, `Brand`). Этот спек **потребляет** их через публичные API, **не модифицирует**.

См. `brief.md`, GitHub issue #11, дизайн-эталон `.kiro/design/megav-iptv-handoff/project/screens/settings-v2.jsx`, и `.kiro/steering/flutter-tv-perf.md` как source-of-truth.

## Boundary Context

- **In scope** (NEW в `lib/features/settings/`):
  - `settings_screen.dart` (REWRITE) — полная переписка как sidebar shell c `Row(children: [SidebarNav, Expanded(scrollBody)])`.
  - `widgets/sidebar_nav.dart` (NEW) — вертикальный список из 6 section-имён, focus-aware, активная позиция через `Chip` или `SafeFocusRing`.
  - `widgets/section_appearance.dart` (NEW) — Theme/Palette section: 6-палитровый swatch-grid + font-pair selector (font-pair как stub если расширение в отдельном спеке, но UI готов).
  - `widgets/section_player.dart` (NEW) — Player section: decoder mode picker pills + buffer mode picker + ABR toggle + audio passthrough toggle. Все читают/пишут `decoderConfigProvider`.
  - `widgets/section_network.dart` (NEW) — Network/Playlists section: API base URL + headers + cache controls (читает `baseUrlProvider`, `categoriesProvider`).
  - `widgets/section_performance.dart` (NEW) — Performance section: 4-tile `PerfHero` + 3 toggles (Impeller/Parallax/ABR) + reset stats button.
  - `widgets/section_about.dart` (NEW) — About: версия app, build number, device info, ссылки на legal stubs.
  - `widgets/section_reset.dart` (NEW) — Reset: подтверждающая кнопка «сбросить настройки до дефолтов» + confirm dialog.
  - `widgets/palette_swatches.dart` (NEW) — 6-palette swatch grid; вызывает `ref.read(themeProvider.notifier).setPalette(name)`. Это главный consumer foundation #4.
  - `widgets/font_pair_picker.dart` (NEW) — picker pills для font-pair (foundation поддерживает только `font-cinema`; UI готов к расширению, но опция blocked-message при попытке выбрать другой font-pair если только один доступен).
  - `widgets/perf_hero.dart` (NEW) — 4-tile grid: GPU FPS / Skipped frames / Memory / Buffer.
  - `widgets/stat_tile.dart` (NEW) — pure presentation: label + 44px display value + sub-text + optional trend arrow.
  - `widgets/mv_toggle.dart` (NEW) — кастомный 44×24 pill toggle с accent glow в on-state. Использует foundation tokens.
  - `widgets/mv_picker.dart` (NEW) — option pills row: 1 active + N inactive. Использует `MvButton`/atoms через композицию.
  - `lib/core/perf/perf_metrics_provider.dart` (NEW) — `StreamProvider`/`AsyncNotifier` с live FPS (через `WidgetsBinding.instance.addTimingsCallback`), memory (`ProcessInfo.maxRss` через dart:io на Android), skipped frames, buffer (передаётся из активного потока, опционально).
  - `test/features/settings/*` — unit + widget тесты для каждой section + golden для swatches + perf-metrics provider isolation тест.

- **Out of scope**:
  - Account / subscription backend — секция About показывает заглушку «Не выполнен вход» если auth не настроен; никакой реальной auth-инфраструктуры этот спек не строит.
  - Модификация `themeProvider` — потребляется через публичный API (`setPalette`) **строго** read-only.
  - Изменения в `lib/core/theme/*` — закрыто foundation #4.
  - Изменения в `lib/core/perf/perf_safe_widgets.dart` — закрыто #13.
  - Изменения в `lib/core/ui/atoms/*` — закрыто #14.
  - Native player engines (`lib/core/player/*` за пределами `decoder_config.dart`).
  - Routing/router — `/settings` route уже существует, не меняем.
  - Mobile-adaptive layout — issue #12.
  - Реальная persistence для `decoderConfigProvider` — отдельный спек.
  - Расширение количества font-pairs — foundation поддерживает только `font-cinema`; этот спек делает UI extension-ready, но не добавляет новые fonts.

- **Adjacent expectations**:
  - `themeProvider` (#4) — единственная точка для смены палитры. Settings вызывает `setPalette(name)`, любой другой экран немедленно ребилдится через `ref.watch(themeProvider)`.
  - `decoderConfigProvider` — существующий Riverpod state notifier, settings читает/пишет напрямую.
  - `baseUrlProvider`, `categoriesProvider` — существующие providers, settings читает и invalidates.
  - Closed-spec файлы (`home-grid-*`, `player-overlay-state-machine`) **не трогаются**.
  - Все atoms (`MvButton`, `MvIconButton`, `Chip`, `SectionTitle`, `RemoteHint`, `Brand`) импортируются через barrel `package:megav_iptv/core/ui/atoms/atoms.dart`.
  - `flutter analyze` проходит чисто; все ранее зелёные тесты остаются зелёными (regression budget — 0).

## Requirements

### Requirement 1: Sidebar shell layout

**Objective:** Как пользователь TV-пульта, я хочу видеть слева вертикальный список секций и справа прокручиваемое содержимое выбранной секции, чтобы быстро ориентироваться в настройках без скролла мимо нужного раздела.

#### Acceptance Criteria

1. The Settings Screen shall render a top-level `Row` widget with two children: a fixed-width sidebar nav on the left and a flexible scroll body on the right.
2. The Settings Screen shall set the sidebar's logical width to 300 dp via `flutter_screenutil` `.w` scaling.
3. The Settings Screen shall display section content in the right panel via a single child whose identity changes based on the currently selected section index.
4. The Settings Screen shall render a backdrop using the active palette's `background` token plus a single `SafeFilmGrain` overlay (no `BackdropFilter`, no `ShaderMask`).
5. The Settings Screen shall expose route `/settings` unchanged from the previous implementation.

### Requirement 2: Sidebar navigation with 6 sections and D-pad focus

**Objective:** Как пользователь TV-пульта, я хочу перемещаться по 6 секциям стрелками вверх/вниз и подтверждать выбор OK, чтобы переключать содержимое правой панели без касания экрана.

#### Acceptance Criteria

1. The Sidebar Nav shall enumerate exactly 6 sections in fixed order: Appearance (Theme/Palette + Font Pair), Player, Network, Performance, About, Reset.
2. The Sidebar Nav shall render each section as a focusable item using `Focus` + a custom render reading `FocusNode.hasFocus`.
3. While a sidebar item has focus the Sidebar Nav shall display a focus visual using `SafeFocusRing` (no blur, no `ShaderMask`).
4. While a sidebar item is the currently selected section the Sidebar Nav shall display an active-state visual distinct from the focus ring (e.g., accent left-bar or filled `Chip`).
5. The Sidebar Nav shall update the selected section index via the parent screen's state when the user presses OK / Enter / Select on a focused item.
6. The Sidebar Nav shall wrap its 6 items in `FocusTraversalGroup` so D-pad up/down stay inside the sidebar until the user explicitly traverses right into the body.
7. The Sidebar Nav shall transfer focus to the right panel's first focusable element when the user presses D-pad right (`LogicalKeyboardKey.arrowRight`) on any sidebar item.

### Requirement 3: Appearance section — palette switcher

**Objective:** Как пользователь, я хочу видеть 6 палитр в виде сетки swatches и выбирать активную одним нажатием OK, чтобы немедленно увидеть смену темы во всём приложении.

#### Acceptance Criteria

1. The Appearance Section shall render a swatch grid containing exactly 6 entries, one per `AppPaletteName` enum value, in the order declared by `AppPaletteName.values`.
2. The Appearance Section shall render each swatch using a `RepaintBoundary`-isolated widget that displays representative tokens of that palette (background + accent + accentGlow) without instantiating a separate `MaterialApp` or `Theme`.
3. The Appearance Section shall mark the swatch corresponding to `ref.watch(themeProvider)` as the currently active palette using a `SafeFocusRing` outer ring or accent border distinct from D-pad focus visuals.
4. The Appearance Section shall, on user activation (OK / tap) of a swatch, call `ref.read(themeProvider.notifier).setPalette(targetName)` exactly once per activation.
5. The Appearance Section shall not call `setPalette` during build or as a side-effect of `ref.watch` — only via explicit user input.
6. The Appearance Section shall reflect the result of the palette change within the same frame the rebuild completes (no manual cache flush, no `setState` in the swatch widget).
7. The Appearance Section shall not modify `themeProvider`'s internal state, persistence adapter, or `AppPaletteName` enum surface.

### Requirement 4: Appearance section — font pair selection

**Objective:** Как пользователь, я хочу видеть доступные шрифтовые пары и понимать, какая активна, чтобы быть готовым к расширению (другие font-pairs появятся в будущем спеке).

#### Acceptance Criteria

1. The Appearance Section shall render a font-pair picker row using `MvPicker` whose options enumerate the font pairs declared by `MegaVTextStyles` extension (currently a single entry `font-cinema`).
2. The Appearance Section shall mark the currently active font pair as selected using the picker's active visual.
3. While only one font pair is available, the Font Pair Picker shall present that single option in a non-interactive (disabled) state with a sub-text «Доступна только Cinematic» and shall NOT call any provider mutation.
4. The Font Pair Picker shall be source-stable: adding a new font pair to `MegaVTextStyles` in a future spec shall require zero changes to `section_appearance.dart` beyond enumeration.
5. The Font Pair Picker shall NOT modify `themeProvider`, `MegaVTextStyles`, or any closed-foundation file.

### Requirement 5: Player section — decoder & buffer & toggles

**Objective:** Как пользователь, я хочу настраивать decoder mode, buffer size, ABR и audio passthrough через D-pad-friendly pickers/toggles, чтобы оптимизировать воспроизведение под своё устройство без правки конфигов.

#### Acceptance Criteria

1. The Player Section shall expose a Decoder Mode picker (`MvPicker`) listing all values of `DecoderMode` enum from `decoder_config.dart` with their `label` strings.
2. The Player Section shall reflect `ref.watch(decoderConfigProvider).decoderMode` as the active picker option.
3. On user activation of a non-active decoder option, the Player Section shall call `ref.read(decoderConfigProvider.notifier).state = currentConfig.copyWith(decoderMode: targetMode)` exactly once.
4. The Player Section shall expose a Buffer Mode picker listing all `BufferMode` values with `label` and `${seconds}s` sub-text, wired via the same copyWith pattern.
5. The Player Section shall expose an ABR toggle (`MvToggle`) bound to a Boolean field on `DecoderConfig`; if the field does not yet exist, the spec implementation shall add it via `copyWith` without modifying the provider's identity.
6. The Player Section shall expose an Audio Passthrough toggle (`MvToggle`) bound similarly.
7. The Player Section shall not call into `lib/core/player/*` beyond reading `DecoderMode` / `BufferMode` enums and writing `decoderConfigProvider`.

### Requirement 6: Network section — API base URL & cache

**Objective:** Как продвинутый пользователь, я хочу менять backend URL и сбрасывать кэш плейлистов через настройки, чтобы быстро переключаться между серверами и инвалидировать заблудившиеся данные.

#### Acceptance Criteria

1. The Network Section shall display the current `baseUrlProvider` value as a single read-only row with a trailing "Edit" `MvIconButton`.
2. On activation of the Edit button the Network Section shall open a dialog (`showDialog`) with a `TextField` pre-filled by the current URL and Save/Cancel actions.
3. The Network Section shall, on Save, write `ref.read(baseUrlProvider.notifier).state = trimmedNewUrl` and call `ref.invalidate(categoriesProvider)`.
4. The Network Section shall display a "Сброс кэша плейлистов" `MvButton.ghost` which, on activation, calls `ref.invalidate(categoriesProvider)` (and any documented playlist providers) without mutating `baseUrlProvider`.
5. The Network Section shall not introduce new HTTP code or new providers in `lib/core/api/*` or `lib/core/playlist/*`.

### Requirement 7: Performance section — live metrics widget

**Objective:** Как разработчик/operator, я хочу видеть live FPS, скиппнутые кадры, потребляемую память и буфер активного потока на правой панели Performance, чтобы диагностировать перформанс прямо на устройстве без подключения VM Service.

#### Acceptance Criteria

1. The Performance Section shall render a 4-tile grid (`PerfHero`) with tiles labelled GPU FPS, Skipped frames, Memory, Buffer.
2. The Performance Section shall source live metrics from a new `perfMetricsProvider` (Riverpod `StreamProvider` or `AsyncNotifier`) located at `lib/core/perf/perf_metrics_provider.dart`.
3. The `perfMetricsProvider` shall produce FPS using `WidgetsBinding.instance.addTimingsCallback`, computing rolling-window average over the last 60 frames.
4. The `perfMetricsProvider` shall produce memory using `ProcessInfo.maxRss` (dart:io) on Android/Linux platforms, falling back to `null` (rendered as «—») where unavailable.
5. The `perfMetricsProvider` shall produce skipped frames count using the same timings callback (frames whose total > 16.7 ms).
6. The `perfMetricsProvider` shall produce buffer seconds for the active playback session if a stream-buffer source is wired via DI; otherwise the tile shall render «—».
7. Each `StatTile` consuming the metrics provider shall be wrapped in `RepaintBoundary` with `const` parent constructor so per-tick provider updates do not rebuild the whole settings screen.
8. The `perfMetricsProvider` shall stop producing values (cancel the timings callback subscription) when no consumer is mounted (auto-dispose).
9. The Performance Section shall include three toggles (`MvToggle`): Impeller engine on/off, Parallax effects, ABR (re-export of the Player section toggle for visibility — single source of truth lives in `decoderConfigProvider`).

### Requirement 8: About section

**Objective:** Как пользователь, я хочу видеть версию приложения, номер сборки, имя устройства и контактные ссылки в секции About, чтобы при репорте бага иметь под рукой все идентификаторы.

#### Acceptance Criteria

1. The About Section shall display the app version and build number sourced from a generated constants file or `package_info_plus` (whichever is already wired); if neither is available the section shall display literal placeholder strings without crashing.
2. The About Section shall display device name (`Platform.localHostname` or equivalent) and OS version (`Platform.operatingSystemVersion`).
3. The About Section shall include an Account stub row reading «Не выполнен вход» when no auth provider is wired (current state).
4. The About Section shall include 2 ghost-button rows for «Политика конфиденциальности» and «Условия использования» that open URL stubs (no real legal content required for this spec).
5. The About Section shall not introduce any new auth, login, or HTTP infrastructure.

### Requirement 9: Reset section

**Objective:** Как пользователь, я хочу одной кнопкой сбросить настройки до дефолтов с подтверждением, чтобы безопасно вернуть приложение к рабочему состоянию после экспериментов.

#### Acceptance Criteria

1. The Reset Section shall render a single `MvButton.accent` labelled «Сбросить настройки».
2. On activation the Reset Section shall present a `showDialog` confirm with «Отмена» and «Сбросить» actions.
3. On confirm the Reset Section shall (a) call `ref.read(themeProvider.notifier).setPalette(AppPaletteName.noirCobalt)`, (b) reset `decoderConfigProvider` to `const DecoderConfig()`, and (c) leave `baseUrlProvider` unchanged (URL is environment-bound, not a "preference").
4. The Reset Section shall not delete any persistent storage outside the documented providers — no file-system wipes, no cache invalidation beyond what the providers themselves trigger.

### Requirement 10: Custom toggle widget

**Objective:** Как пользователь, я хочу видеть кастомные тогглы в дизайн-стиле (44×24 pill с accent-glow), а не дефолтный Material `Switch`, чтобы интерфейс соответствовал handoff-эталону.

#### Acceptance Criteria

1. The MvToggle widget shall render at 44 × 24 logical pixels with rounded corners equal to height/2 (full pill).
2. The MvToggle widget shall use the active palette's `accent` for the on-state fill and `surface2` for the off-state fill.
3. The MvToggle widget shall animate the thumb's horizontal position over 200 ms using `Curves.easeInOut`, transitioning via `AnimatedAlign` or `AnimatedPositioned` (no `AnimatedContainer.width` for the thumb).
4. While in the on-state the MvToggle widget shall display an accent glow using a `BoxShadow` whose `blurRadius` is ≤ `kSafeShadowBlurMax` (12 dp).
5. The MvToggle widget shall be focusable and shall display a `SafeFocusRing` when focused.
6. The MvToggle widget shall not use `BackdropFilter`, `ShaderMask`, or any saveLayer-triggering decoration.

### Requirement 11: Custom picker widget

**Objective:** Как пользователь, я хочу выбирать дискретные опции (decoder mode, buffer mode, font-pair) через ряд таблеток с подсвеченной активной, чтобы видеть все варианты сразу и переключаться D-pad-стрелками.

#### Acceptance Criteria

1. The MvPicker widget shall accept a generic `List<T>` of options, a current `T value`, an `ValueChanged<T> onChanged`, and a `String Function(T) labelOf`.
2. The MvPicker widget shall render exactly one chip per option in a horizontal `Row` (or wrapping `Wrap` when overflow).
3. The MvPicker widget shall mark the chip whose option equals `value` (using `==`) as active using the active palette's `accent` background.
4. The MvPicker widget shall make each non-active chip focusable; activation (OK / tap) shall call `onChanged(option)` exactly once.
5. The MvPicker widget shall not rebuild on `themeProvider` ticks unless the active palette actually changed (achieved by reading palette via `Theme.of(context)` in build).
6. The MvPicker widget shall be composed from `MvButton` / atoms — no duplicated chip rendering code.

### Requirement 12: Performance budget compliance (TV-Mali)

**Objective:** Как пользователь TV-бокса rtd2851a, я хочу плавные D-pad переходы между секциями и безлаговый live-FPS readout, чтобы Settings экран не нарушал общий перформанс-бюджет 16.7 мс/кадр.

#### Acceptance Criteria

1. The Settings Screen shall not contain any `BackdropFilter` instance.
2. The Settings Screen shall not contain any `ShaderMask` instance.
3. The Settings Screen shall not contain any `BoxShadow` whose `blurRadius` exceeds `kSafeShadowBlurMax` (12 dp).
4. The Settings Screen shall use Leanback timings: section switch ≤ 250 ms, focus animation 150 ms, debounced focus-driven side-effects 400 ms.
5. The Settings Screen shall wrap each `StatTile` consuming the per-tick `perfMetricsProvider` in a dedicated `RepaintBoundary` and a `const`-constructor parent.
6. The Settings Screen shall use `Transform.scale` (not `AnimatedContainer.width`) for any focus-grow effect on toggles, pickers, or buttons.
7. The Settings Screen shall, when measured on rtd2851a in `--profile` build, achieve avg `GPURasterizer::Draw` ≤ 16.7 ms during sidebar-keyboard scrolling and during Performance section visibility (live metrics ON).

### Requirement 13: Backward compatibility

**Objective:** Как поддерживатель проекта, я хочу чтобы переписка settings_screen не сломала ни router, ни существующие зелёные тесты, чтобы релиз settings-redesign был безопасным single-feature change.

#### Acceptance Criteria

1. The Settings Module shall keep the `/settings` route exported from the existing router file unchanged.
2. The Settings Module shall keep `SettingsScreen` as the public widget name and constructor signature `const SettingsScreen({super.key})`.
3. The Settings Module shall not delete or rename any public symbol previously exported from `lib/features/settings/*`.
4. The Settings Module shall keep all currently-green tests green; new tests added by this spec shall not depend on test fixtures from closed specs.
5. The Settings Module shall pass `flutter analyze` with zero new warnings or errors.

### Requirement 14: Testability and isolation

**Objective:** Как разработчик, я хочу запускать unit/widget тесты для каждой секции отдельно (без подъёма всего экрана), чтобы тестирование было быстрым и target-friendly.

#### Acceptance Criteria

1. The Settings Module shall expose each section widget (`SectionAppearance`, `SectionPlayer`, `SectionNetwork`, `SectionPerformance`, `SectionAbout`, `SectionReset`) as a public `const`-constructable widget testable in isolation with a `ProviderScope` override.
2. The Settings Module shall provide a widget test that overrides `themeProvider` and asserts that activating a swatch in `SectionAppearance` results in `ref.read(themeProvider.notifier).setPalette(name)` being called exactly once (verified via a fake notifier override).
3. The Settings Module shall provide a unit test for `perfMetricsProvider` that asserts the timings callback subscription is registered on first listen and disposed on last listener removal (auto-dispose contract).
4. The Settings Module shall provide a widget test for `MvToggle` asserting the thumb animates 200 ms, the on-state fill matches `palette.accent`, and the focus ring renders when focused.
5. The Settings Module shall provide a golden test for the palette swatch grid (6 swatches) on the default `noirCobalt` palette, asserting deterministic rendering.

### Requirement 15: Boundary integrity

**Objective:** Как owner закрытых foundation-спецов, я хочу чтобы settings-redesign не модифицировал и не дублировал foundation-код, чтобы revalidation triggers не активировались.

#### Acceptance Criteria

1. The Settings Module shall import `themeProvider`, `AppPaletteName`, `AppPalette`, `AppRadius`, and `MegaVTextStyles` only from their canonical paths in `lib/core/theme/*`.
2. The Settings Module shall import `MvButton`, `MvIconButton`, `Chip`, `SectionTitle`, `RemoteHint`, `Brand` only via barrel `package:megav_iptv/core/ui/atoms/atoms.dart`.
3. The Settings Module shall import `SafePill`, `SafeFocusRing`, `SafeFilmGrain`, `kSafeShadowBlurMax`, `ComputedColors` only from `lib/core/perf/perf_safe_widgets.dart` (or `computed_colors.dart` as applicable).
4. The Settings Module shall not modify any file outside `lib/features/settings/**`, `lib/core/perf/perf_metrics_provider.dart` (NEW), and the `test/features/settings/**` tree.
5. The Settings Module shall not add any new package dependency to `pubspec.yaml`.
