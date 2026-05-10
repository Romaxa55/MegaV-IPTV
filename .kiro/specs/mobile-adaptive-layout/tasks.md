# Implementation Plan — mobile-adaptive-layout

> Спек: `mobile-adaptive-layout`. См. `requirements.md` (12 requirements) и `design.md` (17 lib files + 12 test files + 3-line router swap).
>
> Принципы:
> 1. **TV-path immutability**: 0 writes в `lib/features/home/cinematic/`, `lib/features/home/widgets/`, `lib/features/home/home_screen.dart`, TV detail/player widget trees. Только READ-ONLY импорты в `<Screen>RootScreen` файлах. Router получает строго 3-line swap.
> 2. **Mobile path boundary**: все `BackdropFilter` / `ImageFilter.blur` / `ShaderMask` живут ТОЛЬКО в `lib/core/layout/`, `lib/features/<screen>/mobile/`, `lib/features/mobile/`. Final task запускает global grep и проверяет что hits — только там.
> 3. **Foundation atoms reuse**: import через `package:megav_iptv/core/ui/atoms/atoms.dart` барель; никакого override theme tokens.
> 4. **Test gate**: каждый task создающий новый widget идёт со своим test file. Final task 6.3 запускает `flutter test` — ожидание prior baseline + все новые green.

---

## 1. Foundation: breakpoint detector

- [x] 1.1 `ScreenKind` enum + `screenKindOf` + `screenKindProvider`
  - Создать `megav_iptv/lib/core/layout/` directory.
  - Создать `megav_iptv/lib/core/layout/screen_kind.dart` с:
    - `enum ScreenKind { mobile, tablet, tv }`.
    - `ScreenKind screenKindOf(BuildContext context)` — `< 600` mobile, `< 1280` tablet, `>= 1280` tv (Req 1.2).
    - `final screenKindProvider = Provider.autoDispose<ScreenKind>((ref) => ScreenKind.tv);` (Req 1.3 — overridable in tests).
  - Наблюдаемое: `flutter analyze megav_iptv/lib/core/layout/` чисто; `flutter test` без новых файлов прежний baseline.
  - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.6_
  - _Boundary: ScreenKind public API_

- [x] 1.2 `AdaptiveScaffold` widget
  - Создать `megav_iptv/lib/core/layout/adaptive_scaffold.dart` с:
    - `class AdaptiveScaffold extends StatelessWidget { const AdaptiveScaffold({super.key, required this.mobile, required this.tv, this.tablet}); final WidgetBuilder mobile; final WidgetBuilder tv; final WidgetBuilder? tablet; ... }`.
    - В `build`: switch on `screenKindOf(context)` → mobile / tablet (fallback tv) / tv (Req 1.4).
  - Наблюдаемое: `flutter analyze` чисто; `AdaptiveScaffold` импортируется без ошибок.
  - _Requirements: 1.4_
  - _Depends: 1.1_
  - _Boundary: AdaptiveScaffold widget_

- [x] 1.3 Breakpoint switch tests
  - Создать `megav_iptv/test/core/layout/screen_kind_test.dart` — unit tests для `screenKindOf`:
    - При `MediaQuery(size: Size(390, 844))` → `mobile`.
    - При `MediaQuery(size: Size(800, 1024))` → `tablet`.
    - При `MediaQuery(size: Size(1920, 1080))` → `tv`.
    - При boundary 600 → `tablet`; при boundary 1280 → `tv` (Req 1.2 strict-inequality semantics).
  - Создать `megav_iptv/test/core/layout/adaptive_scaffold_test.dart`:
    - Тест 1: width 390 → mobile child rendered, tv child NOT rendered (assert via `find.byKey(Key('mobile-stub'))` + absence of `Key('tv-stub')`).
    - Тест 2: width 1920 → tv child rendered, mobile NOT (Req 10.2, 10.4).
    - Тест 3: width 1000 → tv child rendered (tablet falls through).
    - Тест 4: width 1000 + explicit `tablet` builder → tablet child rendered.
  - Наблюдаемое: 4 + 4 теста зелёные; полный `flutter test` baseline + 8 новых.
  - _Requirements: 1.2, 1.4, 10.2, 10.4_
  - _Depends: 1.2_
  - _Boundary: layout tests_

