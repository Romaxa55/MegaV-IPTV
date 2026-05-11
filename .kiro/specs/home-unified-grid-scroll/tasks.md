# Implementation Plan — home-unified-grid-scroll

Стратегия: foundation (tokens) → core (новые компоненты) → integration (вшивание в экран) → cleanup (удаление obsolete) → validation (тест + smoke). Все sub-tasks 1–3 часа, наблюдаемое «done»-состояние явно прописано. `(P)` помечает sub-tasks безопасные для параллельного запуска (только когда они изолированы по `_Boundary:_`).

## 1. Foundation — Vertical pinned-slot tokens

- [x] 1.1 Расширить `GridTokens` константами вертикального pinned-slot инварианта
  - Добавить в `lib/features/home/widgets/_grid_tokens.dart`: `verticalPinnedSlotIdx = 1`, `heroRowHeightDp = 600`, `rowStrideDp = cardHeightDp`, `verticalScrollAnimation = Duration(milliseconds: 300)`, `verticalScrollCurve = Curves.easeInOutCubic`.
  - Сохранить файл без `flutter_screenutil` импортов (pure tokens).
  - Дописать dartdoc у каждой константы со ссылкой на Requirement IDs.
  - Наблюдаемое «done»: `flutter analyze` зелёный; новые константы доступны через `GridTokens.verticalPinnedSlotIdx`, `GridTokens.heroRowHeightDp` и т.д.; существующие конст. не изменены.
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 3.3, 3.4_
  - _Boundary: GridTokens_

## 2. Core — Unified vertical scroller and hero wrapper

- [x] 2.1 (P) Реализовать `HeroAsRow` обёртку
  - Создать `lib/features/home/cinematic/hero_as_row.dart` со stateless-виджетом, который оборачивает произвольный child в `SizedBox(height: GridTokens.heroRowHeightDp.h, child: child)`.
  - Принимает только `Widget child` (без логики focus / state).
  - Дописать dartdoc: «hero как row-0 для `UnifiedHomeGridScroller`; ровно `heroRowHeightDp` высотой».
  - Наблюдаемое «done»: файл существует, `flutter analyze` зелёный, виджет можно инстанцировать в тесте.
  - _Requirements: 1.3, 5.1, 5.3, 5.5_
  - _Boundary: HeroAsRow_
  - _Depends: 1.1_

- [x] 2.2 Реализовать каркас `UnifiedHomeGridScroller` — вертикальный ListView и controller
  - Создать `lib/features/home/cinematic/unified_home_grid_scroller.dart` со `StatefulWidget` принимающим `heroBuilder`, `categories`, `rowBuilder`, опциональный `footer`, опциональный `heroFocusNode`, callback `onHeroFocusChanged`.
  - Внутри `State`: создать и dispose-ить `ScrollController _scrollController`, рендерить `ListView.builder(controller: _scrollController, itemCount: 1 + categories.length + (footer != null ? 1 : 0), cacheExtent: 1500.h, addAutomaticKeepAlives: true, addRepaintBoundaries: true, clipBehavior: Clip.none, itemBuilder: ...)`.
  - itemBuilder: idx=0 → `HeroAsRow(child: heroBuilder(ctx))`; idx 1..N → `rowBuilder(ctx, categories[idx-1])`; idx=N+1 → footer.
  - Никакой focus-логики пока, только структура.
  - Наблюдаемое «done»: виджет рендерится в widget-тесте; виден hero (row-0) и первая cinema row; нет exceptions; `flutter analyze` зелёный.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 7.5, 7.6_
  - _Boundary: UnifiedHomeGridScroller_
  - _Depends: 1.1, 2.1_

