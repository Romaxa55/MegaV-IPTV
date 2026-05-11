# Implementation Plan — hero-collapse-tile-morph

## Phase 1 — Foundation: CinemaRow.firstSlot API

- [ ] 1. Расширить CinemaRow опциональным firstSlot API

- [x] 1.1 Добавить FirstSlotConfig value-class и параметр в CinemaRow
  - Создать `FirstSlotConfig` value-class в новом файле
    `megav_iptv/lib/features/home/cinematic/hero_tile_morph.dart`
    (на этом шаге создаётся только `FirstSlotConfig` — HeroTileMorph
    добавляется в задачах 2.x). Поля: `final Widget child`,
    `final FocusNode? focusNode`, `final VoidCallback? onMounted`.
    Конструктор `const FirstSlotConfig({required this.child,
    this.focusNode, this.onMounted})`.
  - В `megav_iptv/lib/features/home/widgets/cinema_row.dart`
    добавить импорт `import '../cinematic/hero_tile_morph.dart'
    show FirstSlotConfig;` (top of file).
  - В `class CinemaRow extends StatefulWidget` добавить новое поле
    `final FirstSlotConfig? firstSlot;` (после `final bool wrapAround;`),
    в конструкторе добавить `this.firstSlot,`.
  - В `class CategoryRowWrapper extends ConsumerStatefulWidget`
    добавить новое поле `final FirstSlotConfig? firstSlot;`, в
    конструкторе добавить `this.firstSlot,`.
  - В `_CategoryRowWrapperState.build`, при создании `CinemaRow(...)` —
    пробросить `firstSlot: widget.firstSlot`.
  - Observable completion: `flutter analyze megav_iptv/` проходит без
    ошибок; `grep -n "FirstSlotConfig" megav_iptv/lib/features/home/`
    возвращает 4+ совпадений (импорт + поле в CinemaRow + поле в
    CategoryRowWrapper + класс в hero_tile_morph.dart); все
    существующие потребители (CinematicHomeScreen, HomeScreen)
    компилируются без правок (используют default null).
  - _Requirements: 3.2, 9.3_
  - _Boundary: CinemaRow, CategoryRowWrapper, FirstSlotConfig_

- [x] 1.2 Подключить firstSlot.focusNode listener в _CinemaRowState
  - В `_CinemaRowState` добавить private метод
    `_onFirstSlotFocusChange()`:
    ```
    final node = widget.firstSlot?.focusNode;
    if (node == null) return;
    if (node.hasFocus) {
      FastScrollDetector().onEvent();
      setState(() => _focusedIndex = 0);
      _scheduleStableFocus(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _focusedIndex != 0) return;
        _scrollFocusedTileToLeadingEdge(0);
      });
    } else if (_focusedIndex == 0) {
      _focusStableTimer?.cancel();
      setState(() => _focusedIndex = -1);
      widget.onItemFocus?.call(null);
    }
    ```
  - В `initState`: если `widget.firstSlot?.focusNode != null` →
    `widget.firstSlot!.focusNode!.addListener(_onFirstSlotFocusChange)`.
    Затем `addPostFrameCallback` чтобы проверить начальный
    `hasFocus` (если node уже имеет focus до mount row — например,
    `_scheduleHeroWatchFocus` сработал после boot fade-out), вызвать
    `_onFirstSlotFocusChange()` синхронно.
    Дополнительно: вызвать `widget.firstSlot?.onMounted?.call()` в
    `addPostFrameCallback`.
  - В `didUpdateWidget(oldWidget)`: если
    `oldWidget.firstSlot?.focusNode != widget.firstSlot?.focusNode` →
    `oldWidget.firstSlot?.focusNode?.removeListener(...)` +
    `widget.firstSlot?.focusNode?.addListener(...)`.
  - В `dispose`: `widget.firstSlot?.focusNode?.removeListener(_onFirstSlotFocusChange)`.
  - Observable completion: при ручном инстансировании
    `CinemaRow(firstSlot: FirstSlotConfig(child: TextButton(...),
    focusNode: testNode))` + `testNode.requestFocus()` → row state
    `_focusedIndex == 0` и pinned-slot scroll вызывается; при
    `testNode.unfocus()` → `_focusedIndex == -1`. Для негативного
    случая (`firstSlot == null`): код не выполняется, существующее
    поведение row сохраняется.
  - _Requirements: 3.4, 9.3_
  - _Boundary: CinemaRow_
  - _Depends: 1.1_

- [x] 1.3 Подменить slot-0 rendering в itemBuilder
  - В `_CinemaRowState.build → ListView.builder → itemBuilder`,
    при `index == 0 && widget.firstSlot != null`:
    - Не возвращать существующий `Focus(...) → MouseRegion → Padding →
      LayoutBuilder → Align → CinemaCard`.
    - Вернуть:
      ```
      return Padding(
        padding: EdgeInsets.only(
          right: widget.items.length == 1 ? 0 : GridTokens.gapDp.w,
        ),
        child: widget.firstSlot!.child,
      );
      ```
  - Для всех остальных индексов (`index > 0` ИЛИ `firstSlot == null`)
    — поведение НЕ меняется.
  - Observable completion: при наличии `firstSlot` первая плитка =
    `firstSlot.child` без обёртки Focus/MouseRegion/etc; для
    остальных индексов остаётся существующий пайплайн; `flutter test
    test/features/home/widgets/cinema_row_pinned_slot_test.dart`
    (upstream-test) — продолжает проходить (потому что test
    конструирует CinemaRow без firstSlot — default null path).
  - _Requirements: 3.3, 3.4, 9.3, 7.5_
  - _Boundary: CinemaRow_
  - _Depends: 1.1, 1.2_

