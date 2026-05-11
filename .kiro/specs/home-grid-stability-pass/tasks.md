# Implementation Plan — home-grid-stability-pass

## Phase 1 — Foundation: токены

- [ ] 1. Расширить GridTokens новыми константами v2 (stability pass)

- [x] 1.1 Добавить новые константы геометрии и анимации в GridTokens
  - Расширить блок `class GridTokens` секцией `// --- v2 (stability pass) ---`.
  - Заменить значение существующей `focusedScale` с `1.02` на `1.01`,
    обновить dartdoc-комментарий: «Снижен в stability pass; визуально
    на пиксельной сетке неотличим от 1.0».
  - Добавить `static const int pinnedSlotIdx = 1` с dartdoc, описывающим
    Netflix-style выравнивание во второй слот.
  - Добавить `static const double cardHeightDp = 720` с dartdoc,
    указывающим целевое cardH/cardW ∈ [1.6, 1.7] на reference TV resolution.
  - Добавить `static const double metadataReservedHeightDp = 46` с
    dartdoc, объясняющим инвариант фиксированной высоты metadata-зоны.
  - Добавить `static const double unfocusedNeighbourOpacity = 0.92` с
    dartdoc, объясняющим scope (только нефокусные плитки активного ряда).
  - Observable completion: команда `flutter analyze` на `megav_iptv/`
    проходит без ошибок; `import` из `cinema_row.dart` уже видит новые
    константы через статический доступ; запуск `flutter test
    test/features/home/editorial/pick_columns_regression_test.dart`
    остаётся зелёным (sanity: pickColumns не сломан).
  - _Requirements: 1.5, 2.1, 2.3, 3.6, 4.4_
  - _Boundary: GridTokens_

## Phase 2 — Core: применение токенов в widgets

- [ ] 2. Закрепить Pinned-Slot Invariant в CinemaRow

- [x] 2.1 Заменить локальную magic-number `pinnedSlotIdx = 1` на токен
  - В `_scrollFocusedTileToLeadingEdge` (`cinema_row.dart`, метод около
    строки 244) удалить локальную `const pinnedSlotIdx = 1`.
  - Заменить использование на `GridTokens.pinnedSlotIdx` (импорт уже
    есть).
  - Observable completion: `grep -n "const pinnedSlotIdx" megav_iptv/lib/`
    возвращает пусто; ручной запуск `CinematicHomeScreen` показывает
    тот же pinned-slot behaviour (qualitative); все widget-тесты
    компилируются.
  - _Requirements: 1.5, 4.4_
  - _Boundary: CinemaRow_

- [x] 2.2 Добавить dartdoc «Pinned-Slot Invariant» на класс CinemaRow
  - Над `class CinemaRow extends StatefulWidget` добавить dartdoc-блок,
    описывающий Pinned-Slot Invariant: формальное определение
    стабильности screen-space позиции фокусной плитки, leading-edge clamp
    (scrollOffset → 0), trailing-edge clamp (scrollOffset → maxScrollExtent),
    tolerance ±1.0 dp, ссылка на verifiable test
    `cinema_row_pinned_slot_test.dart`.
  - Сформулировать контракт строго так, как в design.md → Components →
    CinemaRow → Implementation Notes.
  - Observable completion: `grep -n "Pinned-Slot Invariant" megav_iptv/lib/features/home/widgets/cinema_row.dart`
    возвращает блок dartdoc; `dart doc` (если запускается локально) не
    выдаёт ошибок парсинга на этот файл.
  - _Requirements: 1.6_
  - _Boundary: CinemaRow_

- [ ] 3. Применить новую высоту плитки в CinemaRow

- [ ] 3.1 Заменить default availableHeight 450.h на GridTokens.cardHeightDp.h
  - В `CinemaRow.build`, строка `AnimatedContainer(height: widget.availableHeight ?? 450.h)`
    — заменить literal `450.h` на `GridTokens.cardHeightDp.h`.
  - Сохранить override через `widget.availableHeight` (текущие
    потребители всё ещё могут переопределять).
  - Observable completion: `grep -n "450\\.h" megav_iptv/lib/features/home/widgets/cinema_row.dart`
    остаётся ровно с одним вхождением (loading placeholder Column
    height — будет заменено в 3.2), а строка с `AnimatedContainer.height`
    использует токен; визуальный smoke на 1920×1080 показывает
    увеличенную высоту ряда.
  - _Requirements: 3.1, 3.2, 4.4_
  - _Boundary: CinemaRow_