---

## 2. Adaptive screen roots — minimal-touch mounting layer

- [x] 2.1 `HomeRootScreen`
  - Создать `megav_iptv/lib/features/home/home_root.dart` с:
    - `class HomeRootScreen extends StatelessWidget { const HomeRootScreen({super.key}); @override Widget build(BuildContext context) => AdaptiveScaffold(mobile: (_) => const HomeMobileScreen(), tv: (_) => const CinematicHomeScreen()); }`.
    - `HomeMobileScreen` ещё не существует — в этом task'е использовать stub `Scaffold(body: Center(child: Text('mobile home')))` или `const Placeholder()` с `Key('home-mobile-root')`. Реальный widget будет в task 3.1.
    - Реальный `CinematicHomeScreen` импортируется из `package:megav_iptv/features/home/cinematic/cinematic_home_screen.dart` БЕЗ модификации.
  - Наблюдаемое: `flutter analyze` чисто; импорт TV widget работает.
  - _Requirements: 6.1, 6.2, 9.1_
  - _Depends: 1.2_
  - _Boundary: HomeRootScreen mount_

- [x] 2.2 `DetailRootScreen`
  - Создать `megav_iptv/lib/features/detail/detail_root.dart` аналогично — `AdaptiveScaffold(mobile: stub, tv: <existing TV detail widget>)`.
  - TV detail widget импортируется READ-ONLY (точное имя класса implementer определяет из `lib/features/detail/` после ландинга #7 — например, `DetailFullbleedScreen`).
  - Stub `DetailMobileScreen` с `Key('detail-mobile-root')` будет заменён в task 4.1.
  - Наблюдаемое: `flutter analyze` чисто.
  - _Requirements: 6.1, 6.3, 9.2_
  - _Depends: 1.2_
  - _Boundary: DetailRootScreen mount_

- [x] 2.3 `PlayerRootScreen`
  - Создать `megav_iptv/lib/features/player/player_root.dart` аналогично.
  - TV player widget импортируется READ-ONLY (имя из landing'а #8 — например, `PlayerCinematicScreen`).
  - Stub `PlayerMobileScreen` с `Key('player-mobile-root')` будет заменён в task 5.1.
  - Наблюдаемое: `flutter analyze` чисто.
  - _Requirements: 6.1, 6.4, 9.3_
  - _Depends: 1.2_
  - _Boundary: PlayerRootScreen mount_

- [x] 2.4 Router 3-line swap
  - Найти существующий route registration файл (наиболее вероятно `megav_iptv/lib/app_router.dart`, либо `main.dart`, либо `lib/app/router.dart` — implementer определяет).
  - Заменить три route entries:
    - `/home` (или эквивалент) → `HomeRootScreen` instead of `CinematicHomeScreen`.
    - `/detail` (или эквивалент) → `DetailRootScreen` instead of TV detail.
    - `/player` (или эквивалент) → `PlayerRootScreen` instead of TV player.
  - Каждое изменение — ровно одна строка. Total diff outside mobile/layout dirs: 3 lines (Req 6.5).
  - Implementer документирует выбранный файл в commit message.
  - Наблюдаемое: TV smoke тесты (#5/#7/#8) продолжают зелёные — TV widgets всё ещё mounted при широком viewport.
  - _Requirements: 6.1, 6.5, 9.1, 9.2, 9.3, 9.7_
  - _Depends: 2.1, 2.2, 2.3_
  - _Boundary: router swap_

---

## 3. Home mobile

- [ ] 3.1 `HomeMobileScreen`
  - Создать `megav_iptv/lib/features/home/mobile/` directory.
  - Создать `megav_iptv/lib/features/home/mobile/home_mobile_screen.dart` с `class HomeMobileScreen extends ConsumerWidget` (Req 2.1).
  - Build tree: `Scaffold(body: Stack(children: [ListView(children: [SizedBox(height: viewPadding.top), MTopBar(), MHeroCard(...), ...рейлы..., SizedBox(height: 96 /* tabbar reservation */)]), Positioned(left:0, right:0, bottom:0, child: MTabBar())]))` (Req 2.2-2.5).
  - Status-bar reservation — `MediaQuery.viewPaddingOf(context).top` (Req 2.3).
  - Корневой widget получает `Key('home-mobile-root')` (Req 2.9, 12.1).
  - Stub `MTopBar`, `MHeroCard`, `MStackedRail`, `MTabBar` если ещё не созданы — phased: task 3.2-3.4 создают их. Здесь используются как `const Placeholder()` если нужно.
  - Заменить stub в `HomeRootScreen` (task 2.1) на реальный `HomeMobileScreen`.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится без exception в test.
  - _Requirements: 2.1, 2.6, 2.7, 2.8, 2.9, 12.1_
  - _Depends: 2.1_
  - _Boundary: HomeMobileScreen_

- [ ] 3.2 `MTopBar`
  - Создать `megav_iptv/lib/features/home/mobile/widgets/m_top_bar.dart` с `class MTopBar extends ConsumerWidget` (Req 7.1).
  - Build: `Row(children: [Column(crossAxisAlignment: start, children: [Text(city), Text('${temp}°'), Text(time)]), Spacer(), Brand()])`.
  - Reuse existing weather provider если такой есть, иначе stub strings (data wiring можно отложить — visual-first OK).
  - Корневой widget получает `Key('m-top-bar')` (Req 12.1).
  - Создать `megav_iptv/test/features/home/mobile/m_top_bar_test.dart` — pump + key + brand finding.
  - Наблюдаемое: 1+ test зелёный; `flutter analyze` чисто.
  - _Requirements: 2.2, 7.1, 12.1_
  - _Depends: 1.2_
  - _Boundary: MTopBar_

- [ ] 3.3 `MHeroCard`
  - Создать `megav_iptv/lib/features/home/mobile/widgets/m_hero_card.dart` с `class MHeroCard extends ConsumerWidget` (Req 7.3).
  - Build: `Column(children: [SizedBox(height: 380, child: ClipRRect(borderRadius: BorderRadius.circular(AppRadius.lg), child: Stack(children: [Image (poster), bottom-gradient, Padding(child: Column(title via theme.megavText.headline, MvButton.primary('Смотреть')))]))), SizedBox(height: 8), Row of paginator dots])`.
  - Mobile may use raw `BackdropFilter` if visually warranted (Req 11) — но default OK без blur здесь.
  - Корневой widget получает `Key('m-hero-card')` (Req 12.1).
  - Создать `megav_iptv/test/features/home/mobile/m_hero_card_test.dart`.
  - _Requirements: 2.4, 7.3, 12.1_
  - _Depends: 1.2_
  - _Boundary: MHeroCard_

- [ ] 3.4 `MStackedRail`
  - Создать `megav_iptv/lib/features/home/mobile/widgets/m_stacked_rail.dart` с `class MStackedRail extends StatelessWidget` (Req 7.4).
  - Build: `Column(crossAxisAlignment: start, children: [SectionTitle(label:..., emphasis:..., count:...), GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: NeverScrollableScrollPhysics(), children: items.map(Poster(orientation: portrait, hideText: false)).toList())])`.
  - Single-column / 2-column layout — НЕ horizontal `ListView` (Req 2.5, 2.6).
  - Корневой widget получает `Key('m-stacked-rail')` (Req 12.1).
  - Создать `megav_iptv/test/features/home/mobile/m_stacked_rail_test.dart`.
  - _Requirements: 2.5, 2.6, 7.4_
  - _Depends: 1.2_
  - _Boundary: MStackedRail_

- [ ] 3.5 `HomeMobileScreen` smoke test
  - Создать `megav_iptv/test/features/home/mobile/home_mobile_screen_smoke_test.dart`.
  - Pump под `MediaQuery(size: Size(390, 844))` + `ProviderScope` с моками; ожидает `find.byKey(Key('home-mobile-root'))` finds one + no exception across two frames.
  - Тест 2: `find.byType(HomeMobileScreen)` finds one; `find.byKey(Key('m-tab-bar'))` finds one (после task 6.1) — пока MTabBar stub, проверять только root key.
  - _Requirements: 10.3, 12.1_
  - _Depends: 3.1, 3.2, 3.3, 3.4_
  - _Boundary: home mobile smoke_

---

## 4. Detail mobile

- [ ] 4.1 `DetailMobileScreen`
  - Создать `megav_iptv/lib/features/detail/mobile/` directory.
  - Создать `megav_iptv/lib/features/detail/mobile/detail_mobile_screen.dart` с `class DetailMobileScreen extends ConsumerWidget` (params: `itemId: String`).
  - Build: `Scaffold(body: ListView(children: [Stack(poster + back-arrow MIconBtn top-left), Padding(Column([Text(title via headline, ≤22px), Row(meta), Row(actions: Play/Add/Share via MIconBtn), SizedBox, Text(description, body 16px)]))]))` (Req 3.2, 3.3, 3.4).
  - Title — `Theme.of(context).megavText.headline` (Req 3.3, 8.3).
  - Meta — `Theme.of(context).megavText.metaMono`.
  - Корневой widget получает `Key('detail-mobile-root')` (Req 3.7, 12.1).
  - Заменить stub в `DetailRootScreen` (task 2.2) на реальный `DetailMobileScreen`.
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 8.3, 12.1_
  - _Depends: 2.2, 6.2 (MIconBtn)_
  - _Boundary: DetailMobileScreen_

- [ ] 4.2 `DetailMobileScreen` smoke test
  - Создать `megav_iptv/test/features/detail/mobile/detail_mobile_screen_smoke_test.dart`.
  - Pump под `MediaQuery(size: Size(390, 844))` + mocked item provider.
  - Тест 1: `find.byKey(Key('detail-mobile-root'))` finds one; no exception.
  - Тест 2: title text uses `headline` style — `tester.widget<Text>(find.text(mockTitle)).style.fontSize <= 22`.
  - _Requirements: 10.3, 12.1, 3.3_
  - _Depends: 4.1_
  - _Boundary: detail mobile smoke_

---

## 5. Player mobile

- [ ] 5.1 `PlayerMobileScreen` + swipe gesture
  - Создать `megav_iptv/lib/features/player/mobile/` directory.
  - Создать `megav_iptv/lib/features/player/mobile/player_mobile_screen.dart` с `class PlayerMobileScreen extends ConsumerStatefulWidget` (params: `channelId: String`) (Req 4.1).
  - Build: `Scaffold(body: Stack(children: [<video surface> (consumes playerUiStateProvider read-only), GestureDetector(onHorizontalDragEnd: ... → next/prev channel, behavior: HitTestBehavior.opaque), Positioned(top: 16, left: 16, child: MLiveDot()), Positioned(bottom: 0, left: 0, right: 0, child: MPlayerControls()), MSwipeHint() (overlay until first swipe)]))` (Req 4.2-4.5).
  - Swipe threshold: `velocity.pixelsPerSecond.dx.abs() > 500 || dragDistance.abs() > 50` (Req 4.3).
  - Read sealed `PlayerUiState` через provider — НЕ модифицировать (Req 4.6, 4.7).
  - Корневой widget получает `Key('player-mobile-root')` (Req 4.8, 12.1).
  - Заменить stub в `PlayerRootScreen` (task 2.3) на реальный `PlayerMobileScreen`.
  - _Requirements: 4.1, 4.2, 4.3, 4.6, 4.7, 4.8, 12.1_
  - _Depends: 2.3, 5.2, 5.3, 6.4 (MLiveDot)_
  - _Boundary: PlayerMobileScreen_

- [ ] 5.2 `MPlayerControls`
  - Создать `megav_iptv/lib/features/player/mobile/widgets/m_player_controls.dart` с `class MPlayerControls extends ConsumerWidget` (Req 7.5).
  - Build: `ClipRRect(borderRadius: BorderRadius.circular(AppRadius.lg), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28), child: Container(color: theme.surface1.withValues(alpha: 0.6), padding: ..., child: Row(children: [MIconBtn(prev), MIconBtn(play/pause), MIconBtn(next), Expanded(Slider(volume))]))))` — RAW BackdropFilter PERMITTED (Req 11).
  - Корневой widget получает `Key('m-player-controls')`.
  - Создать `megav_iptv/test/features/player/mobile/m_player_controls_test.dart` — pump + key + `find.byType(BackdropFilter)` finds one (verify blur is actually used).
  - _Requirements: 4.2, 7.5, 11.1, 12.1_
  - _Depends: 6.2 (MIconBtn)_
  - _Boundary: MPlayerControls_

- [ ] 5.3 `MSwipeHint`
  - Создать `megav_iptv/lib/features/player/mobile/widgets/m_swipe_hint.dart` с `class MSwipeHint extends StatefulWidget` (Req 7.6).
  - Внутри: `AnimationController(duration: Duration(milliseconds: 1500), vsync: ...)` репитный (`repeat(reverse: true)`) → `AnimatedOpacity` или `FadeTransition` over the hint Text «SWIPE ↔ КАНАЛ».
  - **Wrapped в `RepaintBoundary`** (Req 11.3).
  - `dismiss()` метод вызывается родителем после первого swipe (Req 4.4).
  - Корневой widget получает `Key('m-swipe-hint')` (Req 12.1).
  - Создать `megav_iptv/test/features/player/mobile/m_swipe_hint_test.dart`.
  - _Requirements: 4.4, 7.6, 11.3, 12.1_
  - _Boundary: MSwipeHint_

- [ ] 5.4 `PlayerMobileScreen` smoke test
  - Создать `megav_iptv/test/features/player/mobile/player_mobile_screen_smoke_test.dart`.
  - Pump под `MediaQuery(size: Size(390, 844))` + mocked `playerUiStateProvider`.
  - Тест 1: `find.byKey(Key('player-mobile-root'))` finds one; `find.byKey(Key('m-player-controls'))` finds one; `find.byKey(Key('m-live-dot'))` finds one.
  - Тест 2: `find.byType(GestureDetector)` finds at least one (swipe handler).
  - Тест 3: `find.byType(BackdropFilter)` finds at least one (Req 11 — blur reachable in mobile player).
  - _Requirements: 10.3, 4.5, 11.1, 12.1_
  - _Depends: 5.1, 5.2, 5.3_
  - _Boundary: player mobile smoke_

---

## 6. Shared mobile widgets — TabBar, IconBtn, LiveDot

- [ ] 6.1 `MTabBar` + `activeMobileTabProvider`
  - Создать `megav_iptv/lib/features/mobile/state/active_mobile_tab_provider.dart` с `final activeMobileTabProvider = StateProvider<int>((ref) => 0);` (Req 5.3).
  - Создать `megav_iptv/lib/features/mobile/widgets/m_tab_bar.dart` с `class MTabBar extends ConsumerWidget` (Req 5.1).
  - Build: `ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28), child: Container(color: theme.surface1.withValues(alpha: 0.6), padding: EdgeInsets.only(bottom: viewPadding.bottom + 8, top: 8, left: 16, right: 16), child: Row(mainAxisAlignment: spaceAround, children: 5 × _MTab(icon: ..., label: ..., active: idx == activeIndex, onTap: () => ref.read(activeMobileTabProvider.notifier).state = idx)))))` — RAW BackdropFilter PERMITTED (Req 5.4, 11.1).
  - Safe-area inset через `MediaQuery.viewPaddingOf(context).bottom` (Req 5.5).
  - 5 tabs labels (Req 5.2): Home / TV / Search / Guide / Profile.
  - Active tab чтение через `ref.watch(activeMobileTabProvider)` (Req 5.3).
  - Корневой widget получает `Key('m-tab-bar')` (Req 12.1).
  - Создать `megav_iptv/test/features/mobile/m_tab_bar_test.dart`:
    - Тест 1: pump + `find.byKey(Key('m-tab-bar'))`; `find.byType(BackdropFilter)` finds one (Req 5.4 enforcement).
    - Тест 2: 5 tabs rendered — `find.byType(_MTab)` finds 5 ИЛИ ищем 5 labels по тексту.
    - Тест 3: tap на tab 2 → `activeMobileTabProvider` state == 2.
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 11.1, 12.1_
  - _Boundary: MTabBar + tab provider_

- [ ] 6.2 `MIconBtn`
  - Создать `megav_iptv/lib/features/mobile/widgets/m_icon_btn.dart` с `class MIconBtn extends StatelessWidget` (params: `icon: IconData`, `onTap: VoidCallback?`, `label: String?`) (Req 7.2).
  - Build: `Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppRadius.md), child: Container(constraints: BoxConstraints(minWidth: 44, minHeight: 44), padding: EdgeInsets.all(8), child: Column(mainAxisSize: min, children: [Icon(icon, size: 24), if (label != null) Text(label, style: theme.megavText.metaMono.copyWith(fontSize: 11))]))))`.
  - Min touch area 44×44 px (Req 7.2).
  - Создать `megav_iptv/test/features/mobile/m_icon_btn_test.dart` — pump + tap callback + min size assertion.
  - _Requirements: 7.2_
  - _Boundary: MIconBtn_

- [ ] 6.3 `MLiveDot`
  - Создать `megav_iptv/lib/features/mobile/widgets/m_live_dot.dart` с `class MLiveDot extends StatefulWidget` (Req 7.7).
  - Внутри: `AnimationController(duration: Duration(milliseconds: 1500), vsync: ...)` `.repeat(reverse: true)` → `AnimatedBuilder` modulating dot opacity / scale.
  - **Wrapped в `RepaintBoundary`** (Req 4.5, 11.3).
  - Build: `RepaintBoundary(child: AnimatedBuilder(animation: _ctrl, builder: (_, __) => Container(width: 8, height: 8, decoration: BoxDecoration(shape: circle, color: AppColors.live.withValues(alpha: _ctrl.value)))))`.
  - Корневой widget получает `Key('m-live-dot')` (Req 12.1).
  - Создать `megav_iptv/test/features/mobile/m_live_dot_test.dart` — pump + key + `find.ancestor(of: find.byType(AnimatedBuilder), matching: find.byType(RepaintBoundary))` finds one.
  - _Requirements: 4.5, 7.7, 11.3, 12.1_
  - _Boundary: MLiveDot_

---

## 7. Final regression + boundary gate

- [ ] 7.1 Boundary grep — RAW blur localized
  - Run `grep -rE "BackdropFilter|ImageFilter\.blur|ShaderMask" megav_iptv/lib/`.
  - Expected hits ONLY in:
    - `megav_iptv/lib/core/layout/` (none expected — but allowed).
    - `megav_iptv/lib/features/home/mobile/`.
    - `megav_iptv/lib/features/detail/mobile/`.
    - `megav_iptv/lib/features/player/mobile/`.
    - `megav_iptv/lib/features/mobile/`.
  - **Any hit outside these 5 directories fails the gate** (Req 11.4, 12.3).
  - Document command output in commit message — include actual file:line list of mobile-path hits as proof.
  - _Requirements: 11.4, 11.5, 12.3_
  - _Depends: 5.4, 6.1_
  - _Boundary: mobile blur boundary check_

- [ ] 7.2 TV-path immutability check
  - Run `git diff master --name-only -- megav_iptv/lib/features/home/cinematic/ megav_iptv/lib/features/home/widgets/ megav_iptv/lib/features/home/home_screen.dart` → expected empty (Req 9.1, 9.4).
  - Run `git diff master --name-only -- megav_iptv/lib/features/detail/` → expected to show ONLY `lib/features/detail/detail_root.dart` and `lib/features/detail/mobile/` files. TV detail widget files unchanged (Req 9.2).
  - Run `git diff master --name-only -- megav_iptv/lib/features/player/` → expected ONLY `lib/features/player/player_root.dart` and `lib/features/player/mobile/` files. TV player widget files unchanged. `lib/core/player/` untouched (Req 9.3, 9.6).
  - Run `git diff master --shortstat -- megav_iptv/lib/app_router.dart` (or equivalent) → expected ≤ 3 insertions / 3 deletions (3-line swap; Req 6.5).
  - Document outputs in commit message.
  - _Requirements: 6.5, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7_
  - _Depends: 2.4_
  - _Boundary: TV immutability gate_

- [ ] 7.3 Final regression — full `flutter test` + analyze
  - Run `flutter test` в `megav_iptv/`. Ожидаемый итог: prior baseline (94 + tests added by Wave 3 #5/#7/#8) + ВСЕ новые mobile tests зелёные (Req 10.5).
  - Подсчитать total и записать в commit message (e.g., «`baseline N + new 25 = N+25 / N+25` зелёных»).
  - Run `flutter analyze megav_iptv/lib/core/layout/ megav_iptv/lib/features/home/mobile/ megav_iptv/lib/features/detail/mobile/ megav_iptv/lib/features/player/mobile/ megav_iptv/lib/features/mobile/` → 0 issues (Req 12.2).
  - Run `flutter analyze megav_iptv/lib/features/home/home_root.dart megav_iptv/lib/features/detail/detail_root.dart megav_iptv/lib/features/player/player_root.dart` → 0 issues.
  - Verify `pubspec.yaml` без новых пакетов (Req 12.4) — `git diff master -- megav_iptv/pubspec.yaml` → empty.
  - Manual smoke на Android phone (Pixel 6 / эмулятор) — открыть home / detail / player, проверить что mobile варианты рендерятся, glass tabbar виден, swipe-hint отображается на player.
  - Manual smoke на rtd2851a TV (если доступен) — TV path выглядит идентично pre-spec (zero regression).
  - Наблюдаемое: все checks зелёные; commit message содержит конкретные числа + boundary grep output из task 7.1 + git diff outputs из task 7.2.
  - _Requirements: 9.7, 10.5, 11.5, 12.2, 12.3, 12.4_
  - _Depends: 7.1, 7.2, 5.4, 4.2, 3.5, 1.3_
  - _Boundary: final regression gate_

---

## Implementation order

Внутри phase'ов sub-tasks независимы (помечены _Boundary:_), можно делать (P) parallel. Между phases — sequential per `_Depends:_`.

```
1.1 → 1.2 → 1.3
              ↘
                2.1, 2.2, 2.3 (P) → 2.4 (router swap)
                                    ↘
                                      3.2, 3.3, 3.4 (P), 6.2 (P), 6.3 (P)
                                                                  ↘
                                                                    3.1 → 3.5
                                                                    4.1 → 4.2
                                                                    5.2 → 5.3 → 5.1 → 5.4
                                                                    6.1
                                                                            ↘
                                                                              7.1, 7.2 (P)
                                                                              → 7.3 final regression
```

## Test count expectation

| Phase | New tests added (approx) | Cumulative new |
|---|---|---|
| Phase 1 | 8 (4 screen_kind + 4 adaptive_scaffold) | 8 |
| Phase 2 | 0 (root files have no own tests — covered via screen smoke) | 8 |
| Phase 3 | 4 (top bar, hero card, stacked rail, smoke) | 12 |
| Phase 4 | 1 (smoke) | 13 |
| Phase 5 | 4 (player smoke, controls, swipe hint) | 17 |
| Phase 6 | 6 (tab bar × 3 cases, icon btn, live dot, etc.) | 23 |
| Phase 7 | 0 (gate-only) | 23 |

Estimated total new tests: **~23**. Implementer должен зафиксировать актуальное число в commit message task 7.3.

## Mobile-blur boundary summary (per-task enforcement)

Каждый task создающий новый файл вне `lib/features/<screen>/mobile/`, `lib/features/mobile/`, или `lib/core/layout/` обязан локально пройти:

```bash
# на task'е task 2.x (root files):
grep -rE "BackdropFilter|ImageFilter\.blur|ShaderMask" megav_iptv/lib/features/home/home_root.dart \
  megav_iptv/lib/features/detail/detail_root.dart \
  megav_iptv/lib/features/player/player_root.dart
# expected: 0 hits — root files only do AdaptiveScaffold mounting, no blur

# глобально на task 7.1:
grep -rE "BackdropFilter|ImageFilter\.blur|ShaderMask" megav_iptv/lib/
# expected: hits ONLY in mobile / layout dirs (см. task 7.1)
```

Final task 7.1 формализует это с full output capture в commit message.