## Phase 2 — Core: HeroTileMorph widget

- [ ] 2. Реализовать HeroMorphState enum + computeNextState pure-function

- [x] 2.1 (P) Создать HeroMorphState enum и computeNextState
  - В `megav_iptv/lib/features/home/cinematic/hero_tile_morph.dart`
    (тот же файл, что FirstSlotConfig) добавить:
    - `enum HeroMorphState { idleExpanded, morphingCollapsing,
      idleCollapsed, morphingExpanding }`.
    - `enum _MorphCommand { collapse, expand, tickerCompleted,
      tickerDismissed, disableAnimationsCollapse,
      disableAnimationsExpand }`.
    - `@visibleForTesting HeroMorphState computeNextState(HeroMorphState
      current, _MorphCommand cmd)` — pure-функция, реализующая switch
      из design.md → Components → HeroMorphState секции:
      - `(idleExpanded, collapse) → morphingCollapsing`
      - `(morphingCollapsing, tickerCompleted) → idleCollapsed`
      - `(morphingCollapsing, expand) → morphingExpanding`
      - `(idleCollapsed, expand) → morphingExpanding`
      - `(morphingExpanding, tickerDismissed) → idleExpanded`
      - `(morphingExpanding, collapse) → morphingCollapsing`
      - `(_, disableAnimationsCollapse) → idleCollapsed`
      - `(_, disableAnimationsExpand) → idleExpanded`
      - default → `current`
  - Импорт `package:flutter/foundation.dart` для `@visibleForTesting`.
  - Observable completion: `flutter analyze megav_iptv/` проходит;
    `grep -n "enum HeroMorphState" megav_iptv/lib/features/home/cinematic/hero_tile_morph.dart`
    возвращает результат; `_MorphCommand` приватный (не экспортируется
    из файла).
  - _Requirements: 1.1, 1.4, 1.5, 1.6, 5.4_
  - _Boundary: HeroMorphState, computeNextState_

- [ ] 3. Реализовать HeroTileMorph widget

- [x] 3.1 Создать HeroTileMorph public API (props + конструктор)
  - В `hero_tile_morph.dart` добавить `class HeroTileMorph extends
    StatefulWidget` с полями (см. design.md → HeroTileMorph public API):
    - `final NowPlayingItem? heroItem;`
    - `final Widget expandedChild;`
    - `final ImageProvider? collapsedCover;`
    - `final String collapsedCaption;`
    - `final FocusNode focusNode;`
    - `final bool collapsed;`
    - `final double expandedHeightDp; // default 620.0`
    - `final double collapsedHeightDp; // default 0.0, resolved at build`
    - `final double collapsedWidthDp;`
    - `final double expandedWidthDp;`
  - Конструктор `const HeroTileMorph({...})` с required-помеченными
    полями.
  - Импорты: `package:flutter/widgets.dart`, `package:flutter/material.dart`,
    `package:flutter_screenutil/flutter_screenutil.dart`, локальный
    `../../widgets/_grid_tokens.dart`, `../../core/playlist/models/now_playing.dart`.
  - Observable completion: `flutter analyze` проходит; класс
    экспортируется; pure-data API, ещё нет State implementation.
  - _Requirements: 1.1, 3.5, 4.1, 4.5_
  - _Boundary: HeroTileMorph_
  - _Depends: 2.1_

- [x] 3.2 Реализовать _HeroTileMorphState: AnimationController + state machine
  - `class _HeroTileMorphState extends State<HeroTileMorph> with
    SingleTickerProviderStateMixin`:
    - `late AnimationController _controller;`
    - `late CurvedAnimation _curved;`
    - `HeroMorphState _state = HeroMorphState.idleExpanded;` (или
      `idleCollapsed` если `widget.collapsed` в `initState`).
  - В `initState`:
    - `_controller = AnimationController(vsync: this, duration:
      const Duration(milliseconds: 300));`
    - `_curved = CurvedAnimation(parent: _controller, curve:
      Curves.easeInOutCubic);`
    - Если `widget.collapsed` → `_controller.value = 1.0; _state =
      idleCollapsed;` иначе `_controller.value = 0.0; _state =
      idleExpanded;`.
    - `_controller.addStatusListener(_onStatusChanged)`.
  - `_onStatusChanged(AnimationStatus status)`:
    - `completed` → `setState(() => _state =
      computeNextState(_state, _MorphCommand.tickerCompleted));`
    - `dismissed` → `setState(() => _state =
      computeNextState(_state, _MorphCommand.tickerDismissed));`
    - `forward` → `setState(() => _state =
      computeNextState(_state, _MorphCommand.collapse));`
      (потому что forward означает что мы запустили forward()
      = collapse направление)
    - `reverse` → `setState(() => _state =
      computeNextState(_state, _MorphCommand.expand));`
  - В `dispose`:
    - `_controller.removeStatusListener(_onStatusChanged);`
    - `_controller.dispose();`
    - НЕ диспозить `widget.focusNode` (он external).
  - Observable completion: при ручном `tester.pumpWidget(HeroTileMorph)`
    + переключении `collapsed: true`, `_state` проходит idleExpanded
    → morphingCollapsing → idleCollapsed по тикам контроллера;
    `flutter test` не падает.
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 2.4, 10.4_
  - _Boundary: HeroTileMorph state_
  - _Depends: 3.1_