- [x] 2.3 Добавить Vertical Pinned-Slot focus dispatch и clamping математику
  - В `UnifiedHomeGridScroller` добавить `int _focusedRowIdx = 0`.
  - Обернуть каждую row (idx=0 hero и idx=1..N cinema rows) в `Focus(skipTraversal: true, onFocusChange: (focused) { if (focused) _onRowFocused(rowIdx); })`.
  - Реализовать `double _verticalOffsetForRow(int idx)`: `if (idx <= verticalPinnedSlotIdx) return 0; var off = heroRowHeightDp.h; if (idx >= 3) off += (idx - 2) * rowStrideDp.h; return off.clamp(0, _scrollController.position.maxScrollExtent);`.
  - Реализовать `_animateToFocusedRow()` через `WidgetsBinding.instance.addPostFrameCallback` + `_scrollController.animateTo(target, duration: verticalScrollAnimation, curve: verticalScrollCurve)`.
  - В `_onRowFocused(idx)`: если `idx != _focusedRowIdx` → `setState(() => _focusedRowIdx = idx); _animateToFocusedRow();` и вызвать `widget.onHeroFocusChanged?.call(idx == 0)`.
  - Наблюдаемое «done»: в widget-тесте при `tester.binding.focusManager`-запросе фокуса на focusable внутри row=2 — controller.offset смещается к `heroRowHeightDp + 0 * rowStrideDp` (= `heroRowHeightDp.h`); leading-edge clamp возвращает 0 при idx=0 и idx=1.
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4, 3.7, 5.1, 5.2, 5.3, 5.6, 5.7, 7.3, 7.4, 8.1, 8.3_
  - _Boundary: UnifiedHomeGridScroller_
  - _Depends: 2.2_

- [x] 2.4 Зафиксировать формальный контракт Vertical Pinned-Slot Invariant в dartdoc
  - В верхней части `unified_home_grid_scroller.dart` добавить dartdoc-блок по образцу `CinemaRow:108–152`: формальные 4 клаузы (middle traversal Δ ≤ 1.0 dp на оси Y; leading-edge clamp; trailing-edge clamp; tolerance ±1.0 dp), ссылка на test-файл из задачи 5.1.
  - Наблюдаемое «done»: dartdoc виден в IDE при наведении на `UnifiedHomeGridScroller`; содержит ссылку на `unified_home_grid_scroller_test.dart` и `verticalPinnedSlotIdx`.
  - _Requirements: 2.1, 2.2, 2.3, 2.4_
  - _Boundary: UnifiedHomeGridScroller_
  - _Depends: 2.3_

## 3. Integration — CinematicHomeScreen rewrite

- [x] 3.1 Заменить Stack(Positioned(hero) + Positioned(ListView)) на UnifiedHomeGridScroller
  - В `lib/features/home/cinematic/cinematic_home_screen.dart`:
    - Удалить локальный `_heroFocused` + связанный `Focus(skipTraversal:true).onFocusChange` блок (строки ~425–500 в текущей версии).
    - Удалить структуру `Stack { Positioned(top:0, height:expandedH, child: HeroTileMorph(...)) + Positioned(top:expandedH, child: ListView.builder(...)) }`.
    - Заменить на `UnifiedHomeGridScroller(heroBuilder: (ctx) => CinematicHeroBlock(...), categories: categories, rowBuilder: (ctx, cat) => CategoryRowWrapper(category: cat, onItemTap: _playNowPlaying, onItemFocus: _onHoveredItemChanged), footer: const Padding(padding: EdgeInsets.only(top: 8), child: CinematicRemoteHintFooter()), heroFocusNode: _heroWatchFocusNode, onHeroFocusChanged: _onHeroFocusChanged)`.
    - Удалить импорты `hero_tile_morph.dart` и `cinematic_compact_hero.dart`.
    - Добавить импорт `unified_home_grid_scroller.dart`.
  - Реализовать `_onHeroFocusChanged(bool focused)`: при `focused == true` — запустить carousel (`_restartCarousel(featured)`), иначе `_carouselTimer?.cancel()`.
  - Наблюдаемое «done»: `cinematic_home_screen.dart` компилируется, `flutter analyze` зелёный; экран строится в widget-тесте без exceptions; визуально hero виден сверху, первая cinema row под ним; pre-commit hook 600-line limit удовлетворён (файл должен сократиться до ~350 строк).
  - _Requirements: 1.1, 1.2, 1.3, 1.5, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 7.6, 10.1, 10.2, 10.3, 10.4, 10.5, 11.1, 11.2, 11.3, 11.4_
  - _Boundary: CinematicHomeScreen_
  - _Depends: 2.3_