- [ ] 3.2 Привести loading placeholder к согласованной геометрии
  - В `_CinemaRowLoadingPlaceholder.build` заменить
    `SizedBox(height: 450.h, ...)` на `SizedBox(height: GridTokens.cardHeightDp.h, ...)`.
  - Заменить `height: 336.h` у плиток-силуэтов на согласованное значение,
    равное полезной высоте плитки (cardHeightDp.h минус 60.h заголовка
    минус padding) ИЛИ упростить: использовать тот же
    `GridTokens.cardHeightDp.h` минус заголовочный slot (60.h) минус
    fromLTRB padding (40.h). Точное число рассчитать так, чтобы при
    переходе loading→loaded не было layout jump.
  - Observable completion: `grep -n "336\\.h\\|450\\.h" megav_iptv/lib/features/home/widgets/cinema_row.dart`
    возвращает пусто (все числа заменены); manual visual check: при
    запуске на холодном кэше виден placeholder той же высоты что и
    последующие загруженные ряды.
  - _Requirements: 3.2, 4.5_
  - _Boundary: CinemaRow_
  - _Depends: 3.1_

- [ ] 4. (P) Применить fixed-height metadata wrapper в CinemaCard

- [ ] 4.1 (P) Обернуть compact-overlay channel-line в SizedBox с metadataReservedHeightDp
  - В `_buildCompactOverlay` (`cinema_card.dart`, около строки 194),
    вместо `Padding(EdgeInsets.only(bottom: 6.h), child: _buildBottomChannelLine())`
    использовать
    `SizedBox(height: GridTokens.metadataReservedHeightDp.h,
    child: Align(alignment: Alignment.bottomLeft,
    child: Padding(padding: EdgeInsets.only(bottom: 6.h),
    child: _buildBottomChannelLine())))`.
  - Сохранить существующий контракт: `Spacer()` сверху, channel-line
    внизу. `SizedBox` фиксирует общую высоту нижней зоны.
  - Observable completion: при `flutter run -d <tv>` или widget-тест:
    высота нижней metadata-зоны на фокусной и нефокусной плитках
    идентична (визуальный side-by-side check); `_buildBottomChannelLine`
    отрабатывает без overflow.
  - _Requirements: 3.3, 3.4, 3.5, 3.6_
  - _Boundary: CinemaCard_
  - _Depends: 1.1_

- [ ] 4.2 Синхронизировать резерв в full-overlay'е
  - В `_buildFullOverlay` (`cinema_card.dart`, около строки 275),
    заменить `SizedBox(height: 22.h + 4.h)` (последняя строка Column)
    на `SizedBox(height: GridTokens.metadataReservedHeightDp.h)`.
  - Observable completion: full-overlay в focused-состоянии не залезает
    на compact-overlay channel-line; визуальный baseline нижнего края
    плитки стабилен между focused и unfocused. `grep -n "22\\.h \\+ 4\\.h" megav_iptv/lib/features/home/widgets/cinema_card.dart`
    возвращает пусто.
  - _Requirements: 3.3, 3.4, 3.6_
  - _Boundary: CinemaCard_
  - _Depends: 4.1_

- [ ] 5. Опциональный neighbour-opacity wrap в CinemaRow

- [ ] 5.1 Обернуть нефокусные плитки активного ряда в Opacity
  - В `CinemaRow.itemBuilder` (`cinema_row.dart`, около строки 382),
    в самом внешнем визуальном wrapper'е (внутри `Padding(EdgeInsets.only(right: ...))`)
    добавить условную обёртку:
    `Opacity(opacity: (_focusedIndex >= 0 && _focusedIndex != index) ? GridTokens.unfocusedNeighbourOpacity : 1.0, child: ...)`.
  - Условие применения: ряд активен (`isRowFocused`, т. е.
    `_focusedIndex >= 0`) И текущая плитка не фокусная.
  - НЕ модифицировать `Visibility`/`AnimatedOpacity` wrapper для
    full-overlay'я в `CinemaCard` (это контракт `home-grid-visual-polish`).
  - Observable completion: при focus traversal плитки рядом с фокусной
    визуально слегка приглушены; нефокусные ряды (где
    `_focusedIndex == -1`) отображаются с opacity 1.0.
  - _Requirements: 2.2, 2.5, 6.1, 6.3, 6.4_
  - _Boundary: CinemaRow_

## Phase 3 — Integration: согласование с потребителями CinemaRow

- [ ] 6. Проверить обоих потребителей CinemaRow (CinematicHomeScreen + legacy HomeScreen)