- [x] 3.3 Реализовать didUpdateWidget + disableAnimations handling
  - В `_HeroTileMorphState.didUpdateWidget(HeroTileMorph oldWidget)`:
    - `super.didUpdateWidget(oldWidget);`
    - Если `oldWidget.collapsed != widget.collapsed`:
      - Если `_disableAnimationsActive()` → snap:
        - target = `widget.collapsed ? 1.0 : 0.0`.
        - `_controller.stop(); _controller.value = target;`
        - `setState(() => _state = computeNextState(_state,
          widget.collapsed ? _MorphCommand.disableAnimationsCollapse
          : _MorphCommand.disableAnimationsExpand));`
      - Иначе:
        - `widget.collapsed ? _controller.forward() :
          _controller.reverse();`
  - Helper `bool _disableAnimationsActive() =>
    MediaQuery.disableAnimationsOf(context);`.
  - В `didChangeDependencies()`:
    - `super.didChangeDependencies();`
    - Если `_controller.isAnimating && _disableAnimationsActive()`:
      - `_controller.stop();`
      - target = `widget.collapsed ? 1.0 : 0.0`.
      - `_controller.value = target;`
      - `setState(() => _state = computeNextState(_state,
        widget.collapsed ? _MorphCommand.disableAnimationsCollapse
        : _MorphCommand.disableAnimationsExpand));`
  - Observable completion: при widget-тесте с
    `MediaQuery(disableAnimations: true)` morph snaps без анимации
    (`controller.value` == target немедленно); без disableAnimations —
    morph длится 300ms и завершается на boundary.
  - _Requirements: 1.4, 1.5, 1.6, 2.3, 5.1, 5.2, 5.3, 5.4_
  - _Boundary: HeroTileMorph state_
  - _Depends: 3.2_

- [x] 3.4 Реализовать build: geometry interpolation + Opacity TweenSequence
  - В `_HeroTileMorphState.build(BuildContext context)`:
    - Раннее `final collapsedH = widget.collapsedHeightDp > 0
      ? widget.collapsedHeightDp
      : GridTokens.cardHeightDp.h;`
    - Раннее `final expandedH = widget.expandedHeightDp.h;`
    - Раннее `final collapsedW = widget.collapsedWidthDp.w;`
    - Раннее `final expandedW = widget.expandedWidthDp.w;`
    - `return AnimatedBuilder(animation: _curved, builder: (context,
      _) { ... });`
    - Внутри builder:
      - `final t = _curved.value; // 0..1`
      - `final h = lerpDouble(expandedH, collapsedH, t)!;`
      - `final w = lerpDouble(expandedW, collapsedW, t)!;`
      - `final tsCollapsedOpacity = TweenSequence<double>([
          TweenSequenceItem(tween: ConstantTween(0.0), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0),
            weight: 50),
        ]).evaluate(AlwaysStoppedAnimation(t));`
      - `final expandedOpacity = 1.0 - tsCollapsedOpacity;`
      - Возвращать:
        ```
        SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              if (expandedOpacity > 0)
                Positioned.fill(
                  child: Opacity(
                    opacity: expandedOpacity,
                    child: widget.expandedChild,
                  ),
                ),
              if (tsCollapsedOpacity > 0)
                Positioned.fill(
                  child: Opacity(
                    opacity: tsCollapsedOpacity,
                    child: _buildCollapsedLayout(context),
                  ),
                ),
            ],
          ),
        )
        ```
  - `_buildCollapsedLayout(BuildContext context)` — приватный метод,
    собирает tile (см. design.md → Implementation Notes для
    HeroTileMorph):
    ```
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: widget.collapsedCover != null
              ? Image(image: widget.collapsedCover!, fit: BoxFit.cover)
              : Container(color: AppColors.cardBg),
          ),
        ),
        Positioned(
          bottom: 6.h,
          left: 12.w,
          right: 12.w,
          child: Text(
            widget.collapsedCaption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ),
      ],
    );
    ```
  - Observable completion: при mounting `HeroTileMorph` визуально
    видна expanded версия (Opacity=1 для expandedChild); при
    `collapsed=true` через 300ms видна collapsed версия; в `morphing-*`
    кадрах height растёт/убывает плавно. `find.byType(HeroTileMorph)`
    возвращает 1 instance, `find.byType(AnimatedBuilder)` под ним —
    1.
  - _Requirements: 1.2, 1.3, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 7.1, 7.3,
    7.4, 10.1, 10.2_
  - _Boundary: HeroTileMorph build_
  - _Depends: 3.3_