- [x] 3.2 Передавать фокус boot-overlay → hero как row-0 через `_heroWatchFocusNode`
  - Проверить что `_scheduleHeroWatchFocus` (post-frame callback) корректно вызывает `_heroWatchFocusNode.requestFocus()` после fade-out boot overlay.
  - Через `UnifiedHomeGridScroller.heroFocusNode` гарантировать что focus event от этого node триггерит `_onRowFocused(0)` — это можно реализовать через дополнительный `addListener` на `heroFocusNode` внутри scroller-а или просто полагаясь на `Focus(skipTraversal:true)`-обёртку вокруг hero row (родительский focus subtree уже его покроет).
  - Наблюдаемое «done»: после fade-out boot overlay (420 ms) фокус оказывается на кнопке «Смотреть» hero; vertical scrollOffset = 0; `_focusedRowIdx = 0`.
  - _Requirements: 5.3, 10.5, 11.2_
  - _Boundary: CinematicHomeScreen, UnifiedHomeGridScroller_
  - _Depends: 3.1_

## 4. Cleanup — Remove HeroTileMorph and FirstSlotConfig

- [x] 4.1 Убрать FirstSlotConfig из CinemaRow и CategoryRowWrapper
  - В `lib/features/home/widgets/cinema_row.dart`:
    - Удалить параметр `FirstSlotConfig? firstSlot` из конструкторов `CategoryRowWrapper` и `CinemaRow`.
    - Удалить ветку `if (index == 0 && widget.firstSlot != null) { return Padding(...child: widget.firstSlot!.child); }` в `itemBuilder` (текущие строки 434–438).
    - Удалить методы / listener-логику: `_onFirstSlotFocusChange`, `addListener`/`removeListener` для `firstSlot?.focusNode` в `initState`/`didUpdateWidget`/`dispose`.
    - Удалить импорт `import '../cinematic/hero_tile_morph.dart' show FirstSlotConfig;`.
  - Наблюдаемое «done»: `flutter analyze` зелёный; ни одного reference на `FirstSlotConfig` или `firstSlot` в проекте не осталось (проверить `grep -rn "FirstSlotConfig\|\.firstSlot" megav_iptv/lib megav_iptv/test`); `cinema_row.dart` компилируется.
  - _Requirements: 4.1, 4.2, 4.4, 6.1, 6.2_
  - _Boundary: CinemaRow_
  - _Depends: 3.1_

- [x] 4.2 Удалить hero_tile_morph.dart и его тесты
  - Удалить `lib/features/home/cinematic/hero_tile_morph.dart`.
  - Удалить `test/features/home/cinematic/hero_tile_morph_test.dart` (если существует).
  - Проверить grep `grep -rn "HeroTileMorph\|hero_tile_morph" megav_iptv/` — нет references.
  - Наблюдаемое «done»: файлы удалены; `flutter analyze` зелёный; полный набор тестов (`flutter test`) проходит (минус тесты внутри удалённого файла); число failing тестов = 0.
  - _Requirements: 6.1, 6.2, 6.3, 6.4_
  - _Boundary: HeroTileMorph_
  - _Depends: 4.1_

## 5. Validation — Vertical Pinned-Slot test and regression