- [ ] 6.1 Прогнать smoke-тесты обоих главных экранов
  - Запустить `flutter test test/features/home/` целиком на ветке
    спека.
  - Зафиксировать список упавших тестов; разделить на две группы:
    (a) числовые ожидания, ломающиеся от новой `cardHeightDp` /
    `metadataReservedHeightDp` / `focusedScale`, и (b) семантические
    регрессии (необъяснимые с точки зрения design.md).
  - Группа (a) — обновляется в 6.2; группа (b) — означает ошибку
    в одной из предыдущих задач, нужно вернуться и исправить.
  - Observable completion: список упавших тестов оформлен в commit
    message либо PR-описании; для каждого теста указан reason
    (a/b) с цитатой ожидаемого vs фактического значения.
  - _Requirements: 4.1, 4.2, 4.3_
  - _Boundary: home tests_
  - _Depends: 3.1, 3.2, 4.1, 4.2, 5.1_

- [ ] 6.2 Обновить числовые ожидания в существующих widget-тестах
  - Для каждого теста из группы (a) из 6.1: заменить literal
    числовые значения (height, scale, metadata height) на новые
    значения из `GridTokens.cardHeightDp` / `metadataReservedHeightDp` /
    `focusedScale`, СОХРАНИВ semantic intent теста.
  - Запрещено: ослаблять assertion (например, заменять `expect(rect.height,
    closeTo(450, 1))` на бесконечный tolerance). Допустимо: заменять
    literal на референс токена через import.
  - НЕ модифицировать тесты `pick_columns_regression_test.dart` (это
    контракт `home-grid-optimization`).
  - Observable completion: `flutter test test/features/home/` зелёный;
    git diff показывает только числовые правки в expectations
    (никаких изменений в test logic).
  - _Requirements: 4.3_
  - _Boundary: home tests_
  - _Depends: 6.1_

## Phase 4 — Validation: invariant test + manual TV smoke

- [ ] 7. Добавить Pinned-Slot Invariant widget-тест

- [ ] 7.1 Создать тестовый файл и фикстуру
  - Создать
    `megav_iptv/test/features/home/widgets/cinema_row_pinned_slot_test.dart`.
  - Определить helper-функцию `List<NowPlayingItem> _makeFixture(int n)`,
    генерирующую `n` элементов с уникальными `channelId` (1..n) и
    стабильными именами/программами.
  - В `setUp`: задать `MediaQueryData(size: Size(1920, 1080))` для всех
    тестов (через `MediaQuery` wrapper или `ScreenUtilInit`).
  - Observable completion: файл создан, `flutter test
    test/features/home/widgets/cinema_row_pinned_slot_test.dart` запускается
    (хотя пока без assertions — это базовая инфраструктура).
  - _Requirements: 5.1_
  - _Boundary: cinema_row_pinned_slot_test_

- [ ] 7.2 Реализовать middle-traversal assertion (Δ screen-space ≤ 1.0 dp)
  - Тест-кейс: «focus stays in slot 1 while D-pad sweeps tiles 2..6».
  - Шаги:
    1. `tester.pumpWidget(CinemaRow(items: _makeFixture(10), ...))`
       внутри `MaterialApp` + `ScreenUtilInit`.
    2. Получить `FocusNode` плитки index=2 через `tester.element(...).child(...)` или
       через `Focus.of(context)` finder; вызвать `requestFocus()`.
    3. `await tester.pumpAndSettle(const Duration(seconds: 1))`.
    4. Замерить
       `tester.renderObject<RenderBox>(find.byKey(ValueKey('card_${id}_$index'))).localToGlobal(Offset.zero)`
       — сохранить в `Offset prevPos`.
    5. Цикл 5 раз: `tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
       await tester.pumpAndSettle(...)`; замерить позицию новой
       фокусной плитки; assert `(prevPos - newPos).distance <= 1.0`.
  - Failure message: «Focused tile screen-space drifted by
    ${d.toStringAsFixed(2)} dp between index $i → ${i+1} (tolerance: 1.0)».
  - Observable completion: тест компилируется и проходит; при ручном
    breaking change (например, замена `pinnedSlotIdx = 1` на `2`) тест
    падает с конкретным diagnostic-сообщением.
  - _Requirements: 1.1, 1.2, 5.1, 5.2, 5.5_
  - _Boundary: cinema_row_pinned_slot_test_
  - _Depends: 7.1_