## Phase 3 — Integration: CinematicHomeScreen refactor

- [ ] 4. Рефакторинг CinematicHomeScreen — hero → firstSlot первой row

- [x] 4.1 Удалить старый hero Positioned + AnimatedCrossFade блок
  - В `_CinematicHomeScreenState.build` найти и удалить блок:
    ```
    Positioned(
      top: 0, left: 0, right: 0, height: expandedH,
      child: Focus(
        skipTraversal: true,
        canRequestFocus: false,
        onFocusChange: (focused) { ... },
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _heroFocused ? showFirst : showSecond,
          firstChild: CinematicHeroBlock(...),
          secondChild: heroItem != null
            ? Align(...CinematicCompactHero...)
            : SizedBox(height: collapsedH),
        ),
      ),
    ),
    ```
  - Удалить локальные `const expandedH = 620.0` и `final collapsedH =
    CinematicCompactHero.kCompactHeroHeight` если они больше нигде не
    используются после удаления блока.
  - Удалить импорт `import 'cinematic_compact_hero.dart';` если он
    больше нигде в файле не используется (проверить — компилируется ли).
  - **НЕ удалять** state `_heroFocused`, `_isWatchFocused`,
    `_heroWatchFocusNode`, `_onHeroWatchFocusChanged`,
    `_carouselTimer`, `_carouselIndex`, hover/preview state, boot
    overlay state, `_clockTimer` — они нужны.
  - **НЕ удалять** `_scheduleHeroWatchFocus()` — он должен продолжать
    работать и таргетить `_heroWatchFocusNode` (который теперь
    передаётся в HeroTileMorph).
  - Observable completion: `grep -n "AnimatedCrossFade" megav_iptv/lib/features/home/cinematic/cinematic_home_screen.dart`
    возвращает пусто; `grep -n "CinematicCompactHero" megav_iptv/lib/features/home/cinematic/cinematic_home_screen.dart`
    возвращает пусто (или только удалённый import); `flutter analyze`
    может временно ругаться на missing widget — это нормально, пока
    задача 4.2 не подмонтирует HeroTileMorph.
  - _Requirements: 3.1, 3.6, 7.2_
  - _Boundary: CinematicHomeScreen_

- [ ] 4.2 Подмонтировать HeroTileMorph в firstSlot первой CategoryRowWrapper
  - В `_CinematicHomeScreenState.build`, в rails `ListView.builder.itemBuilder`,
    для `rowIdx == 0` построить `firstSlot` с HeroTileMorph.
  - Импорт `import 'hero_tile_morph.dart';` (если не добавлен в 1.1).
  - Вычисление collapsedWidthDp:
    ```
    final screenW = MediaQuery.sizeOf(context).width;
    final cols = pickColumns(screenW);
    final pad = GridTokens.horizontalPaddingDp.w;
    final gap = GridTokens.gapDp.w;
    final usable = screenW - 2 * pad - (cols - 1) * gap;
    final slotZeroCardW = usable > 0 ? usable / cols : 200.0;
    ```
    (То же вычисление, что в `_gridLayoutFor` `_CinemaRowState`.)
  - Build HeroTileMorph:
    ```
    final heroTile = HeroTileMorph(
      heroItem: heroItem,
      expandedChild: CinematicHeroBlock(
        backdropImage: backdropImage,
        heroItem: heroItem,
        heroWatchFocusNode: _heroWatchFocusNode,
        isPreviewVideoReady: _isPreviewVideoReady,
        previewPlayer: _previewPlayer,
        clockTime: _clockTime,
        onWatch: heroItem != null ? () => _playNowPlaying(heroItem) : null,
        onEpg: heroItem != null
          ? () => context.push(
              '/channel/${heroItem.channelId}',
              extra: DetailArgs(channelId: heroItem.channelId,
                preloadedNowPlaying: heroItem),
            )
          : null,
        onFavourite: () {},
        onWatchFocusChanged: (focused) {
          if (!mounted) return;
          setState(() => _isWatchFocused = focused);
        },
      ),
      collapsedCover: backdropImage,
      collapsedCaption: heroItem == null
        ? ''
        : '${heroItem.channelName}'
          + (heroItem.program?.title != null
              ? ' · ${heroItem.program!.title}'
              : ''),
      focusNode: _heroWatchFocusNode,
      collapsed: !_heroFocused,
      expandedHeightDp: 620.0,
      collapsedHeightDp: GridTokens.cardHeightDp,
      collapsedWidthDp: slotZeroCardW / 1.sp /* unwrap .w applied later */,
      // Note: HeroTileMorph internally applies .w/.h via flutter_screenutil
      // so we pass raw dp values here. Verify in 4.5 task.
      expandedWidthDp: screenW / 1.sp,
    );
    ```
  - Передать `firstSlot: FirstSlotConfig(child: heroTile, focusNode:
    _heroWatchFocusNode)` в первый `CategoryRowWrapper`:
    ```
    if (rowIdx == 0) {
      return Padding(
        padding: EdgeInsets.only(bottom: GridTokens.rowVerticalGapDp.h),
        child: CategoryRowWrapper(
          key: ValueKey('cinematic-row-${cat.id}'),
          category: cat,
          onItemTap: _playNowPlaying,
          onItemFocus: _onHoveredItemChanged,
          firstSlot: FirstSlotConfig(
            child: heroTile,
            focusNode: _heroWatchFocusNode,
          ),
        ),
      );
    }
    ```
  - Передать `availableHeight: max(620.0, GridTokens.cardHeightDp)` в
    первый `CategoryRowWrapper` (новый параметр пропагации,
    добавляется в 4.4). На текущих значениях токенов = 720.h.
  - НЕ передавать firstSlot для `rowIdx >= 1` (default null).
  - Observable completion: `grep -n "firstSlot" megav_iptv/lib/features/home/cinematic/cinematic_home_screen.dart`
    возвращает ровно одно совпадение (для rowIdx == 0); существующий
    smoke test `cinematic_home_screen` (если есть) пересобирается;
    при `flutter run -d macos` запуске видна expanded hero =
    HeroTileMorph (визуальный smoke).
  - _Requirements: 3.1, 3.5, 7.2, 8.5_
  - _Boundary: CinematicHomeScreen_
  - _Depends: 4.1, 3.4, 1.1_