- [x] 5.1 Реализовать widget-тест Vertical Pinned-Slot Invariant
  - Создать `test/features/home/cinematic/unified_home_grid_scroller_test.dart`.
  - Harness повторяет стиль `cinema_row_pinned_slot_test.dart`: `MediaQuery(size: Size(1920, 1080)) + ScreenUtilInit + MaterialApp + Scaffold + Column(externalFocusNode + UnifiedHomeGridScroller(...))`.
  - Stub `heroBuilder` → `FocusableActionDetector`-обёртка с фиксированным `FocusNode`, `categories` → 7 dummy `CinemaCategory` объектов, `rowBuilder` → стаб-виджет с focusable плитками (можно использовать `CinemaRow` с фейковыми items).
  - 3 теста:
    1. **Middle-traversal**: пройти focus row 2 → 3 → 4 → 5; assert screen-space Y focused row Δ ≤ 1.0 dp между соседними переходами.
    2. **Leading-edge clamp**: focused row=0 и row=1 → `scrollController.position.pixels == 0.0`.
    3. **Trailing-edge clamp**: focused row=last → `(offset - maxScrollExtent).abs() ≤ 1.0`.
  - Наблюдаемое «done»: `flutter test test/features/home/cinematic/unified_home_grid_scroller_test.dart` — 3/3 PASS.
  - _Requirements: 9.1, 9.2, 9.3_
  - _Boundary: unified_home_grid_scroller_test_
  - _Depends: 3.1, 4.2_

- [x] 5.2 Проверить регрессию горизонтального invariant и всего home-test suite
  - Запустить `flutter test test/features/home/widgets/cinema_row_pinned_slot_test.dart` — должен быть 3/3 PASS.
  - Запустить полный `flutter test test/features/home/` — все тесты зелёные; число тестов после удаления `hero_tile_morph_test.dart` уменьшилось ровно на количество тестов в нём.
  - Запустить `flutter analyze` — 0 issues.
  - Наблюдаемое «done»: все home-тесты зелёные; `flutter analyze` 0 issues; commit-msg фиксирует diff числа тестов с пояснением.
  - _Requirements: 4.4, 6.3, 7.6, 9.4, 9.5_
  - _Boundary: home test suite_
  - _Depends: 5.1_

- [ ] 5.3 Smoke на macOS через `flutter run -d macos`
  - Запустить приложение, дождаться скрытия boot overlay (фокус → кнопка «Смотреть»).
  - Проверить D-pad parity: стрелка ↓ — фокус на первую плитку первой row, hero уехала наверх; стрелка ↓ — на первую плитку второй row, focused row screen-space Y не сдвинулась; ←/→ — горизонтальный pinned slot работает как раньше; ↑ из row-2 → возврат на row-1 без артефактов; ↑ из row-1 → hero полностью видна.
  - Проверить ESC → preview закрывается (если был запущен).
  - Анимация скролла визуально плавная, без «дёрганий» (≤ 300 ms `easeInOutCubic`).
  - Hero carousel rotation работает когда focused row = row-0; останавливается когда focused row ≥ 1.
  - Наблюдаемое «done»: чек-лист пройден визуально; commit-msg фиксирует «macOS smoke OK».
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 4.1, 4.2, 4.3, 4.5, 5.1, 5.2, 5.6, 5.7, 8.1, 8.2, 10.5_
  - _Boundary: macOS smoke_
  - _Depends: 5.2_

- [ ] 5.4 (опционально) Smoke на rtd2851a с GPU trace
  - Установить debug/profile build на rtd2851a, выполнить тот же чек-лист что в 5.3.
  - Снять `getVMTimeline` трасу за 5–10 секунд активного D-pad ↑/↓ через VM Service curl-эндпоинт (см. `flutter-tv-perf.md:329–344`).
  - Распарсить avg / p95 `GPURasterizer::Draw`; цель — avg ≤ 16.7 ms.
  - Если бюджет не выдерживается — анализ через `kiro-debug`, регрессионный fix в новом коде или снижение `verticalScrollAnimation` до 250 ms.
  - Наблюдаемое «done»: trace JSON приложен к спеке в `snapshots/` (по аналогии с `home-grid-visual-polish/snapshots/`); avg `GPURasterizer::Draw` метрика зафиксирована в commit message.
  - _Requirements: 7.1, 7.2, 7.3, 7.4_
  - _Boundary: rtd2851a smoke_
  - _Depends: 5.3_
