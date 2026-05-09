# Implementation Plan

> Спек: `home-grid-visual-polish`. См. `requirements.md` (6 требований) и `design.md` (3 модифицируемых файла + 2 новых теста).
>
> Принципы: foundation → core → integration → validation. Major 1 — token addition (foundation). Major 2 — два независимых полиш-изменения (могут идти параллельно, разные файлы). Major 3 — auto-тесты. Major 4 — manual TV-приёмка.

---

## 1. Foundation: добавить fadeEdgeFraction в токены

- [x] 1.1 Добавить `static const double fadeEdgeFraction = 0.05` в `GridTokens`
  - Открыть `megav_iptv/lib/features/home/widgets/_grid_tokens.dart`.
  - Добавить новую `static const double fadeEdgeFraction = 0.05;` в `class GridTokens` рядом с другими размерными токенами (`gapDp`, `horizontalPaddingDp`).
  - Добавить doc-comment на одну строку: «Доля ширины ряда, занимаемая правым fade-edge gradient».
  - Наблюдаемое: `flutter analyze lib/features/home/widgets/_grid_tokens.dart` чисто; импорт из других файлов работает; существующий `grid_tokens_test.dart` всё ещё 11/11 зелёный.
  - _Requirements: 1.2_
  - _Boundary: GridTokens_

---

## 2. Core: визуальные правки

- [x] 2.1 Обернуть ListView.builder в `cinema_row.dart` в ShaderMask с fade-out на правом крае
  - Найти горизонтальный `ListView.builder` в `_CinemaRowState.build` (он в `Positioned(top: -72.h, ...)`).
  - Обернуть его в `ShaderMask` с `blendMode: BlendMode.dstOut` и `shaderCallback`, возвращающим `LinearGradient(begin: centerLeft, end: centerRight, stops: [0.0, 1.0 - GridTokens.fadeEdgeFraction, 1.0], colors: [Colors.transparent, Colors.transparent, Colors.black])`.
  - Все остальные виджеты (`FocusTraversalGroup`, `ListView.builder` параметры, `clipBehavior: Clip.none`, `cacheExtent`, `addAutomaticKeepAlives`, `addRepaintBoundaries`) сохраняются.
  - Левый край НЕ затухает (Req 1.3) — gradient stops это обеспечивают (на левом краю opacity = 1 = visible).
  - Наблюдаемое: визуально на TV (или в widget-test) последняя частично-видимая плитка справа плавно затухает; первая плитка слева остаётся четкой; `flutter analyze` чисто; все 17 существующих тестов проходят.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
  - _Depends: 1.1_
  - _Boundary: CinemaRow_

- [x] 2.2 Добавить Visibility-обёртку над AnimatedOpacity full overlay в `cinema_card.dart`
  - В `_CinemaCardState` добавить поле `bool _focusJustLost = false` и `Timer? _focusLossTimer`.
  - Добавить геттер `bool get _shouldRenderFullOverlay => widget.isFocused || _focusJustLost`.
  - Реализовать `didUpdateWidget(CinemaCard oldWidget)`:
    - Если `oldWidget.isFocused == true && widget.isFocused == false`: `setState(() => _focusJustLost = true)`, отменить старый таймер, запустить новый `Timer(GridTokens.overlayFade + Duration(milliseconds: 16), ...)` который через истечение делает `setState(() => _focusJustLost = false)`.
    - Если `widget.isFocused == true`: отменить таймер, `_focusJustLost = false` (без setState — состояние совпадает с `_shouldRenderFullOverlay`).
  - В `dispose` отменить `_focusLossTimer`.
  - Метод `_buildFullOverlayWithFade()` оборачивается в `Visibility(visible: _shouldRenderFullOverlay, maintainState: false, maintainSize: false, maintainAnimation: false, child: <existing IgnorePointer + AnimatedOpacity + _buildFullOverlay tree>)`.
  - Наблюдаемое: `flutter test test/features/home/widgets/cinema_card_overlay_test.dart` всё ещё проходит 2/2 (старый тест проверяет focus=true → opacity=1 и focus=false → opacity=0; теперь дополнительно у нефокусированной плитки виджеты Key('rating-badge') etc. отсутствуют в дереве, но opacity-проверка всё ещё валидна для focused state); `flutter analyze` чисто.
  - _Requirements: 2.1, 2.2, 2.3, 4.4_
  - _Depends: 1.1_
  - _Boundary: CinemaCard_

- [x] 2.3 Увеличить bottom-padding compact-строки канала
  - В `cinema_card.dart` найти место рендеринга имени канала в compact-overlay (вероятно `_buildBottomChannelLine` или аналог).
  - Если строка сейчас в `Padding(EdgeInsets.only(bottom: <X>.h))` где X < 6 — увеличить до 6.
  - Если padding отсутствует — обернуть в `Padding(EdgeInsets.only(bottom: 6.h), child: <existing>)`.
  - НЕ менять типографику (`fontSize`, `fontWeight`, `color`).
  - Наблюдаемое: визуально на TV имя канала имеет видимый воздух от нижнего края карточки; снапшот при сравнении с baseline показывает разницу; все 17 существующих тестов проходят.
  - _Requirements: 3.1, 3.2, 3.3_
  - _Depends: none (independent of 1.1, 2.1, 2.2 — только касается layout, не токенов)_
  - _Boundary: CinemaCard_

---

## 3. Validation: новые auto-тесты