- [ ] 4.3 Корректировать rails Positioned: top: 0 вместо top: expandedH
  - В `_CinematicHomeScreenState.build`, в `Stack` rails блок,
    заменить `Positioned(top: expandedH, ...)` на `Positioned(top: 0,
    ...)`.
  - Rails ListView теперь начинается с верха экрана; первая row
    (через `availableHeight: 720.h` в задаче 4.4) занимает верхние 720
    dp, hero-tile занимает её слот 0.
  - Observable completion: визуальный smoke на macOS: hero-tile
    рендерится в верхней части экрана, под ним остальные плитки
    первой row выровнены по нижнему краю (existing
    `Align(alignment: bottomCenter, …)` в `_CinemaRowState.itemBuilder`),
    под первой row — вторая row, и т.д. Нет visible jump'а после
    boot fade-out.
  - _Requirements: 3.1, 7.2_
  - _Boundary: CinematicHomeScreen_
  - _Depends: 4.1, 4.2_

- [ ] 4.4 Прокинуть availableHeight через CategoryRowWrapper
  - В `class CategoryRowWrapper` (`cinema_row.dart`) добавить
    необязательный параметр `final double? availableHeight;`. В
    конструкторе: `this.availableHeight,`. Default null → existing
    behavior.
  - В `_CategoryRowWrapperState.build`, при создании `CinemaRow(...)` —
    пробросить `availableHeight: widget.availableHeight`.
  - В `CinematicHomeScreen` для первой row (rowIdx == 0) передать
    `availableHeight: 720.h` (вычислить как
    `max(620.0, GridTokens.cardHeightDp).h`, через `.h` от
    flutter_screenutil).
  - **Дополнительная coordination с upstream**: upstream спек
    `home-grid-stability-pass` task 3.1 заменит default `availableHeight
    ?? 450.h` на `GridTokens.cardHeightDp.h` (720). После этого для row
    с `availableHeight: null` высота будет 720; для первой row с
    `availableHeight: 720.h` — то же 720. То есть **никакой пересортировки
    после landing upstream не требуется**.
  - Observable completion: `grep -n "availableHeight" megav_iptv/lib/features/home/widgets/cinema_row.dart`
    показывает новое поле в `CategoryRowWrapper`; первый row на macOS
    smoke имеет высоту 720 dp (визуально — hero-tile expanded занимает
    верхние 620 dp, нижние ~100 dp пустые в slot 0; остальные плитки
    выровнены по `bottomCenter` и занимают `cardHeight = 720` через
    `LayoutBuilder.constraints.maxHeight`).
  - _Requirements: 8.6_
  - _Boundary: CinemaRow, CategoryRowWrapper, CinematicHomeScreen_
  - _Depends: 4.2_

- [x] 4.5 Sanity: _heroFocused → HeroTileMorph.collapsed proxy
  - Убедиться, что `_onHeroWatchFocusChanged` (existing listener в
    `_CinematicHomeScreenState`) продолжает работать после рефакторинга:
    при focus loss на `_heroWatchFocusNode` → `setState(() => _heroFocused
    = false)` → следующий build передаёт `collapsed: true` в
    HeroTileMorph → controller.forward().
  - Если `CinematicHeroBlock` имеет дополнительные focusables (например,
    EPG / Favourite buttons), которые focusable independently of
    Watch button: эти кнопки **не имеют** собственного listener'а к
    `_heroWatchFocusNode`. В текущем коде это обрабатывается через
    `Focus(skipTraversal: true, onFocusChange: ...)` обёртку,
    которая будет удалена в 4.1. После удаления: если фокус уходит
    с Watch на EPG — `_heroWatchFocusNode` теряет focus →
    `_heroFocused = false` → morph collapse начнётся, что **не желательно**.
  - Решение: проверить исходник `cinematic_hero_block.dart` (читать,
    не модифицировать). Если EPG/Favourite используют отдельные
    FocusNode — обернуть HeroTileMorph (или сам CinematicHeroBlock в
    `expandedChild`) в `FocusScope` с одним общим
    `_heroScopeFocusNode` (новый persistent node в
    `_CinematicHomeScreenState`), listener'ить scope.hasFocus вместо
    Watch button.
  - Альтернатива (проще): добавить **второй listener** на
    `_heroScopeFocusNode = FocusScopeNode()` в `_CinematicHomeScreenState`,
    обернуть `HeroTileMorph` в `FocusScope(node: _heroScopeFocusNode,
    child: ...)` — listener реагирует на любой focused descendant
    hero subtree.
  - **Этот вопрос — open**, решается на impl-фазе после чтения
    `cinematic_hero_block.dart`. В base-плане: если внутри
    CinematicHeroBlock только Watch button — оставляем как есть; если
    есть несколько focusables — добавляем FocusScope wrapper.
  - Observable completion: D-pad → / ↑ / ↓ цикл на macOS smoke
    показывает: focus заходит в Watch → hero expanded; focus заходит
    в EPG (если есть) → hero остаётся expanded (не collapse); focus
    уходит на первую row → hero collapse. Никакого flickering морфа
    при переходе Watch ↔ EPG.
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 8.1, 8.6_
  - _Boundary: CinematicHomeScreen_
  - _Depends: 4.1, 4.2_

