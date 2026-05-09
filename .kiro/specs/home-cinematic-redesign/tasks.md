# Implementation Plan — home-cinematic-redesign

> Спек: `home-cinematic-redesign`. См. `requirements.md` (13 requirements) и `design.md` (8 widgets + flag provider + 8 tests).
>
> Принципы:
> 1. **Closed-spec безопасность**: 0 writes в `lib/features/home/widgets/`, 0 writes в `cinema_row.dart` / `cinema_card.dart` / `_card_poster.dart` / `_grid_tokens.dart` / `home_screen.dart`. Только READ-ONLY импорты.
> 2. **Один файл = один atom-обёртка**, parallel-friendly. Каждая sub-task ставит свой Key, помечает _Boundary:_ и регистрирует `_Depends:_` cross-task.
> 3. **Perf gate**: каждый task проходит `grep "BackdropFilter\|ShaderMask\|ImageFilter\.blur"` → 0 hits, и `grep -E "blurRadius:\s*([2-9][0-9]+|1[3-9])"` → 0 hits в `lib/features/home/cinematic/`. Final task 5.1 повторяет это глобально.
> 4. **Regression gate**: финальный task 5.3 запускает `flutter test`, ожидание — 94/94 baseline + все новые green.
>
> Implementation order ≠ numerical order только в task 4: live-strip subtask зависит от atoms `Chip` + `MvTrack` (готовы в #14), но никаких внутрикадровых cross-task зависимостей внутри спека нет — каждая phase идёт sequentially.

---

## 1. Foundation: scaffold + flag + entry

- [x] 1.1 Создать директорию + provider flag
  - Создать `megav_iptv/lib/features/home/cinematic/` directory.
  - Создать `megav_iptv/lib/features/home/cinematic/use_cinematic_home_provider.dart` с:
    - `const bool kCinematicHomeDefault = false;` (single source of truth, Req 11.4).
    - `final useCinematicHomeProvider = StateProvider<bool>((ref) => kCinematicHomeDefault);`.
  - Наблюдаемое: `flutter analyze megav_iptv/lib/features/home/cinematic/` чисто; `flutter test` 94/94 не сломан.
  - _Requirements: 11.1, 11.2, 11.3, 11.4_
  - _Boundary: cinematic flag provider_

- [x] 1.2 Skeleton `CinematicHomeScreen` + entry switch
  - Создать `megav_iptv/lib/features/home/cinematic/cinematic_home_screen.dart` с `class CinematicHomeScreen extends ConsumerStatefulWidget` (Req 1.1).
  - В `build` — `Scaffold(body: SafeArea(child: const SizedBox.shrink()))` + root `Key('cinematic-home-root')` (placeholder; subtree будет заполнена в phase 2-4).
  - **Entry switch** — реализовать **Option B** из design.md: зарегистрировать новый `go_router` route `/home-cinematic` параллельно с существующим `/home` (или эквивалент). Existing route entries не модифицируются. Один файл (router / main) получает строго ONE-LINE добавление новой route entry. Если выбран не go_router — implementer документирует решение в commit message.
  - **Альтернативно (Option A)** допустима ONE-LINE замена `HomeScreen()` → `useCinematicHomeProvider`-aware builder в одном существующем файле, при условии что строк изменений действительно одна.
  - Наблюдаемое: legacy `HomeScreen` остаётся reachable; новый route reachable; `flutter analyze` чисто; `flutter test` 94/94 не сломан; root widget имеет `Key('cinematic-home-root')`.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 10.5, 10.6, 11.1, 11.3_
  - _Depends: 1.1_
  - _Boundary: cinematic_home_screen scaffold + entry_

- [x] 1.3 Smoke test для пустого скелета
  - Создать `megav_iptv/test/features/home/cinematic/cinematic_home_screen_smoke_test.dart`.
  - Тест pump'ит `CinematicHomeScreen` внутри `ProviderScope` + `MaterialApp` с замоканной темой; `await tester.pump(); await tester.pump();` → ожидает no exception + `find.byKey(const Key('cinematic-home-root'))` finds one.
  - Наблюдаемое: `flutter test test/features/home/cinematic/cinematic_home_screen_smoke_test.dart` зелёный; полный `flutter test` 94/94 + 1 новый = 95/95.
  - _Requirements: 12.2, 13.1_
  - _Depends: 1.2_
  - _Boundary: smoke test scaffold_

---

## 2. Hero + GenreTabs

- [ ] 2.1 `CinematicHeroSection`
  - Создать `megav_iptv/lib/features/home/cinematic/cinematic_hero_section.dart` с `class CinematicHeroSection extends ConsumerWidget` (Req 2).
  - Build tree: `Stack(children: [SafeBackdrop(image: ...), DecoratedBox(decoration: BoxDecoration(gradient: combinedHeroGradient(palette))), SafeFilmGrain(), Positioned(content)])`.
  - Content column: italic title через `Theme.of(context).megavText.displayLarge.copyWith(fontStyle: FontStyle.italic)`; meta row `Chip(variant: ChipVariant.live, label: 'LIVE')` + `MMLogo` + label через `MegaVTextStyles.metaMono`; primary action `MvButton.primary(label: 'Смотреть')` с `FocusNode` (initially focused on mount).
  - Title `Shadow(blurRadius: kSafeShadowBlurMax)` — НЕ выше (Req 9.2).
  - Любой stream-consumer (e.g., progress) обёрнут в private `class _HeroProgress extends ConsumerWidget` под `RepaintBoundary` с `const _HeroProgress()` parent ctor (Req 9.6).
  - Корневой widget получает `Key('cinematic-hero')` (Req 13.1).
  - **Perf gate**: `grep -E "BackdropFilter|ShaderMask|ImageFilter\.blur" lib/features/home/cinematic/cinematic_hero_section.dart` → 0; `grep -E "blurRadius:\s*([2-9][0-9]+|1[3-9])" .../cinematic_hero_section.dart` → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится без exception в test; key присутствует.
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 8.1, 8.2, 8.4, 9.1, 9.2, 9.3, 9.6, 13.1_
  - _Depends: 1.2_
  - _Boundary: CinematicHeroSection_

- [ ] 2.2 `CinematicHeroSection` widget test
  - Создать `megav_iptv/test/features/home/cinematic/cinematic_hero_section_test.dart`.
  - Тест 1: pump с моком `NowPlayingItem`, ожидает `find.byKey(const Key('cinematic-hero'))` finds one + `find.byType(SafeBackdrop)` ≥ 1 + `find.byType(SafeFilmGrain)` ≥ 1.
  - Тест 2: проверка отсутствия forbidden — `find.byType(BackdropFilter)` finds none.
  - Тест 3: title использует italic style — `tester.widget<Text>(find.text(...))` имеет `style.fontStyle == FontStyle.italic`.
  - Наблюдаемое: 3 теста зелёные; общий `flutter test` 94 + 1 + 1 файл (3 теста) = 98 всего.
  - _Requirements: 12.1, 13.1_
  - _Depends: 2.1_
  - _Boundary: hero widget test_

- [ ] 2.3 `CinematicGenreTabsBar`
  - Создать `megav_iptv/lib/features/home/cinematic/cinematic_genre_tabs_bar.dart` с `class CinematicGenreTabsBar extends ConsumerWidget` (Req 3).
  - Build tree: `Stack(children: [SizedBox(height:..., child: GenreTabs(tabs: ..., activeIndex: ..., onSelected: ...)), Positioned(left:0, top:0, bottom:0, width: 32, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: centerLeft, end: centerRight, colors: [palette.background, palette.background.withAlpha(0)]))))), Positioned(right:0, top:0, bottom:0, width: 32, child: ... mirrored ...)])` — ТОЛЬКО `DecoratedBox` + `LinearGradient`, никакого `ShaderMask` (Req 3.4, 9.1).
  - Boundary semantics: при достижении последнего tab focus НЕ wrap'ится; surface event через callback (Req 3.5) — допустимо проксировать через `FocusTraversalGroup` или явный callback из `GenreTabs` атома.
  - Active selection и counts читаются через провайдер (либо существующий категорий, либо тонкий derived в `use_cinematic_home_provider.dart` — implementer выбирает менее-инвазивный путь).
  - Корневой widget получает `Key('cinematic-genre-tabs')`.
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится; key present; `find.byType(ShaderMask)` finds none.
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 9.1, 9.2, 13.1_
  - _Depends: 1.2_
  - _Boundary: CinematicGenreTabsBar_

- [ ] 2.4 `CinematicGenreTabsBar` widget test
  - Создать `megav_iptv/test/features/home/cinematic/cinematic_genre_tabs_bar_test.dart`.
  - Тест 1: pump с 5 жанрами, активный=2; ожидает `find.byKey(const Key('cinematic-genre-tabs'))` + `find.byType(GenreTabs)` finds one.
  - Тест 2: `find.byType(ShaderMask)` finds none (Req 3.4 enforcement).
  - Тест 3: edge-fade overlays присутствуют — `find.byType(DecoratedBox)` ≥ 2 (left + right fade).
  - Наблюдаемое: 3 теста зелёные.
  - _Requirements: 12.1, 13.1, 13.3_
  - _Depends: 2.3_
  - _Boundary: genre tabs bar test_

---

## 3. Dual-rail + section title

- [ ] 3.1 `CinematicRail` (внутренний rail-builder)
  - Создать `megav_iptv/lib/features/home/cinematic/cinematic_rail.dart` с `class CinematicRail extends StatefulWidget` (params: `orientation: PosterOrientation`, `items: List<NowPlayingItem>`, `onItemTap`, `onItemFocus`).
  - Внутри: `ListView.builder(scrollDirection: Axis.horizontal, cacheExtent: 1500, addAutomaticKeepAlives: true, addRepaintBoundaries: true, clipBehavior: Clip.none, itemCount: items.length, itemBuilder: ...)` (Req 9.4).
  - Каждый item: `Focus(onFocusChange: ..., child: AnimatedScale(scale: focused ? 1.08 : 1.0, duration: Duration(milliseconds: 150), curve: Curves.easeOutCubic, child: Poster(orientation: widget.orientation, image: ..., hideText: true, isFocused: focused)))` (Req 4.2, 4.3, 8.3, 8.4).
  - Focus-debounce 400 ms через `Timer` для heavy `onItemFocus` (Req 9.5). Sync clear (`null`-clear) без debounce.
  - READ-ONLY импорт `pickColumns` из `lib/features/home/widgets/_grid_tokens.dart` для размера visible window (Req 4.6, 10.3) — НЕ модифицировать функцию.
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; rail pump'ится; ListView имеет правильные перф-флаги (можно проверить через `tester.widget<ListView>(find.byType(ListView)).cacheExtent == 1500.0`).
  - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.6, 8.1, 8.3, 8.4, 9.1, 9.2, 9.4, 9.5, 10.2, 10.3_
  - _Depends: 1.2_
  - _Boundary: CinematicRail_

- [ ] 3.2 `CinematicDualRail` façade
  - Создать `megav_iptv/lib/features/home/cinematic/cinematic_dual_rail.dart` с `class CinematicDualRail extends StatelessWidget`, named ctors `.landscape(...)` и `.portrait(...)`.
  - Каждый ctor возвращает `CinematicRail(orientation: ...)` со стабильным Key:
    - landscape → `Key('cinematic-dual-rail-landscape')`
    - portrait → `Key('cinematic-dual-rail-portrait')`
  - `CinematicDualRail.landscape` рендерит landscape rail; `.portrait` — portrait rail. Композиция «оба сразу» делается caller'ом (CinematicHomeScreen) через два инстанса.
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: оба ctor pump'ятся; keys присутствуют.
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 13.1_
  - _Depends: 3.1_
  - _Boundary: CinematicDualRail facade_

- [ ] 3.3 `CinematicDualRail` widget test
  - Создать `megav_iptv/test/features/home/cinematic/cinematic_dual_rail_test.dart`.
  - Тест 1: `CinematicDualRail.landscape(items: [3 items])` — `find.byKey(const Key('cinematic-dual-rail-landscape'))` finds one; `find.byType(Poster)` finds 3 (или fewer in test viewport — ≥ 1 acceptable).
  - Тест 2: `CinematicDualRail.portrait(items: [3 items])` — `find.byKey(const Key('cinematic-dual-rail-portrait'))` finds one.
  - Тест 3: ListView имеет `cacheExtent == 1500.0`, `addAutomaticKeepAlives == true`, `addRepaintBoundaries == true`, `clipBehavior == Clip.none` (Req 9.4 enforcement).
  - Тест 4: `find.byType(BackdropFilter)` finds none, `find.byType(ShaderMask)` finds none (Req 9.1 enforcement).
  - Наблюдаемое: 4 теста зелёные.
  - _Requirements: 9.1, 9.4, 12.1, 13.1, 13.3_
  - _Depends: 3.2_
  - _Boundary: dual rail test_

- [ ] 3.4 `CinematicSectionTitle`
  - Создать `megav_iptv/lib/features/home/cinematic/cinematic_section_title.dart` с `class CinematicSectionTitle extends StatelessWidget` (params: `label: String`, `emphasis: String`, `count: int?`, `onMoreTap: VoidCallback?`).
  - Build: тонкая обёртка над `SectionTitle` атом — пробрасывает label / italic em / count / onMoreTap.
  - Italic em применяется через атом (атом уже умеет italic em через `MegaVTextStyles.displayMedium`).
  - Корневой widget получает `Key('cinematic-section-title-${label}')` или explicit `Key` если caller передал.
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится с разными комбинациями (count=null, count=12, onMoreTap=null, onMoreTap=non-null).
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  - _Depends: 1.2_
  - _Boundary: CinematicSectionTitle_

- [ ] 3.5 `CinematicSectionTitle` widget test
  - Создать `megav_iptv/test/features/home/cinematic/cinematic_section_title_test.dart`.
  - Тест 1: `CinematicSectionTitle(label: 'Сейчас в', emphasis: 'эфире')` — `find.byType(SectionTitle)` finds one; `find.text('эфире')` finds one.
  - Тест 2: с `count: 12` — обнаружить число в дереве (через `find.textContaining('12')`).
  - Тест 3: с `onMoreTap` non-null — focusable trailing action присутствует (`find.byType(MvButton)` или эквивалент атома).
  - Наблюдаемое: 3 теста зелёные.
  - _Requirements: 12.1_
  - _Depends: 3.4_
  - _Boundary: section title test_

---

## 4. Live strip + remote hint footer

- [ ] 4.1 `CinematicLiveStrip` + private `_LiveProgress`
  - Создать `megav_iptv/lib/features/home/cinematic/cinematic_live_strip.dart` с:
    - `class CinematicLiveStrip extends ConsumerWidget` (public, Req 6.1).
    - В build: `Row(children: [Chip(variant: ChipVariant.live, label: 'LIVE'), MMLogo(...), Column(crossAxisAlignment: start, children: [Text(currentTitle, style: theme.megavText.headline), Text(nextLabel, style: theme.megavText.metaMono)]), Expanded(child: const _LiveProgress())])`.
    - Private `class _LiveProgress extends ConsumerWidget` с `const _LiveProgress();` (parent ctor const → no rebuild on parent).
    - В `_LiveProgress.build`: `RepaintBoundary(child: MvTrack(progress: ref.watch(...)))` — stream/provider-tick поглощается RepaintBoundary'ем (Req 6.3, 9.6).
  - Pulse в `Chip(variant: live)` уже изолирован в атоме (Req 6.1 satisfied by atom).
  - Корневой widget получает `Key('cinematic-live-strip')`.
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится; key present; `find.byType(MvTrack)` finds one (внутри `_LiveProgress`).
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 9.1, 9.2, 9.6, 13.1_
  - _Depends: 1.2_
  - _Boundary: CinematicLiveStrip_

- [ ] 4.2 `CinematicLiveStrip` widget test
  - Создать `megav_iptv/test/features/home/cinematic/cinematic_live_strip_test.dart`.
  - Тест 1: pump с моком; ожидает `find.byKey(const Key('cinematic-live-strip'))` finds one; `find.byType(Chip)` finds one (live variant); `find.byType(MvTrack)` finds one; `find.byType(MMLogo)` finds one.
  - Тест 2: progress consumer wrapped в `RepaintBoundary` — обнаруживается ancestor через `find.ancestor(of: find.byType(MvTrack), matching: find.byType(RepaintBoundary))`.
  - Наблюдаемое: 2 теста зелёные.
  - _Requirements: 12.1, 13.1, 9.6_
  - _Depends: 4.1_
  - _Boundary: live strip test_

- [ ] 4.3 `CinematicRemoteHintFooter`
  - Создать `megav_iptv/lib/features/home/cinematic/cinematic_remote_hint_footer.dart` с `class CinematicRemoteHintFooter extends StatelessWidget` (Req 7).
  - Build: `RepaintBoundary(child: ExcludeFocus(child: IgnorePointer(child: const RemoteHint())))`.
  - Конструктор `const CinematicRemoteHintFooter({super.key})` — позволяет caller поместить `const CinematicRemoteHintFooter()` в дерево.
  - Корневой widget получает `Key('cinematic-remote-hint')` (через caller или внутренний const-key).
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится; const ctor; `find.byType(IgnorePointer)` finds one; `find.byType(RemoteHint)` finds one.
  - _Requirements: 7.1, 7.2, 7.3, 9.1, 9.2, 9.6, 13.1_
  - _Depends: 1.2_
  - _Boundary: CinematicRemoteHintFooter_

- [ ] 4.4 `CinematicRemoteHintFooter` widget test
  - Создать `megav_iptv/test/features/home/cinematic/cinematic_remote_hint_footer_test.dart`.
  - Тест 1: pump; `find.byKey(const Key('cinematic-remote-hint'))` finds one; `find.byType(RemoteHint)` finds one.
  - Тест 2: `find.byType(IgnorePointer)` finds one — focus-traversal не блокирует.
  - Тест 3: const ctor reachable — `const CinematicRemoteHintFooter()` компилируется (статика проверки достаточно — тест просто instantiates `const`).
  - Наблюдаемое: 3 теста зелёные.
  - _Requirements: 7.1, 7.2, 7.3, 12.1, 13.1_
  - _Depends: 4.3_
  - _Boundary: remote hint footer test_

---

## 5. Integration + regression + perf gate

- [ ] 5.1 Wire all components в `CinematicHomeScreen`
  - Модифицировать `megav_iptv/lib/features/home/cinematic/cinematic_home_screen.dart` (созданный в 1.2) — заполнить body composition согласно design.md §1 component layout:
    1. Status / brand bar row (Brand + StatusBar from atoms barrel).
    2. `CinematicGenreTabsBar`.
    3. `CinematicHeroSection`.
    4. `CinematicSectionTitle('Сейчас в', emphasis: 'эфире', count: ...)` + `CinematicDualRail.landscape(items: ...)`.
    5. `CinematicLiveStrip`.
    6. `CinematicSectionTitle('Фильмы', emphasis: '· каталог', count: ...)` + `CinematicDualRail.portrait(items: ...)`.
    7. `CinematicRemoteHintFooter`.
  - Wrapping scrollable: `CustomScrollView` (sliver list) ИЛИ `ListView` с теми же perf-флагами (`cacheExtent: 1500`, `addAutomaticKeepAlives: true`, `addRepaintBoundaries: true`, `clipBehavior: Clip.none`).
  - Все Keys из Req 13.1 mounted (каждая sub-component уже несёт свой Key из phase 2-4).
  - Hero `MvButton.primary` `FocusNode` initially focused on mount (Req 2.7).
  - **Perf gate**: `grep -rE "BackdropFilter|ShaderMask|ImageFilter\.blur" lib/features/home/cinematic/` → 0; `grep -rE "blurRadius:\s*([2-9][0-9]+|1[3-9])" lib/features/home/cinematic/` → 0.
  - Наблюдаемое: smoke test из 1.3 продолжает зелёный + теперь обнаруживает все 6 keys (Req 13.1) — обновить smoke test для проверки всех keys (часть этого task'а).
  - _Requirements: 1.1, 1.2, 1.3, 2.7, 9.1, 9.2, 9.3, 9.4, 13.1_
  - _Depends: 2.1, 2.3, 3.2, 3.4, 4.1, 4.3_
  - _Boundary: CinematicHomeScreen integration_

- [ ] 5.2 Regression test для `pickColumns`
  - Создать `megav_iptv/test/features/home/cinematic/pick_columns_regression_test.dart`.
  - Тест импортирует `pickColumns` из `package:megav_iptv/features/home/widgets/_grid_tokens.dart` (READ-ONLY).
  - Asserts: `pickColumns(1280) == 3`, `pickColumns(2560) == 4`, `pickColumns(3840) == 5` (Req 12.3, 10.3 защита).
  - Наблюдаемое: тест зелёный; защищает закрытый `home-grid-optimization` от случайных изменений из этого спека.
  - _Requirements: 10.3, 12.3_
  - _Depends: 1.1_
  - _Boundary: pickColumns regression_

- [ ] 5.3 Final regression — full `flutter test` + perf greps
  - Run `flutter test` в `megav_iptv/`. Ожидаемый итог: **94 baseline + новые cinematic tests все зелёные** (Req 12.4).
  - Подсчитать общее число тестов после landing — задокументировать в commit message (e.g., «94 + 18 новых = 112/112 зелёных»).
  - Run `flutter analyze megav_iptv/lib/features/home/cinematic/` — 0 issues (Req 13.2).
  - Run `grep -rE "BackdropFilter|ShaderMask|ImageFilter\.blur" megav_iptv/lib/features/home/cinematic/` → 0 hits (Req 9.1, 13.3).
  - Run `grep -rE "blurRadius:\s*([2-9][0-9]+|1[3-9])" megav_iptv/lib/features/home/cinematic/` → 0 hits (Req 9.2).
  - Verify `pubspec.yaml` без новых пакетов (Req 13.4) — diff vs main → no `pubspec.yaml` change.
  - Verify closed-spec файлы НЕ модифицированы — `git diff master --name-only -- megav_iptv/lib/features/home/widgets/ megav_iptv/lib/features/home/home_screen.dart` → empty (Req 10.1, 10.2, 10.5).
  - Manual VM Service smoke pass on rtd2851a (если доступен): avg `GPURasterizer::Draw ≤ 16.7 ms` при scroll по новому экрану (Req 9 acceptance).
  - Наблюдаемое: все checks зелёные; commit message содержит конкретные числа.
  - _Requirements: 9.1, 9.2, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 12.3, 12.4, 13.2, 13.3, 13.4_
  - _Depends: 5.1, 5.2, 4.4, 4.2, 3.5, 3.3, 2.4, 2.2, 1.3_
  - _Boundary: final regression gate_

- [ ] 5.4 Rollout flag flip (Stage 5) — opt-in
  - **Этот task делается ТОЛЬКО после ручной проверки на rtd2851a (см. 5.3 manual VM Service smoke).**
  - Изменить `kCinematicHomeDefault` в `use_cinematic_home_provider.dart` с `false` на `true` (один-line patch, Req 11.4 single source of truth).
  - Re-run `flutter test` — 94 + новые всё ещё зелёные.
  - Smoke test из 1.3 теперь по умолчанию рендерит cinematic вариант — обновить mock setup если нужно.
  - Commit message ясно отмечает: «Cinematic home enabled by default».
  - **Если manual smoke на TV не пройден — НЕ делать этот task; flag остаётся `false`, redesign reachable только через explicit route / provider-override.**
  - Наблюдаемое: после flip пользователь по умолчанию видит cinematic экран; legacy reachable через provider override (опц. через debug menu).
  - _Requirements: 11.1, 11.2, 11.3, 11.4_
  - _Depends: 5.3_
  - _Boundary: rollout flag flip_

---

## Implementation order

Внутри phase'ов sub-tasks независимы (помечены _Boundary:_), можно делать (P) parallel. Между phases — sequential per `_Depends:_`.

```
1.1 → 1.2 → 1.3
                ↘
                  2.1, 2.3 (P) → 2.2, 2.4 (P)
                  3.1 → 3.2 → 3.3 (P), 3.4 → 3.5 (P)
                  4.1 → 4.2 (P), 4.3 → 4.4 (P)
                ↙
              5.1 (depends on all phase-2/3/4 widget tasks)
              5.2 (depends on 1.1 only)
                ↓
              5.3 final regression
                ↓
              5.4 rollout flip (manual gate)
```

## Test count expectation

| Phase | New tests added | Cumulative |
|---|---|---|
| Phase 1 | 1 (smoke) | 95 |
| Phase 2 | 3 + 3 | 101 |
| Phase 3 | 4 + 3 | 108 |
| Phase 4 | 2 + 3 | 113 |
| Phase 5 | 1 (regression) | 114 |

Total expected after spec lands: **114 tests** (94 baseline + 20 new). Implementer должен зафиксировать актуальное число в commit message task 5.3.

## Perf gate summary (per-task enforcement)

Каждый task создающий новый файл в `lib/features/home/cinematic/` обязан локально пройти:

```bash
grep -rE "BackdropFilter|ShaderMask|ImageFilter\.blur" megav_iptv/lib/features/home/cinematic/
# expected: 0 hits

grep -rE "blurRadius:\s*([2-9][0-9]+|1[3-9])" megav_iptv/lib/features/home/cinematic/
# expected: 0 hits
```

Final task 5.3 повторяет это глобально + добавляет git diff проверку closed-spec immutability.
