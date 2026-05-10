# Implementation Plan — home-editorial-redesign

> Спек: `home-editorial-redesign`. См. `requirements.md` (13 requirements) и `design.md` (10 widgets + shared variant provider + 12 tests).
>
> Принципы:
> 1. **Closed-spec безопасность**: 0 writes в `lib/features/home/widgets/`, 0 writes в `cinema_row.dart` / `cinema_card.dart` / `_card_poster.dart` / `_grid_tokens.dart` / `home_screen.dart`. Только READ-ONLY импорты.
> 2. **Sibling-spec безопасность**: 0 writes в `lib/features/home/cinematic/*` (owned by `home-cinematic-redesign` #5). Только READ-ONLY type-imports для entry-switch и coexistence-теста.
> 3. **Один файл = один widget или atom-обёртка**, parallel-friendly. Каждая sub-task ставит свой Key, помечает _Boundary:_ и регистрирует `_Depends:_` cross-task.
> 4. **Perf gate**: каждый task проходит `grep "BackdropFilter\|ShaderMask\|ImageFilter\.blur"` → 0 hits, и `grep -E "blurRadius:\s*([2-9][0-9]+|1[3-9])"` → 0 hits в `lib/features/home/editorial/` + `lib/features/home/home_variant_provider.dart`. Final task 6.1 повторяет это глобально.
> 5. **Regression gate**: финальный task 6.3 запускает `flutter test`, ожидание — все ранее-зелёные тесты (94 baseline + cinematic-spec additions) + все новые editorial green.
> 6. **Coexistence gate**: task 6.2 проверяет что `homeVariantProvider == cinematic` mounts cinematic-screen, `editorial` mounts editorial-screen, `legacy` mounts legacy `HomeScreen` — без модификации cinematic-spec кода.

---

## 1. Foundation: shared variant provider + scaffold + entry

- [x] 1.1 Создать shared `home_variant_provider.dart`
  - Создать `megav_iptv/lib/features/home/home_variant_provider.dart` с:
    - `enum HomeVariant { cinematic, editorial, legacy }`.
    - `const HomeVariant kHomeVariantDefault = HomeVariant.cinematic;` (single source of truth, Req 11.6).
    - `const String _kHomeVariantPrefsKey = 'home_variant';`.
    - `class HomeVariantNotifier extends StateNotifier<HomeVariant>` с `_load(SharedPreferences)` и `Future<void> set(HomeVariant)` персистом.
    - `final sharedPreferencesProvider = Provider<SharedPreferences>((ref) { throw UnimplementedError(...); });` (override в main()).
    - `final homeVariantProvider = StateNotifierProvider<HomeVariantNotifier, HomeVariant>(...)`.
  - **Reconciliation с cinematic-spec'овским `useCinematicHomeProvider`**:
    - Если cinematic-spec уже зарегистрировал свой flag — добавить в этом же файле derived provider `final useCinematicHomeProviderEditorial = Provider<bool>((ref) => ref.watch(homeVariantProvider) == HomeVariant.cinematic);` под отдельным именем (избежать символьной коллизии). NO modification of cinematic-spec file.
    - Если cinematic-spec не зарегистрировал — оставить только `homeVariantProvider`.
    - Решение задокументировать в commit message.
  - Наблюдаемое: `flutter analyze megav_iptv/lib/features/home/home_variant_provider.dart` чисто; `flutter test` всё ещё зелёный (baseline + cinematic-spec).
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7, 13.4_
  - _Boundary: shared variant provider_

- [x] 1.2 Skeleton `EditorialHomeScreen` + entry switch
  - Создать `megav_iptv/lib/features/home/editorial/` directory.
  - Создать `megav_iptv/lib/features/home/editorial/editorial_home_screen.dart` с `class EditorialHomeScreen extends ConsumerStatefulWidget` (Req 1.1).
  - В `build` — `Scaffold(body: SafeArea(child: const SizedBox.shrink()))` + root `Key('editorial-home-root')` (placeholder; subtree будет заполнена в phase 2-5).
  - **Entry switch** — реализовать **Option B** из design.md: зарегистрировать новый `go_router` route `/home-editorial` параллельно с существующими `/home` (legacy) и `/home-cinematic` (cinematic-spec). Existing route entries **не модифицируются** (особенно — никаких изменений в файлах cinematic-spec). Один файл (router / main) получает строго ONE-LINE добавление новой route entry. Если выбран не go_router — implementer документирует решение в commit message.
  - **Альтернативно (Option A)** допустима ONE-LINE замена / расширение существующего entry-switch на `homeVariantProvider`-aware builder в одном существующем файле (не cinematic-spec файл!). Решение и обоснование — в commit message.
  - **CRITICAL**: задача НЕ модифицирует ни один файл под `lib/features/home/cinematic/`. Если cinematic-spec уже владеет entry-switch файлом, который технически тоже является «единственным» candidate — реализовать через Option B (новый route, не trogая cinematic entry-switch).
  - Наблюдаемое: legacy `HomeScreen` остаётся reachable; `CinematicHomeScreen` остаётся reachable; новый `EditorialHomeScreen` route reachable; `flutter analyze` чисто; `flutter test` всё ещё зелёный; root widget имеет `Key('editorial-home-root')`; `git diff master --name-only -- megav_iptv/lib/features/home/cinematic/` empty.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 10.1, 10.2, 10.5, 10.6, 11.3, 11.4_
  - _Depends: 1.1_
  - _Boundary: editorial_home_screen scaffold + entry_

- [x] 1.3 Smoke test для пустого скелета
  - Создать `megav_iptv/test/features/home/editorial/editorial_home_screen_smoke_test.dart`.
  - Тест pump'ит `EditorialHomeScreen` внутри `ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(MockSharedPreferences())])` + `MaterialApp` с замоканной темой; `await tester.pump(); await tester.pump();` → ожидает no exception + `find.byKey(const Key('editorial-home-root'))` finds one.
  - Наблюдаемое: `flutter test test/features/home/editorial/editorial_home_screen_smoke_test.dart` зелёный; полный `flutter test` всё ещё green (baseline + cinematic + 1 новый editorial).
  - _Requirements: 12.2, 13.1_
  - _Depends: 1.2_
  - _Boundary: smoke test scaffold_

---

## 2. Brand header + masthead

- [x] 2.1 `EditorialBrandHeader`
  - Создать `megav_iptv/lib/features/home/editorial/editorial_brand_header.dart` с `class EditorialBrandHeader extends StatelessWidget` (params: `scale: double = 1.4`).
  - Build: `Row(children: [Transform.scale(scale: scale, alignment: Alignment.centerLeft, child: const Brand()), const Spacer(), const StatusBar()])`.
  - Корневой widget получает `Key('editorial-brand-header')`.
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится; key present; `find.byType(Brand)` finds one; `find.byType(StatusBar)` finds one.
  - _Requirements: 13.1_
  - _Depends: 1.2_
  - _Boundary: EditorialBrandHeader_

- [x] 2.2 `EditorialBrandHeader` widget test
  - Создать `megav_iptv/test/features/home/editorial/editorial_brand_header_test.dart`.
  - Тест 1: pump; `find.byKey(const Key('editorial-brand-header'))` finds one; `find.byType(Brand)` finds one; `find.byType(StatusBar)` finds one.
  - Тест 2: scale параметр применяется — `find.byType(Transform)` finds one с `Transform.scale` matrix.
  - Наблюдаемое: 2 теста зелёные.
  - _Requirements: 12.1, 13.1_
  - _Depends: 2.1_
  - _Boundary: brand header test_

- [x] 2.3 `EditorialMasthead`
  - Создать `megav_iptv/lib/features/home/editorial/editorial_masthead.dart` с `class EditorialMasthead extends StatelessWidget` (params: `label: String`, `emphasis: String`, `dateLine: String`, `issueNumber: int`).
  - Build tree: `Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line)))) → Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Expanded(child: RichText(text: TextSpan(children: [TextSpan(text: label, style: theme.megavText.displayLarge), TextSpan(text: ' $emphasis', style: theme.megavText.displayLarge.copyWith(fontStyle: FontStyle.italic, color: palette.textDim))]))), Text('$dateLine · ВЫПУСК №${issueNumber.toString().padLeft(3, '0')}', style: theme.megavText.metaMono.copyWith(color: palette.textMute))])`.
  - Title `Shadow(blurRadius: kSafeShadowBlurMax)` — НЕ выше (Req 9.2).
  - Корневой widget получает `Key('editorial-masthead')` (Req 13.1).
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится; key present; em-fragment имеет italic FontStyle.
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 9.1, 9.2, 13.1_
  - _Depends: 1.2_
  - _Boundary: EditorialMasthead_

- [x] 2.4 `EditorialMasthead` widget test
  - Создать `megav_iptv/test/features/home/editorial/editorial_masthead_test.dart`.
  - Тест 1: pump с label='Главная', emphasis='сегодня', dateLine='9 МАЯ 2026', issueNumber=127; ожидает `find.byKey(const Key('editorial-masthead'))` finds one; `find.textContaining('Главная')` finds one; `find.textContaining('сегодня')` finds one (italic em); `find.textContaining('9 МАЯ 2026 · ВЫПУСК №127')` finds one.
  - Тест 2: italic em — обнаружить `TextSpan` с `fontStyle == FontStyle.italic` через `find.byType(RichText)` walk.
  - Тест 3: hairline border — `find.byType(Container)` finds one с `BoxDecoration.border?.bottom != BorderSide.none`.
  - Тест 4: `find.byType(BackdropFilter)` finds none, `find.byType(ShaderMask)` finds none (Req 9.1 enforcement).
  - Наблюдаемое: 4 теста зелёные.
  - _Requirements: 12.1, 13.1, 13.3_
  - _Depends: 2.3_
  - _Boundary: masthead test_

---

## 3. Hero section + side card

- [x] 3.1 `EditorialSideCard`
  - Создать `megav_iptv/lib/features/home/editorial/editorial_side_card.dart` с:
    - `class EditorialSideCard extends StatefulWidget` (Focus state needed).
    - Named ctors: `.next({required NowPlayingItem item, required String remaining})` (label = 'ДАЛЕЕ В ЭФИРЕ'), `.featured({required NowPlayingItem item, required String remaining})` (label = 'РЕКОМЕНДУЕМ').
  - Build: `Focus(onFocusChange: setState, child: SafeFocusRing(focused: _focused, child: DecoratedBox(decoration: BoxDecoration(color: palette.surface2.withOpacity(0.55), border: Border.all(color: palette.line), borderRadius: BorderRadius.circular(AppRadius.md)), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Poster.portrait(width: 84, height: 112, image: item.poster, hideText: true), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: metaMono.copyWith(color: palette.textMute)), Text(item.title, style: theme.megavText.displaySmall.copyWith(fontStyle: FontStyle.italic)), Text('${item.year} · ${item.genre}', style: theme.megavText.metaSmall.copyWith(color: palette.textDim)), Text(remaining, style: theme.megavText.metaMono.copyWith(color: palette.accent))]))]))))`.
  - **CRITICAL**: NO `BackdropFilter` — flat semi-opaque surface (Req 4.2).
  - Корневой widget получает `Key('editorial-side-card-${slot}')` где slot = 'next' или 'featured'.
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится для обоих ctor; keys present; `find.byType(BackdropFilter)` finds none.
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 9.1, 9.2, 13.1_
  - _Depends: 1.2_
  - _Boundary: EditorialSideCard_

- [x] 3.2 `EditorialSideCard` widget test
  - Создать `megav_iptv/test/features/home/editorial/editorial_side_card_test.dart`.
  - Тест 1: `EditorialSideCard.next(item: mockItem, remaining: 'через 55 мин')` — `find.byKey(const Key('editorial-side-card-next'))` finds one; `find.text('ДАЛЕЕ В ЭФИРЕ')` finds one; `find.text('через 55 мин')` finds one.
  - Тест 2: `EditorialSideCard.featured(item: mockItem, remaining: '2ч 06м')` — `find.byKey(const Key('editorial-side-card-featured'))` finds one; `find.text('РЕКОМЕНДУЕМ')` finds one.
  - Тест 3: `find.byType(BackdropFilter)` finds none (Req 4.2 enforcement).
  - Тест 4: `find.byType(SafeFocusRing)` finds one (focusable as a unit).
  - Наблюдаемое: 4 теста зелёные.
  - _Requirements: 4.2, 4.5, 12.1, 13.1, 13.3_
  - _Depends: 3.1_
  - _Boundary: side card test_

- [x] 3.3 `EditorialHeroSection`
  - Создать `megav_iptv/lib/features/home/editorial/editorial_hero_section.dart` с `class EditorialHeroSection extends ConsumerStatefulWidget` (params: `item`, `nextItem`, `featuredItem`, `onPlay`, `onFavoriteToggle`, `onEpgOpen`).
  - Build tree:
    ```
    Stack(children: [
      Positioned.fill(SafeBackdrop(image: item.backdrop, opacity: 0.35)),
      Positioned.fill(DecoratedBox(decoration: BoxDecoration(gradient: combinedHeroGradient(palette)))),
      Padding(padding: EdgeInsets.symmetric(horizontal: 56, vertical: 28), child: Row(crossAxisAlignment: start, children: [
        Stack(clipBehavior: Clip.none, children: [
          SizedBox(width: 420, height: 620, child: Poster.portrait(image: item.poster, hideText: true)),
          Positioned(left: -10, top: 20, child: Transform.rotate(angle: -math.pi / 2, alignment: Alignment.topLeft, child: _EditorsPickBadge(index: item.index)))
        ]),
        const SizedBox(width: 36),
        Expanded(child: _MetaColumn(item: item, nextItem: nextItem, featuredItem: featuredItem, onPlay: onPlay, onFavoriteToggle: onFavoriteToggle, onEpgOpen: onEpgOpen, heroFocus: _heroFocus))
      ]))
    ])
    ```
  - `_MetaColumn` (private widget внутри файла) композирует chips → italic display title (84sp italic) → mono meta-row (rating gold, year, genre, duration) → summary (body, maxWidth 540, maxLines 4) → `MvTrack` + ticks → action row (`MvButton.primary('Смотреть', focusNode: heroFocus)` + 2× `MvButton.ghost`) → side cards row (`Row(children: [Expanded(EditorialSideCard.next(...)), const SizedBox(width: 14), Expanded(EditorialSideCard.featured(...))])`).
  - `_EditorsPickBadge` (private widget) — `Container(decoration: BoxDecoration(color: palette.gold), padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text("EDITORS' PICK · ${index.toString().padLeft(2, '0')}", style: metaMono.copyWith(color: const Color(0xFF1A1208), fontWeight: FontWeight.w700, letterSpacing: 0.16)))` (Req 3.7 — static rotation, no animation).
  - Hero focus node initialized in `initState`, requested focus in first frame (Req 3.6).
  - Title `Shadow(blurRadius: kSafeShadowBlurMax)` — НЕ выше (Req 9.2).
  - Любой stream-consumer (e.g., progress) обёрнут в private `class _HeroProgress extends ConsumerWidget` под `RepaintBoundary` с `const _HeroProgress()` parent ctor (Req 9.6).
  - Корневой widget получает `Key('editorial-hero')` (Req 13.1).
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится; key present; `find.byType(SafeBackdrop)` ≥ 1; `find.byType(Poster)` ≥ 1 (hero poster); `find.byType(EditorialSideCard)` finds 2; `find.byType(BackdropFilter)` finds none.
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 9.1, 9.2, 9.3, 9.6, 13.1_
  - _Depends: 1.2, 3.1_
  - _Boundary: EditorialHeroSection_

- [x] 3.4 `EditorialHeroSection` widget test
  - Создать `megav_iptv/test/features/home/editorial/editorial_hero_section_test.dart`.
  - Тест 1: pump с моком `NowPlayingItem` × 3 (item, next, featured); ожидает `find.byKey(const Key('editorial-hero'))` finds one + `find.byType(SafeBackdrop)` ≥ 1 + 2× `EditorialSideCard`.
  - Тест 2: `find.byType(BackdropFilter)` finds none, `find.byType(ShaderMask)` finds none.
  - Тест 3: hero title использует italic style.
  - Тест 4: action row содержит `MvButton.primary` с focusNode.
  - Тест 5: `_EditorsPickBadge` rendered с `Transform.rotate` (`find.byType(Transform)` ≥ 1).
  - Наблюдаемое: 5 тестов зелёные.
  - _Requirements: 12.1, 13.1, 13.3_
  - _Depends: 3.3_
  - _Boundary: hero section test_

---

## 4. Bento grid + bento card

- [x] 4.1 `EditorialBentoCard`
  - Создать `megav_iptv/lib/features/home/editorial/editorial_bento_card.dart` с:
    - `class EditorialBentoCell` value-type (params: `item: NowPlayingItem`, `cols: int`, `rows: int`, `live: bool`).
    - `class EditorialBentoCard extends StatefulWidget` (params: `cell: EditorialBentoCell`, `onTap: VoidCallback`, `onFocusChange: ValueChanged<bool>?`).
  - Build:
    ```
    Focus(onFocusChange: ..., child: Transform.scale(scale: focused ? 1.04 : 1.0, child: SafeFocusRing(focused: focused, child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: focused ? [BoxShadow(blurRadius: kSafeShadowBlurMax, color: palette.accentGlow)] : null), child: ClipRRect(borderRadius: BorderRadius.circular(AppRadius.md), child: Stack(children: [
      Positioned.fill(child: Image(image: provider, fit: BoxFit.cover)),
      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x0D000000), Color(0xD9000000)])))),
      if (cell.live) Positioned(top: 12, left: 12, child: Chip(variant: ChipVariant.live, label: 'Live')),
      Positioned(left: 16, right: 16, bottom: 14, child: Column(crossAxisAlignment: start, children: [
        Text(cell.item.title, style: titleStyle),
        const SizedBox(height: 6),
        Text('${cell.item.year} · ${cell.item.genre} · ${cell.item.duration}', style: theme.megavText.metaMono.copyWith(color: Colors.white70, letterSpacing: 0.12))
      ]))
    ])))))
    ```
  - `titleStyle` selection: `(cell.cols >= 2 && cell.rows >= 2) ? displayMedium.copyWith(italic, fontSize: 36) : displaySmall.copyWith(italic, fontSize: 20)` (Req 6.2).
  - Focus-debounce 400 ms через `Timer` для heavy `onItemFocus` (Req 9.5). Sync clear (`null`-clear) без debounce.
  - Корневой widget получает `Key('editorial-bento-card-${cell.item.index}')` или explicit Key from caller.
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; pump'ится для обоих big и small вариантов; title font size меняется по cols/rows; `find.byType(BackdropFilter)` finds none.
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 9.1, 9.2, 9.3, 9.5, 13.1_
  - _Depends: 1.2_
  - _Boundary: EditorialBentoCard_

- [x] 4.2 `EditorialBentoCard` widget test
  - Создать `megav_iptv/test/features/home/editorial/editorial_bento_card_test.dart`.
  - Тест 1: pump с `cols=2, rows=2, live=true` — title font size ≈ 36; `find.byType(Chip)` finds one (live).
  - Тест 2: pump с `cols=1, rows=1, live=false` — title font size ≈ 20; `find.byType(Chip)` finds none.
  - Тест 3: `find.byType(BackdropFilter)` finds none; `find.byType(ShaderMask)` finds none.
  - Тест 4: focused state добавляет ровно один `BoxShadow` с `blurRadius == kSafeShadowBlurMax`.
  - Наблюдаемое: 4 теста зелёные.
  - _Requirements: 6.2, 6.3, 6.4, 9.1, 9.2, 12.1, 13.1, 13.3, 13.5_
  - _Depends: 4.1_
  - _Boundary: bento card test_

- [x] 4.3 `EditorialBentoGrid`
  - Создать `megav_iptv/lib/features/home/editorial/editorial_bento_grid.dart` с `class EditorialBentoGrid extends StatelessWidget` (params: `cells: List<EditorialBentoCell>`, `onItemTap`, `onItemFocus?`).
  - Layout primitive: implementer выбирает между:
    - **Option A** (preferred if no new package): `CustomMultiChildLayout` с custom `MultiChildLayoutDelegate` который computes positions per cell `(cols, rows)` over a 6-column / 220-lp-row grid с 16-lp gap.
    - **Option B**: ручной `Column` of `Row`s, где каждый row группирует cells в которые помещаются на этот row. Менее гибко, но проще.
    - **Option C** (NOT allowed): добавить `flutter_staggered_grid_view` в pubspec.yaml — Req 13.4 запрещает new packages. Если уже есть в pubspec — допустимо.
  - Решение задокументировать в commit message.
  - 6-column grid, row-height 220 lp, gap 16 lp (Req 5.2, 5.3).
  - Каждая cell — `EditorialBentoCard(cell: cell, onTap: () => onItemTap(cell.item), onFocusChange: ...)`.
  - Корневой widget получает `Key('editorial-bento-grid')`.
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится с 8 cells; key present; visible cards ≤ 12 (Req 9.7).
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 9.1, 9.2, 9.7, 13.1_
  - _Depends: 4.1_
  - _Boundary: EditorialBentoGrid_

- [x] 4.4 `EditorialBentoGrid` widget test
  - Создать `megav_iptv/test/features/home/editorial/editorial_bento_grid_test.dart`.
  - Тест 1: pump с 8 cells разных размеров (1×1, 2×1, 1×2, 2×2 mix) — `find.byKey(const Key('editorial-bento-grid'))` finds one; `find.byType(EditorialBentoCard)` finds 8 (или меньше если viewport not enough — ≥ 6 acceptable).
  - Тест 2: `find.byType(BackdropFilter)` finds none.
  - Тест 3: grid не имеет своего scroll (Req 5.6) — `find.descendant(of: find.byType(EditorialBentoGrid), matching: find.byType(Scrollable))` finds none.
  - Наблюдаемое: 3 теста зелёные.
  - _Requirements: 5.6, 9.1, 12.1, 13.1, 13.3_
  - _Depends: 4.3_
  - _Boundary: bento grid test_

---

## 5. Film-reel strip + section title + genre tabs bar

- [ ] 5.1 `EditorialFilmReelStrip`
  - Создать `megav_iptv/lib/features/home/editorial/editorial_film_reel_strip.dart` с `class EditorialFilmReelStrip extends StatelessWidget` (params: `channelCount: int`, `activeIndex: int`, `frameCount: int = 18`).
  - Build: `Row(children: [Text('КАНАЛЫ ↓', style: theme.megavText.metaMono.copyWith(color: palette.textMute, letterSpacing: 0.16)), const SizedBox(width: 18), Expanded(child: MvStrip(frameCount: frameCount, activeIndex: activeIndex)), Text('${(activeIndex + 1).toString().padLeft(2, '0')} / ${channelCount.toString().padLeft(3, '0')}', style: theme.megavText.metaMono.copyWith(color: palette.textMute, letterSpacing: 0.12))])`.
  - Корневой widget получает `Key('editorial-film-reel-strip')`.
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится; key present; `find.byType(MvStrip)` finds one; counter '05 / 124' формируется корректно.
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 9.1, 9.2, 13.1_
  - _Depends: 1.2_
  - _Boundary: EditorialFilmReelStrip_

- [ ] 5.2 `EditorialFilmReelStrip` widget test
  - Создать `megav_iptv/test/features/home/editorial/editorial_film_reel_strip_test.dart`.
  - Тест 1: pump с `channelCount=124, activeIndex=4, frameCount=18` — `find.byKey(const Key('editorial-film-reel-strip'))` finds one; `find.byType(MvStrip)` finds one; `find.text('КАНАЛЫ ↓')` finds one; `find.text('05 / 124')` finds one.
  - Тест 2: `find.byType(BackdropFilter)` finds none.
  - Наблюдаемое: 2 теста зелёные.
  - _Requirements: 7.1, 7.2, 7.3, 12.1, 13.1, 13.3_
  - _Depends: 5.1_
  - _Boundary: film-reel strip test_

- [ ] 5.3 `EditorialSectionTitle`
  - Создать `megav_iptv/lib/features/home/editorial/editorial_section_title.dart` с `class EditorialSectionTitle extends StatelessWidget` (params: `label: String`, `emphasis: String`, `count: int?`, `onMoreTap: VoidCallback?`).
  - Build: тонкая обёртка над `SectionTitle` атом — пробрасывает label / italic em / count / onMoreTap.
  - Italic em применяется через атом (атом уже умеет italic em через `MegaVTextStyles.displayMedium`).
  - Корневой widget получает `Key('editorial-section-title-${label}')` или explicit Key если caller передал.
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится с разными комбинациями.
  - _Requirements: 8.1, 8.2, 8.3, 8.5, 9.1, 9.2_
  - _Depends: 1.2_
  - _Boundary: EditorialSectionTitle_

- [ ] 5.4 `EditorialSectionTitle` widget test
  - Создать `megav_iptv/test/features/home/editorial/editorial_section_title_test.dart`.
  - Тест 1: `EditorialSectionTitle(label: 'Кино', emphasis: 'без расписания')` — `find.byType(SectionTitle)` finds one; `find.text('без расписания')` finds one.
  - Тест 2: с `count: 30` — `find.textContaining('30')` finds one.
  - Тест 3: с `onMoreTap` non-null — focusable trailing action присутствует.
  - Наблюдаемое: 3 теста зелёные.
  - _Requirements: 12.1_
  - _Depends: 5.3_
  - _Boundary: section title test_

- [ ] 5.5 `EditorialGenreTabsBar`
  - Создать `megav_iptv/lib/features/home/editorial/editorial_genre_tabs_bar.dart` с `class EditorialGenreTabsBar extends ConsumerWidget` (Req 8.4).
  - Build tree: `Stack(children: [SizedBox(height: ..., child: GenreTabs(tabs: ..., activeIndex: ..., onSelected: ...)), Positioned(left:0, top:0, bottom:0, width: 32, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: centerLeft, end: centerRight, colors: [palette.background, palette.background.withAlpha(0)]))))), Positioned(right:0, top:0, bottom:0, width: 32, child: ... mirrored ...)])` — ТОЛЬКО `DecoratedBox` + `LinearGradient`, никакого `ShaderMask` (Req 8.4, 9.1).
  - Корневой widget получает `Key('editorial-genre-tabs')`.
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится; key present; `find.byType(ShaderMask)` finds none.
  - _Requirements: 8.4, 8.5, 9.1, 9.2, 13.1_
  - _Depends: 1.2_
  - _Boundary: EditorialGenreTabsBar_

- [ ] 5.6 `EditorialGenreTabsBar` widget test
  - Создать `megav_iptv/test/features/home/editorial/editorial_genre_tabs_bar_test.dart`.
  - Тест 1: pump с 5 жанрами, активный=2; ожидает `find.byKey(const Key('editorial-genre-tabs'))` + `find.byType(GenreTabs)` finds one.
  - Тест 2: `find.byType(ShaderMask)` finds none (Req 8.4 enforcement).
  - Тест 3: edge-fade overlays присутствуют — `find.byType(DecoratedBox)` ≥ 2 (left + right fade).
  - Наблюдаемое: 3 теста зелёные.
  - _Requirements: 12.1, 13.1, 13.3_
  - _Depends: 5.5_
  - _Boundary: genre tabs bar test_

---

## 6. Integration + coexistence + regression + perf gate

- [ ] 6.1 Wire all components в `EditorialHomeScreen`
  - Модифицировать `megav_iptv/lib/features/home/editorial/editorial_home_screen.dart` (созданный в 1.2) — заполнить body composition согласно design.md §1 component layout:
    1. `EditorialBrandHeader`.
    2. `EditorialMasthead(label: 'Главная', emphasis: 'сегодня', dateLine: ..., issueNumber: ...)`.
    3. `EditorialHeroSection(item: ..., nextItem: ..., featuredItem: ..., onPlay: ..., onFavoriteToggle: ..., onEpgOpen: ...)`.
    4. `EditorialGenreTabsBar`.
    5. `EditorialSectionTitle(label: 'Кино', emphasis: 'без расписания', count: ...)`.
    6. `EditorialBentoGrid(cells: [...])` с ≥ 8 cells разных sizes (1×1, 2×1, 1×2, 2×2 mix матчит дизайн).
    7. `EditorialFilmReelStrip(channelCount: ..., activeIndex: ..., frameCount: 18)`.
  - Wrapping scrollable: `CustomScrollView` (sliver list для bento) ИЛИ `ListView` с теми же perf-флагами (`cacheExtent: 1500`, `addAutomaticKeepAlives: true`, `addRepaintBoundaries: true`, `clipBehavior: Clip.none`) (Req 9.4).
  - Все Keys из Req 13.1 mounted (каждая sub-component уже несёт свой Key из phase 2-5).
  - Hero `MvButton.primary` `FocusNode` initially focused on mount (Req 3.6).
  - **Perf gate**: `grep -rE "BackdropFilter|ShaderMask|ImageFilter\.blur" lib/features/home/editorial/ lib/features/home/home_variant_provider.dart` → 0; `grep -rE "blurRadius:\s*([2-9][0-9]+|1[3-9])" lib/features/home/editorial/` → 0.
  - Наблюдаемое: smoke test из 1.3 продолжает зелёный + теперь обнаруживает все ключевые keys (Req 13.1) — обновить smoke test для проверки всех keys (часть этого task'а).
  - _Requirements: 1.1, 1.2, 1.3, 3.6, 9.1, 9.2, 9.3, 9.4, 13.1_
  - _Depends: 2.1, 2.3, 3.3, 4.3, 5.1, 5.3, 5.5_
  - _Boundary: EditorialHomeScreen integration_

- [ ] 6.2 Coexistence test — Cinematic vs Editorial vs legacy via `homeVariantProvider`
  - Создать `megav_iptv/test/features/home/editorial/home_variant_coexistence_test.dart`.
  - Тест 1 — `HomeVariant.editorial`:
    - Pump app с `ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(MockSharedPreferences())])`.
    - Set `ref.read(homeVariantProvider.notifier).state = HomeVariant.editorial` (или эквивалент в зависимости от реализации).
    - Navigate to `/home-editorial` (Option B) или к root (Option A).
    - `find.byKey(const Key('editorial-home-root'))` finds one; `find.byKey(const Key('cinematic-home-root'))` finds none.
  - Тест 2 — `HomeVariant.cinematic`:
    - Set `state = HomeVariant.cinematic`.
    - Navigate to `/home-cinematic`.
    - `find.byKey(const Key('cinematic-home-root'))` finds one; `find.byKey(const Key('editorial-home-root'))` finds none.
  - Тест 3 — `HomeVariant.legacy`:
    - Set `state = HomeVariant.legacy`.
    - Navigate to `/home`.
    - Legacy `HomeScreen` mounts (`find.byType(HomeScreen)` или эквивалент).
  - Тест 4 — Persistence:
    - Set `state = HomeVariant.editorial`, then re-create `HomeVariantNotifier` with same `MockSharedPreferences` — initial state == `HomeVariant.editorial` (Req 11.5).
  - Наблюдаемое: 4 теста зелёные; coexistence proven; cinematic-spec файлы НЕ модифицированы.
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 12.4_
  - _Depends: 6.1, 1.1_
  - _Boundary: coexistence test_

- [ ] 6.3 Regression test для `pickColumns`
  - Создать `megav_iptv/test/features/home/editorial/pick_columns_regression_test.dart`.
  - Тест импортирует `pickColumns` из `package:megav_iptv/features/home/widgets/_grid_tokens.dart` (READ-ONLY).
  - Asserts: `pickColumns(1280) == 3`, `pickColumns(2560) == 4`, `pickColumns(3840) == 5` (Req 12.3, 10.4 защита).
  - Наблюдаемое: тест зелёный; защищает закрытый `home-grid-optimization` от случайных изменений из этого спека.
  - **Note**: cinematic-spec может уже иметь свой regression тест с тем же именем — назвать файл `pick_columns_regression_test.dart` уникально через path (`test/features/home/editorial/pick_columns_regression_test.dart` — это уже отличный path от cinematic-spec'овского `test/features/home/cinematic/pick_columns_regression_test.dart`). Дублирование regression-теста acceptable: оба спека защищают свою boundary.
  - _Requirements: 10.4, 12.3_
  - _Depends: 1.1_
  - _Boundary: pickColumns regression_

- [ ] 6.4 Final regression — full `flutter test` + perf greps + immutability checks
  - Run `flutter test` в `megav_iptv/`. Ожидаемый итог: **все ранее-зелёные тесты (94 baseline + cinematic-spec additions) + все новые editorial tests зелёные** (Req 12.5).
  - Подсчитать общее число тестов после landing — задокументировать в commit message (e.g., «94 baseline + 20 cinematic + 22 editorial = 136/136 зелёных»).
  - Run `flutter analyze megav_iptv/lib/features/home/editorial/ megav_iptv/lib/features/home/home_variant_provider.dart` — 0 issues (Req 13.2).
  - Run `grep -rE "BackdropFilter|ShaderMask|ImageFilter\.blur" megav_iptv/lib/features/home/editorial/ megav_iptv/lib/features/home/home_variant_provider.dart` → 0 hits (Req 9.1, 13.3).
  - Run `grep -rE "blurRadius:\s*([2-9][0-9]+|1[3-9])" megav_iptv/lib/features/home/editorial/` → 0 hits (Req 9.2, 13.5).
  - Verify `pubspec.yaml` без новых пакетов (Req 13.4) — diff vs main → no `pubspec.yaml` change.
  - Verify closed-spec файлы НЕ модифицированы — `git diff master --name-only -- megav_iptv/lib/features/home/widgets/ megav_iptv/lib/features/home/home_screen.dart` → empty (Req 10.1, 10.3, 10.5).
  - Verify cinematic-spec файлы НЕ модифицированы — `git diff master --name-only -- megav_iptv/lib/features/home/cinematic/ megav_iptv/test/features/home/cinematic/` → empty (Req 10.2).
  - Manual VM Service smoke pass on rtd2851a (если доступен): avg `GPURasterizer::Draw ≤ 16.7 ms` при scroll по новому экрану (Req 9 acceptance).
  - Наблюдаемое: все checks зелёные; commit message содержит конкретные числа.
  - _Requirements: 9.1, 9.2, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 12.3, 12.5, 13.2, 13.3, 13.4, 13.5_
  - _Depends: 6.1, 6.2, 6.3, 5.6, 5.4, 5.2, 4.4, 4.2, 3.4, 3.2, 2.4, 2.2, 1.3_
  - _Boundary: final regression gate_

- [ ] 6.5 Rollout (opt-in) — НЕ flip default
  - **Editorial остаётся opt-in**: `kHomeVariantDefault` остаётся `HomeVariant.cinematic` (или `legacy` — что было до этого спека). User не сделал явного выбора Editorial vs Cinematic, поэтому default НЕ меняется этим спеком (Req 11.6).
  - Editorial reachable через:
    - explicit route `/home-editorial` (если Option B);
    - explicit `homeVariantProvider.notifier.set(HomeVariant.editorial)` через debug menu или Settings toggle (последнее — out of scope, обрабатывается `settings-redesign` #11);
    - manual override в `kHomeVariantDefault` для QA.
  - **Если позже user явно выберет Editorial as default**: отдельный one-line patch в `kHomeVariantDefault`. Не входит в scope этого спека.
  - Manual VM Service smoke pass on rtd2851a (если доступен) проводится как часть 6.4 — это документация только что Editorial reachable + не регрессит существующие экраны.
  - Commit message ясно отмечает: «Editorial home available opt-in via /home-editorial; default remains cinematic».
  - Наблюдаемое: после landing спека пользователь может явно переключиться на Editorial, но по умолчанию видит Cinematic; legacy reachable через provider override.
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.6, 11.7_
  - _Depends: 6.4_
  - _Boundary: opt-in rollout doc_

---

## Implementation order

Внутри phase'ов sub-tasks независимы (помечены _Boundary:_), можно делать (P) parallel. Между phases — sequential per `_Depends:_`.

```
1.1 → 1.2 → 1.3
                ↘
                  2.1 → 2.2 (P)
                  2.3 → 2.4 (P)
                  3.1 → 3.2 (P)
                  3.3 → 3.4 (P, depends on 3.1)
                  4.1 → 4.2 (P)
                  4.3 → 4.4 (P, depends on 4.1)
                  5.1 → 5.2 (P)
                  5.3 → 5.4 (P)
                  5.5 → 5.6 (P)
                ↙
              6.1 (depends on all phase-2/3/4/5 widget tasks)
              6.2 (depends on 6.1, 1.1)
              6.3 (depends on 1.1)
                ↓
              6.4 final regression
                ↓
              6.5 rollout doc (opt-in only)
```

## Test count expectation

| Phase | New tests added | Cumulative new (this spec) |
|---|---|---|
| Phase 1 | 1 (smoke) | 1 |
| Phase 2 | 2 + 4 | 7 |
| Phase 3 | 4 + 5 | 16 |
| Phase 4 | 4 + 3 | 23 |
| Phase 5 | 2 + 3 + 3 | 31 |
| Phase 6 | 4 (coexistence) + 1 (regression) | 36 |

Total expected new tests from this spec: **~36 tests**. Implementer должен зафиксировать актуальное число в commit message task 6.4.

## Perf gate summary (per-task enforcement)

Каждый task создающий новый файл в `lib/features/home/editorial/` или модифицирующий `lib/features/home/home_variant_provider.dart` обязан локально пройти:

```bash
grep -rE "BackdropFilter|ShaderMask|ImageFilter\.blur" \
  megav_iptv/lib/features/home/editorial/ \
  megav_iptv/lib/features/home/home_variant_provider.dart
# expected: 0 hits

grep -rE "blurRadius:\s*([2-9][0-9]+|1[3-9])" megav_iptv/lib/features/home/editorial/
# expected: 0 hits
```

Final task 6.4 повторяет это глобально + добавляет git diff проверку closed-spec и cinematic-spec immutability.

## Sibling-spec immutability check (per-task enforcement)

Каждый task этого спека должен проверить:

```bash
git diff master --name-only -- \
  megav_iptv/lib/features/home/cinematic/ \
  megav_iptv/test/features/home/cinematic/ \
  megav_iptv/lib/features/home/widgets/ \
  megav_iptv/lib/features/home/home_screen.dart \
  megav_iptv/pubspec.yaml
# expected: empty (no modifications)
```

Final task 6.4 закрепляет это как обязательный gate.