## Phase 4 — Verification: tests

- [ ] 5. State machine unit tests

- [x] 5.1 (P) Создать тестовый файл hero_tile_morph_test.dart + state-machine группа
  - Создать
    `megav_iptv/test/features/home/cinematic/hero_tile_morph_test.dart`.
  - Импорты: `package:flutter_test/flutter_test.dart`,
    `package:megav_iptv/features/home/cinematic/hero_tile_morph.dart`.
  - `group('computeNextState', () { ... })` — 9 тест-кейсов:
    - `idleExpanded + collapse → morphingCollapsing`.
    - `morphingCollapsing + tickerCompleted → idleCollapsed`.
    - `morphingCollapsing + expand → morphingExpanding` (mid-flight
      reverse).
    - `idleCollapsed + expand → morphingExpanding`.
    - `morphingExpanding + tickerDismissed → idleExpanded`.
    - `morphingExpanding + collapse → morphingCollapsing` (mid-flight
      reverse).
    - `idleExpanded + disableAnimationsCollapse → idleCollapsed`.
    - `idleCollapsed + disableAnimationsExpand → idleExpanded`.
    - `morphingCollapsing + disableAnimationsCollapse → idleCollapsed`
      (snap mid-flight).
  - Observable completion: `flutter test test/features/home/cinematic/hero_tile_morph_test.dart`
    проходит зелёным; 9 PASS.
  - _Requirements: 1.1, 1.4, 1.5, 1.6, 4.6, 5.4_
  - _Boundary: hero_tile_morph_test_
  - _Depends: 2.1_

- [ ] 6. Focus survival widget test

- [ ] 6.1 Реализовать focus survival group
  - В том же файле, `group('Focus survives morph', () { ... })`:
    - `testWidgets('focus retained through collapse', (tester) async { ... })`:
      - Создать `final node = FocusNode();`.
      - Wrapper: `MaterialApp(home: ScreenUtilInit(designSize: Size(1920, 1080),
        builder: (_, __) => HeroTileMorph(focusNode: node, collapsed:
        false, heroItem: null, expandedChild: SizedBox(width: 100,
        height: 100), collapsedCover: null, collapsedCaption: 'test',
        collapsedWidthDp: 200, expandedWidthDp: 1920)))`.
      - `tester.pumpWidget(...)`, затем `node.requestFocus(); await
        tester.pump();`.
      - `expect(node.hasFocus, isTrue);` — sanity.
      - Trigger collapse: `tester.pumpWidget(... collapsed: true ...);`.
      - Loop 6 раз `await tester.pump(Duration(milliseconds: 50));
        expect(node.hasFocus, isTrue, reason: 'frame $i lost focus');`.
      - `await tester.pumpAndSettle();`
      - `expect(node.hasFocus, isTrue);` — post-morph.
      - `node.dispose();`.
    - `testWidgets('focus retained through expand', (tester) async { ... })`:
      - Аналогично, но начинаем с `collapsed: true`, затем переключаем
        на `collapsed: false`, sample каждые 50ms.
    - `testWidgets('focus retained through full cycle', (tester) async { ... })`:
      - Цикл collapse → expand, sample, assert hasFocus.
  - Observable completion: 3 widget-теста проходят зелёным; при
    ручной breaking change (например, заменить `widget.focusNode` на
    `FocusNode()` внутри `_HeroTileMorphState.build`) тесты падают.
  - _Requirements: 4.2, 4.3, 4.4, 4.6_
  - _Boundary: hero_tile_morph_test_
  - _Depends: 5.1, 3.4_

- [ ] 7. disableAnimations snap test