- [x] 3.1 (P) Widget-тест на присутствие ShaderMask в CinemaRow
  - Создать `test/features/home/widgets/cinema_row_fade_edge_test.dart`.
  - Pump `CinemaRow` с 5 fake items в `MaterialApp + Scaffold + ScreenUtilInit`.
  - Assert `find.byType(ShaderMask)` returns `findsOneWidget`.
  - Optional: проверить что `ShaderMask` имеет `blendMode: BlendMode.dstOut` через `tester.widget<ShaderMask>(...)`.
  - Запуск: `flutter test test/features/home/widgets/cinema_row_fade_edge_test.dart`.
  - Наблюдаемое: тест зелёный.
  - _Requirements: 1.1_
  - _Depends: 2.1_
  - _Boundary: CinemaRow_

- [x] 3.2 (P) Widget-тест на отсутствие full overlay в дереве у нефокусированной карточки
  - Создать `test/features/home/widgets/cinema_card_offstage_full_test.dart`.
  - Test 1: pump `CinemaCard(isFocused: false, ...)` с fake item. Assert: `find.byKey(const ValueKey('rating-badge'))` → `findsNothing`. Same for 4 других keys (`age-rating`, `genre-emoji`, `programme-title`, `progress-section`). Channel-name (Key('channel-name')) — должен быть found (compact preserved).
  - Test 2: pump `isFocused: true`, `pump(Duration(milliseconds: 200))`. Assert: все 5 full keys → `findsOneWidget`. Channel-name тоже found.
  - Test 3 (удержание fade-out): pump `isFocused: true`, `pump(200ms)`. Switch to `isFocused: false`, **немедленно** (без pump) — assert keys всё ещё в дереве (Visibility держит). `pump(Duration(milliseconds: GridTokens.overlayFade.inMilliseconds + 50))`. Assert keys → `findsNothing`.
  - Запуск: `flutter test test/features/home/widgets/cinema_card_offstage_full_test.dart`.
  - Наблюдаемое: 3 теста зелёные.
  - _Requirements: 2.1, 2.2, 2.3_
  - _Depends: 2.2_
  - _Boundary: CinemaCard_

- [ ] 3.3 Запустить все 22 теста (17 существующих + 5 новых) и убедиться что регрессий нет
  - `cd megav_iptv && flutter test test/`.
  - Все тесты должны проходить.
  - Наблюдаемое: `+22 -0`, exit code 0.
  - _Requirements: 5.2_
  - _Depends: 3.1, 3.2_
  - _Boundary: All test files_

---

## 4. Manual: приёмка на TV

- [ ] 4.1 Снять after-снапшоты с TV
  - Запустить `cd megav_iptv && flutter run -d 192.168.100.8:5555 --profile`.
  - Дождаться загрузки главного экрана.
  - Снять чистый скрин: `adb -s 192.168.100.8:5555 exec-out screencap -p > .kiro/specs/home-grid-visual-polish/snapshots/after_clean.png`.
  - Включить performance overlay (`P`), поскроллить ряд, снять во время скролла: `adb -s 192.168.100.8:5555 exec-out screencap -p > .kiro/specs/home-grid-visual-polish/snapshots/after_perf_overlay.png`.
  - Наблюдаемое: оба файла существуют на диске; визуально after_clean показывает fade-edge справа и больше воздуха под именами каналов; after_perf_overlay показывает значения GPU frame time.
  - _Requirements: 6.1, 6.2_
  - _Depends: 3.3_
  - _Boundary: ReferenceDevice_

- [ ] 4.2 Сравнить baseline и after
  - Открыть baseline_clean.png и after_clean.png рядом — визуально оценить fade-edge и bottom padding.
  - Открыть baseline_perf_overlay.png и after_perf_overlay.png — записать в комментарий numeric values: было `avg 20.3 ms / max 34.2 ms`, стало `avg X / max Y`.
  - Если avg ≤ 16.7 мс и max ≤ 25 мс — Req 4.1, 4.2 PASS.
  - Если не достигнуто — Req 4.3: записать остаточный долг в `snapshots/residual_perf_gap.md`, явно зафиксировать что он out of scope для этого спека.
  - Наблюдаемое: либо метрики PASS, либо есть `residual_perf_gap.md` с конкретным delta.
  - _Requirements: 4.1, 4.2, 4.3, 6.3_
  - _Depends: 4.1_
  - _Boundary: ReferenceDevice_

- [ ] 4.3 Idle perf check
  - На TV главный экран в покое 30 секунд (не нажимать ничего).
  - В performance overlay убедиться, что оба графика плоские в idle (нет постоянных перерисовок).
  - Наблюдаемое: подтверждение оператором.
  - _Requirements: 4.4_
  - _Depends: 4.1_
  - _Boundary: ReferenceDevice_

## Implementation Notes

- **Task 2.2 forced extraction**: Pre-commit hook `check-file-size` (max 600 lines) blocked the original commit because cinema_card.dart grew to 619 lines. Resolved by extracting poster sub-tree into `_card_poster.dart` as `CardPoster` StatefulWidget. Class name is public (`CardPoster`) because Dart privacy is library-scoped — `_`-prefixed class can't be imported across files; file itself is `_`-prefixed by project convention. Pattern matches existing `_grid_tokens.dart` → `class GridTokens`. Future tasks touching cinema_card.dart should keep its size headroom in mind (currently 539/600).