- [ ] 7.3 Реализовать leading-edge clamp assertion
  - Тест-кейс: «focused tile 0 → scroll offset stays at 0».
  - Шаги: запросить фокус на плитке index=0, `pumpAndSettle`, получить
    `ScrollController.offset` через `Scrollable.of(context).position.pixels`
    либо через `tester.widget<ListView>(find.byType(ListView).first).controller`,
    assert `== 0`.
  - Failure message: «Leading-edge clamp violated: scrollOffset =
    ${offset.toStringAsFixed(2)} (expected 0)».
  - Observable completion: тест проходит; при ручном breaking change
    (удалить `clamp(0, max)` в `_scrollFocusedTileToLeadingEdge`) тест
    падает с конкретным diagnostic.
  - _Requirements: 1.3, 5.3, 5.5_
  - _Boundary: cinema_row_pinned_slot_test_
  - _Depends: 7.1_

- [ ] 7.4 Реализовать trailing-edge clamp assertion
  - Тест-кейс: «focused tile N-1 → scroll offset = maxScrollExtent».
  - Шаги: запросить фокус на последней плитке, `pumpAndSettle`,
    получить `ScrollController.offset` и `maxScrollExtent`,
    assert `offset == maxScrollExtent` (с tolerance 1.0).
  - Failure message: «Trailing-edge clamp violated: scrollOffset =
    $offset, maxScrollExtent = $max (expected equal within 1.0 dp)».
  - Observable completion: тест проходит; при ручном breaking change
    (убрать верхний `clamp` upper bound) тест падает.
  - _Requirements: 1.4, 5.4, 5.5_
  - _Boundary: cinema_row_pinned_slot_test_
  - _Depends: 7.1_

- [ ] 8. Финальная валидация на TV-target

- [ ] 8.1 Прогнать full test suite (`flutter test`)
  - Запустить `flutter test` на корне `megav_iptv/`.
  - Все тесты включая новый `cinema_row_pinned_slot_test.dart` зелёные.
  - Никаких новых warning'ов от `flutter analyze` на изменённые файлы.
  - Observable completion: stdout `flutter test` содержит `All tests
    passed!` и счётчик ≥ 30 (исходный + новые тест-кейсы); `flutter
    analyze` возвращает 0 issues для `megav_iptv/lib/features/home/widgets/`
    и `megav_iptv/test/features/home/widgets/`.
  - _Requirements: 4.3, 5.1, 5.2, 5.3, 5.4, 5.5_
  - _Boundary: full test suite_
  - _Depends: 6.2, 7.2, 7.3, 7.4_

- [ ] 8.2 Manual TV smoke на rtd2851a (визуальная валидация)
  - На референсном TV-боксе rtd2851a (или эквивалентном профиле):
    1. Запустить `flutter run --profile -d <tv-box>`.
    2. Войти в CinematicHomeScreen, дождаться загрузки рядов.
    3. D-pad ↓ → переход с hero на первую полосу.
    4. D-pad → 5-10 раз внутри одной полосы. Визуально проверить:
       - фокусная плитка визуально не двигается (Req 1.1);
       - соседние плитки не «толкаются» (Req 2.1, 2.4);
       - aspect плитки — постерный (Req 3.1);
       - baseline нижней строки стабилен между focused/unfocused
         (Req 3.3, 3.4).
    5. D-pad → до конца полосы. Визуально проверить, что плитка-N-1
       выровнена к правому краю (Req 1.4).
    6. D-pad ← обратно. Визуально проверить, что плитка-0 выровнена к
       левому краю (Req 1.3).
    7. Проверить вторую полосу — повторить пункты 4-6 (Req 4.1).
  - При обнаружении регрессии вернуться к соответствующей предыдущей
    задаче, не патчить «на лету».
  - Observable completion: чек-лист 1-7 пройден глазами; никаких jank
    или layout jumps в течение 30 сек idle/scroll цикла.
  - _Requirements: 1.1, 1.3, 1.4, 2.1, 2.4, 3.1, 3.3, 3.4, 4.1, 6.2_
  - _Boundary: manual TV smoke_
  - _Depends: 8.1_

- [ ] 8.3 Manual smoke legacy HomeScreen
  - Через router перейти на `/home` (legacy HomeScreen).
  - Повторить D-pad traversal проверку из 8.2 (пункт 4) — должен
    работать так же, как cinematic (Req 4.2).
  - Observable completion: legacy HomeScreen рендерит ряды с новыми
    плитками без overflow и focus-trap; D-pad traversal стабильный.
  - _Requirements: 4.2_
  - _Boundary: manual TV smoke_
  - _Depends: 8.1_