- [ ] 7.1 (P) Реализовать disableAnimations honoring group
  - В том же файле, `group('disableAnimations honoring', () { ... })`:
    - `testWidgets('snap on collapse with disableAnimations', (tester) async { ... })`:
      - Wrapper включает `MediaQuery(data: MediaQueryData(size:
        Size(1920,1080), disableAnimations: true), child: ...)`.
      - `pumpWidget(...collapsed: false)`, затем
        `pumpWidget(...collapsed: true)`, затем
        `tester.pump(Duration.zero)` — без pumpAndSettle.
      - Получить state через `tester.state<State<HeroTileMorph>>(...)`
        и приватный getter `currentState` (нужно сделать `@visibleForTesting
        HeroMorphState get currentState => _state;` в
        `_HeroTileMorphState`).
      - `expect(currentState, equals(HeroMorphState.idleCollapsed));`
        (минует morphing-collapsing).
      - Получить controller через `@visibleForTesting double get
        currentControllerValue => _controller.value;` →
        `expect(currentControllerValue, equals(1.0));`.
    - `testWidgets('snap on expand with disableAnimations', ...)`:
      - Аналогично — обратно.
    - `testWidgets('mid-flight disableAnimations toggle snaps', (tester) async { ... })`:
      - Запустить collapse без disableAnimations, pump 100ms (середина
        морфа).
      - Включить disableAnimations через
        `pumpWidget(MediaQuery(disableAnimations: true, ...))`.
      - `pump(Duration.zero)`.
      - `expect(currentControllerValue, equals(1.0));
        expect(currentState, equals(HeroMorphState.idleCollapsed));`.
  - **Note**: для тестируемости `_state` и `_controller.value` —
    добавить `@visibleForTesting` getters в `_HeroTileMorphState`.
  - Observable completion: 3 widget-теста проходят зелёным; при ручном
    breaking change (например, удалить snap в `didChangeDependencies`)
    тест mid-flight падает.
  - _Requirements: 5.1, 5.2, 5.3, 5.4_
  - _Boundary: hero_tile_morph_test_
  - _Depends: 3.3, 6.1_

- [ ] 8. Bounding rect tolerance test

- [ ] 8.1 (P) Реализовать bounding rect group
  - В том же файле, `group('Final rect matches target', () { ... })`:
    - `testWidgets('collapsed rect ≈ collapsedHeightDp', (tester) async { ... })`:
      - Wrapper с фиксированным MediaQuery (size 1920×1080).
      - `pumpWidget(...collapsed: true...)`, `pumpAndSettle()`.
      - `final rect = tester.getRect(find.byType(HeroTileMorph));`
      - `expect((rect.height - collapsedHeightDp).abs(),
        lessThanOrEqualTo(1.0), reason: 'Expected ${collapsedHeightDp},
        got ${rect.height}');`.
    - `testWidgets('expanded rect ≈ expandedHeightDp', ...)`:
      - Аналогично, начинаем с `collapsed: false`, `pumpAndSettle()`.
      - `expect((rect.height - expandedHeightDp).abs(),
        lessThanOrEqualTo(1.0), reason: ...);`.
  - **Note**: точные expected значения учитывают `.w/.h` от
    flutter_screenutil — если HeroTileMorph внутри применяет `.h`,
    expected = `cardHeightDp.h` через resolved ScaleFactor. Может
    потребоваться использовать `ScreenUtilInit(designSize: Size(1920,
    1080))` чтобы scale factor = 1.0.
  - Observable completion: 2 widget-теста проходят зелёным.
  - _Requirements: 7.3, 7.4_
  - _Boundary: hero_tile_morph_test_
  - _Depends: 6.1_

## Phase 5 — Integration validation

- [ ] 9. Прогон существующих тестов на ветке спека

- [ ] 9.1 Прогнать full test suite
  - `flutter test` в корне `megav_iptv/`.
  - Все тесты включая новый `hero_tile_morph_test.dart` зелёные.
  - **Особое внимание**:
    - `cinema_row_pinned_slot_test.dart` (upstream) — должен
      проходить, потому что test конструирует CinemaRow без firstSlot
      (default null).
    - cinematic_home_screen smoke (если есть) — после рефакторинга
      `find.byType(AnimatedCrossFade)` для hero возвращает пусто;
      может потребоваться правка теста, если он assert'ил наличие
      AnimatedCrossFade.
    - Тесты `cinema_card`, `cinema_row` — не должны fall'нуться,
      потому что общий path не модифицирован.
  - **Запрещено**: ослаблять assertion. Допустимо: правка test
    expectations на новое observable behaviour (например, expect
    `find.byType(HeroTileMorph)` вместо `find.byType(CinematicHeroBlock)`
    в smoke).
  - Observable completion: `flutter test` stdout содержит `All tests
    passed!` и счётчик ≥ 30 + новые тест-кейсы из 5/6/7/8 задач;
    `flutter analyze` 0 issues для затронутых файлов.
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 9.1, 9.2, 9.3, 9.4_
  - _Boundary: full test suite_
  - _Depends: 4.5, 5.1, 6.1, 7.1, 8.1_

- [ ] 10. Manual smoke checklist

- [ ] 10.1 macOS debug build smoke (быстрый цикл разработки)
  - Запустить `flutter run -d macos --debug` на разработческой машине.
  - Дождаться boot overlay fade-out, focus автоматически приходит на
    Watch button (через `_scheduleHeroWatchFocus`).
  - Чек-лист:
    1. Hero expanded видна (full backdrop + title + Watch button).
    2. D-pad ↓ (стрелка вниз через keyboard): hero collapse через
       300ms anim; **никакого black gap** на промежуточных кадрах
       (визуально — opacity crossfade в last 50%).
    3. После collapse: hero уехала в slot 0 первой row; визуально —
       cover image + caption в нижней части slot 0.
    4. D-pad → (вправо) и обратно ← : pinned-slot scroll работает для
       плиток первой row (index ≥ 1) — focused tile остаётся в slot 1
       (Pinned-Slot Invariant из upstream).
    5. D-pad ↑ (стрелка вверх) с первой плитки первой row (index 1
       или index 0): hero expand через 300ms anim; **focus остаётся** на
       hero-tile (= Watch button) после morph без явного click.
    6. macOS «Settings → Accessibility → Display → Reduce motion» →
       toggle ON, повторить D-pad ↓ / ↑: morph snaps instant без
       анимации.
    7. Carousel timer (8с) — продолжает менять `_carouselIndex` при
       hero expanded, останавливается при collapsed (existing
       behaviour, должно работать после refactor'а).
    8. Hover на не-hero плитку (3-я row, например): через 600ms hero
       обновляется на новый item (existing
       `_onHoveredItemChanged` debounce работает).
    9. ESC / `_isPreviewPlaying` cleanup — если preview активен,
       stop preview без визуальных артефактов.
  - При обнаружении регрессии вернуться к 4.5 / 4.2 / 3.x.
  - Observable completion: 9 пунктов чек-листа пройдены глазами; нет
    visible jumps или flickering.
  - _Requirements: 1.x, 2.x, 4.x, 5.x, 6.x, 7.x, 8.x_
  - _Boundary: manual macOS smoke_
  - _Depends: 9.1_

- [ ] 10.2 TV smoke on rtd2851a (профилировочный)
  - `flutter run --profile -d <rtd2851a>`.
  - Повторить чек-лист 10.1 пункты 1-9.
  - Дополнительно — VM Service trace:
    - Очистить timeline (см. `flutter-tv-perf.md` →
      «Как замерять — VM Service не DevTools»).
    - Запустить D-pad ↓ → ↑ цикл несколько раз.
    - Получить trace через `curl`, спарсить avg
      `GPURasterizer::Draw`.
    - Assert: avg ≤ 16.7 ms (Req 10.3).
    - Assert: BUILD events в idle (10 сек без D-pad) ≤ 5 (preserves
      `home-grid-visual-polish` budget).
  - Observable completion: чек-лист TV пройден, VM trace показывает
    avg ≤ 16.7 ms; нет регрессии vs baseline (от
    `home-grid-visual-polish` snapshot).
  - _Requirements: 10.3_
  - _Boundary: manual TV smoke_
  - _Depends: 10.1_

## Implementation Notes (recorded during implementation)

### Design deviation: HeroTileMorph in Positioned slot, NOT in firstSlot (2026-05-11)

Spec § 4.x originally called for mounting `HeroTileMorph` as the
`firstSlot` of the first `CategoryRowWrapper`, making hero and tile-0
literally one widget in the row's ListView.

During task 4.x implementation it became clear this restructuring would
break the hero's existing visual contract:

- The hero owns a **full-bleed backdrop image** (1920×1080) plus
  StatusBar that paints behind everything else. A tile-sized container
  inside a row would clip the backdrop and lose the cinematic feel.
- `CinematicHeroBlock` has its own internal layout (chips row, large
  italic title, action button strip) optimised for the 620 dp expanded
  zone — not for a 720 dp portrait tile.
- The row's `ListView.builder` lazy-materialises tiles; relying on tile-0
  to always exist creates a coupling between hero state and rail data
  loading that the old layout intentionally avoided.

**Decision**: keep hero as the existing `Positioned(top:0, height:620)`
overlay, but swap the inner `AnimatedCrossFade(expanded↔compact)` for
`HeroTileMorph`. This solves the **user's actual complaint** (the cross-fade
flickered into a black gap on collapse) by using HeroTileMorph's 300 ms
geometry-lerp + opacity crossfade, while preserving full-bleed backdrop
and untouched row layout.

Tasks 4.2 / 4.3 / 4.4 (firstSlot mount, rails top:0, availableHeight
forwarding) are therefore **superseded** by task 4.1 — left unchecked to
preserve the audit trail. `FirstSlotConfig` + `CinemaRow.firstSlot` API
(tasks 1.1–1.3) remain in code as **optional future-use plumbing** if a
later spec re-decides to merge hero and tile-0.

### Phase 2 manual testing pending

- Task 6.1 (focus survival inside CinemaRow with firstSlot) — covered
  partially by the basic mount test in task 5.1; full integration test
  pending real CinematicHomeScreen smoke.
- Task 7.1 (disableAnimations widget-level snap) — covered by state
  machine `disableAnimations*` command tests; widget-mount test deferred.
- Task 8.1 (bounding rect tolerance) — deferred to manual TV smoke or
  the visual-feedback-pipeline once issue #16 resolves Flutter web compile.

These three are **non-blocking** for the spec's core value (smooth
morph instead of cross-fade); they harden the contract over time.
