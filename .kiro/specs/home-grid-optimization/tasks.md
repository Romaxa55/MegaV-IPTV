# Implementation Plan

> Спек: `home-grid-optimization`. См. `requirements.md` (11 требований) и `design.md` (компоненты `_grid_tokens.dart`, `CinemaRow`, `CinemaCard`, `_CinemaRowLoadingPlaceholder`).
>
> Принципы: foundation → core → integration → validation. Major 2 и Major 3 трогают разные файлы и могут идти параллельно после Major 1.

---

## 1. Foundation: layout-токены и адаптивная функция колонок

- [x] 1.1 Создать приватный файл с pure-константами и функцией выбора числа колонок
  - Завести новый файл `lib/features/home/widgets/_grid_tokens.dart` без runtime-зависимостей (без BuildContext, без Riverpod, без screenutil).
  - Реализовать `class GridTokens` со статическими `const` полями: `focusAnimation = Duration(milliseconds: 150)`, `scrollAnimation = Duration(milliseconds: 250)`, `overlayFade = Duration(milliseconds: 150)`, `focusStableDebounce = Duration(milliseconds: 400)`, `focusCurve = Curves.easeOutCubic`, `scrollCurve = Curves.fastOutSlowIn`, `overlayCurve = Curves.easeOut`, `focusedScale = 1.08`, `focusBorderWidth = 3.0`, `gapDp = 16`, `horizontalPaddingDp = 48`, `rowVerticalGapDp = 20`.
  - Реализовать функцию `int pickColumns(double screenW)`: при `screenW < 1280` возвращает 3; при `1280 ≤ screenW < 2560` возвращает 4; при `screenW ≥ 2560` возвращает 5.
  - Наблюдаемое: файл существует, импортируется через `import 'package:megav_iptv/features/home/widgets/_grid_tokens.dart';` без ошибок; `dart analyze` чистый.
  - _Requirements: 1.1, 1.2, 1.3, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_
  - _Boundary: GridTokens_

---

## 2. Core: рефакторинг визуала карточки

- [x] 2.1 Кэшировать псевдо-данные через `late final` поля
  - В `_CinemaCardState` (`lib/features/home/widgets/cinema_card.dart`) объявить три `late final` поля: `_ratingCached`, `_ageRatingCached`, `_genreEmojiCached`. Инициализировать через приватные методы, читающие `widget.item`.
  - Удалить вызовы `_pseudoRating()`, `_pseudoAgeRating()`, `_genreEmoji(...)` из `build`/`_buildOverlay`/etc; вместо них читать кэшированные поля.
  - Наблюдаемое: после первого `build` карточки повторные ребилды (например, на смену `isFocused`) не вызывают `String.hashCode` от `widget.item.program?.title`. Подтверждается отсутствием упомянутых вызовов в горячем пути `build`.
  - _Requirements: 9.4_
  - _Depends: 1.1_
  - _Boundary: CinemaCard_

- [x] 2.2 Заменить `boxShadow` blur=50 на лёгкий вариант, не зависящий от `effectiveLowPowerUi`
  - В `cinema_card.dart` в `BoxDecoration` карточки: при `widget.isFocused == true` использовать **без размытой тени** (или `BoxShadow.blurRadius` ≤ 12); сделать рамку толще/ярче (`Border.all(width: GridTokens.focusBorderWidth, color: AppColors.primary)`) для визуального компенсаторного выделения.
  - Удалить ветку «`isLowPower ? blur=8 : blur=50`», оставить единый дешёвый стиль для всех устройств.
  - Наблюдаемое: на референсном TV сфокусированная плитка не «прорисовывается» с заметной задержкой при многократной смене фокуса; визуально активная плитка выделяется рамкой.
  - _Requirements: 3.3, 3.5, 9.1, 9.4_
  - _Depends: 1.1_
  - _Boundary: CinemaCard_

- [x] 2.3 Убрать `AnimatedContainer` для ширины; оставить только border/decoration анимацию
  - В `cinema_card.dart` `cardWidth` и `cardHeight` сделать обязательными (non-nullable) параметрами; удалить параметры `expanded` и `posterWidth` из публичного API виджета.
  - `AnimatedContainer.width` принимает `widget.cardWidth` без подмены при `isExpanded`; при смене `isFocused` width не анимируется (потому что не меняется).
  - `AnimatedScale.duration` и `AnimatedContainer.duration` равны `GridTokens.focusAnimation` (150 мс), curve = `GridTokens.focusCurve`.
  - Наблюдаемое: в widget tree DevTools при перемещении фокуса ширина плитки в layout-явлении остаётся постоянной; никаких сдвигов соседних плиток.
  - _Requirements: 1.4, 1.5, 3.1, 3.2, 3.4, 3.6, 7.1, 7.2_
  - _Depends: 1.1, 2.2_
  - _Boundary: CinemaCard_

- [x] 2.4 Разделить overlay на compact (всегда) и full (под `AnimatedOpacity`)
  - В `cinema_card.dart` создать два метода: `_buildCompactOverlay()` — рендерит `Positioned.fill` с нижней полоской (постер виден, компактная полоска занимает ≤ 25% высоты), внутри которой `_buildChannelIcon()`, `widget.item.channelName` (одной строкой) и LIVE-индикатор `_liveBadge` если `widget.item.program?.isNow == true`. `_buildFullOverlay()` — содержит всё, что сейчас в `_buildOverlay` **без** имени канала и без LIVE-бейджа в верхнем углу (избегаем дублирования с compact).
  - В `_buildCardContent` после `_buildPoster()` и `_buildGradient()` рендерить: `_buildCompactOverlay()`, затем `AnimatedOpacity(opacity: widget.isFocused ? 1 : 0, duration: GridTokens.overlayFade, curve: GridTokens.overlayCurve, child: _buildFullOverlay())`.
  - Сохранить существующие helper'ы (`_ratingBadge`, `_buildAgeAndGenre`, `_buildProgressSection`, `_buildBottomInfo` в его части про название программы и год). Не дублировать имя канала в full overlay (оно уже в compact).
  - Наблюдаемое: на неактивной плитке в Widget Inspector отсутствуют виджеты программы (заголовок, рейтинг, возраст, эмодзи); они появляются с fade-in 150 мс при фокусе. Имя канала видимо всегда и не «прыгает» между состояниями.
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2, 6.3, 6.4, 7.4, 7.6_
  - _Depends: 1.1, 2.3_
  - _Boundary: CinemaCard_

- [x] 2.5 Учесть `FastScrollDetector`: scale обнуляется при fast-scroll, debounce от него независим
  - В `cinema_card.dart` сохранить ветку: `final isFastScroll = context.isFastScrolling; final animationDuration = isFastScroll ? Duration.zero : GridTokens.focusAnimation;` для `AnimatedScale`.
  - Опционально: при fast-scroll скрывать full overlay мгновенно (чтобы fade-out не «отставал» от прокрутки). `AnimatedOpacity.duration` остаётся `GridTokens.overlayFade` — это достаточно быстро.
  - Наблюдаемое: при удержании стрелки на пульте scale-эффекты исчезают, плитки «не моргают»; FastScrollDetector в логах подтверждает state.
  - _Requirements: 4.4, 4.5_
  - _Depends: 2.3_
  - _Boundary: CinemaCard_

---

## 3. Core: рефакторинг модели ряда

- [x] 3.1 (P) Заменить дуальную ширину на фиксированную; вычислять её через `pickColumns` и токены
  - В `_CinemaRowState` (`lib/features/home/widgets/cinema_row.dart`) удалить методы и поля, относящиеся к `narrowW`/`fullW`/`_cardSizes`/`_lastActiveCol`/`_hoveredCol`. Оставить один `_focusedIndex` (int, начальное `-1`).
  - Реализовать локальную функцию вычисления: `double cardW = (screenW - 2 * GridTokens.horizontalPaddingDp.w - (n - 1) * GridTokens.gapDp.w) / n;` где `n = pickColumns(screenW)`.
  - В `ListView.builder.itemBuilder` всегда передавать в `CinemaCard` `cardWidth: cardW`, `cardHeight: rowH` (как сейчас).
  - Наблюдаемое: при ручном изменении `screenW` (через эмулятор/resize окна) число видимых плиток меняется по порогам 1280/2560; левый край первой плитки лежит на `GridTokens.horizontalPaddingDp.w` от края экрана; ширины всех плиток равны.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 3.6_
  - _Depends: 1.1_
  - _Boundary: CinemaRow_

- [x] 3.2 Упростить `_scrollFocusedCardToLeadingEdge` под фиксированную ширину
  - В `cinema_row.dart` метод вычисляет `offset = index * (cardW + GridTokens.gapDp.w)`, clamp по `position.maxScrollExtent`, `_scrollController.animateTo(offset, duration: GridTokens.scrollAnimation, curve: GridTokens.scrollCurve)`.
  - Удалить старую логику накопления `narrowW + gap` в цикле `for (var i = 0; i < index; i++)`.
  - Сохранить вызов из `Focus.onFocusChange` через `addPostFrameCallback` (как сейчас).
  - Наблюдаемое: при программной установке фокуса на плитку с индексом N через 250 мс `_scrollController.offset` равен `N * (cardW + gap)` с допуском < 1px (или равен `maxScrollExtent` если N — последняя). При переходе фокуса назад (на меньший index, который уже виден ≤ leading edge) метод не двигает скролл (offset не уменьшается ниже текущего, если текущий уже ≤ требуемого).
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 7.3, 7.5_
  - _Depends: 1.1, 3.1_
  - _Boundary: CinemaRow_

- [x] 3.3 Реализовать debounce 400 мс перед dispatch'ем `onItemFocus(item)`
  - В `_CinemaRowState` объявить `Timer? _focusStableTimer`. Реализовать `_scheduleStableFocus(int index)`: отменить предыдущий timer, запустить новый на `GridTokens.focusStableDebounce`; по истечении вызвать `widget.onItemFocus?.call(widget.items[index])` если `_focusedIndex == index && mounted`.
  - В `Focus.onFocusChange(true)`: сразу `setState(_focusedIndex = index)` (это даёт мгновенный scale в карточке — Req 4.3) **и** `_scheduleStableFocus(index)`. **Не** вызывать `widget.onItemFocus?.call(item)` сразу.
  - В `Focus.onFocusChange(false)`: если `_focusedIndex == index`, отменить `_focusStableTimer`, `setState(_focusedIndex = -1)`, синхронно вызвать `widget.onItemFocus?.call(null)` (поведение clear не debounced).
  - В `dispose`: отменить `_focusStableTimer`.
  - Сохранить триггер пагинации (`if (widget.onLoadMore != null && index >= widget.items.length - 3) widget.onLoadMore!();`) синхронно в `onFocusChange(true)` — пагинация debounce'у не подлежит.
  - Наблюдаемое: при быстром движении пультом по 5 плиткам (со скоростью < 400 мс/плитка) `widget.onItemFocus` вызывается с **последней** остановленной плиткой, не с пролётными; на пролетающих плитках full overlay не успевает раскрыться (потому что у каждой `isFocused` менее 400 мс).
  - _Requirements: 4.1, 4.2, 4.3, 10.5_
  - _Depends: 3.1_
  - _Boundary: CinemaRow_

- [x] 3.4 Слить mouse-hover и D-pad focus в один источник
  - В `cinema_row.dart` `MouseRegion.onEnter` для плитки больше не делает свой `setState(_hoveredCol = index)`; вместо этого вызывает `Focus.of(context).requestFocus()` (или хранит `FocusNode` per item и зовёт `requestFocus()` напрямую). Это запускает обычный focus-pipeline, и debounce/scale работает одинаково.
  - `MouseRegion.onExit` — оставить пустым или лёгкий guard; clear фокуса произойдёт когда фокус уйдёт на другую плитку или из ряда.
  - Удалить поле `_hoveredCol` и логику его участия в `_activeCol`.
  - Наблюдаемое: при наведении мышью на плитку (если в TV есть мышь/HDMI-донгл) поведение совпадает с фокусом по пульту: scale через 150 мс, full overlay через 400 мс; никаких отдельных hover-состояний.
  - _Requirements: 3.1, 3.6, 4.1_
  - _Depends: 3.3_
  - _Boundary: CinemaRow_

- [x] 3.5 Сохранить шапку, шевроны, индикатор «Фильмы в эфире», подсветку активного ряда
  - В `cinema_row.dart` шапку ряда (заголовок, индикатор-точка для `Фильмы в эфире`, счётчик количества элементов, шевроны влево/вправо) **оставить как есть**; шевроны вызывают `_scrollBy(±600.w)` с `duration: GridTokens.scrollAnimation, curve: GridTokens.scrollCurve` (унифицировать с токенами вместо текущих 300 мс/easeOut).
  - Подсветка заголовка ряда (`_isFocusedRow` → opacity 0.95 vs 0.60) сохраняется и теперь пересчитывается через `_focusedIndex >= 0`.
  - Сохранить `wrapAround` параметр в виджете и его проброс (даже если внутри ряда поведение не меняется в этом спеке — флаг продолжает существовать для совместимости с `live-movies`).
  - Наблюдаемое: визуально шапка ряда совпадает с текущей; клик мышью по шеврону прокручивает ряд на ~600.w пикселей за 250 мс с deceleration-кривой; заголовок активного ряда выделяется белым, заголовки неактивных приглушены.
  - _Requirements: 8.1, 8.3, 8.4, 8.5_
  - _Depends: 3.1, 1.1_
  - _Boundary: CinemaRow_

- [x] 3.6 Сохранить keyEvent-обработку: SELECT/ENTER, конец ряда, ESC/BACK
  - В `cinema_row.dart` `Focus.onKeyEvent` обработка `LogicalKeyboardKey.select`/`enter`/`gameButtonA`/`numpadEnter` → вызов `widget.onItemTap(items[index])` и `KeyEventResult.handled` (как сейчас).
  - Условие `index == widget.items.length - 1 && key == arrowRight` → `KeyEventResult.handled` (сохраняется поведение «не выходить за край»).
  - ESC/BACK → `KeyEventResult.ignored` (родитель обрабатывает; уже работает в `home_screen.dart`).
  - Наблюдаемое: на последней плитке стрелка вправо не вызывает визуальных артефактов, не уводит фокус и не запускает «зацикленный» скролл (в не-cyclic рядах); SELECT открывает плеер для канала; ESC из ряда останавливает preview в Hero (поведение `home_screen.dart`).
  - _Requirements: 2.5, 10.1, 10.2, 10.4_
  - _Depends: 3.1_
  - _Boundary: CinemaRow_

- [x] 3.7 Обновить `_CinemaRowLoadingPlaceholder` под новую модель ширины
  - В `cinema_row.dart` placeholder: вместо фиксированных 7 силуэтов с `width: 224.w` использовать `n = pickColumns(MediaQuery.sizeOf(context).width)` и `cardW = _cardWidthFor(screenW)`.
  - Между силуэтами — `GridTokens.gapDp.w` (вместо текущего `right: 24.w`).
  - Высота placeholder остаётся `450.h` (Req 11.1: same vertical height as a loaded row).
  - Наблюдаемое: при загрузке ряда видимое число силуэтов совпадает с числом плиток после загрузки; никакого сдвига layout'а при появлении реальных данных.
  - _Requirements: 11.1, 11.2, 11.5_
  - _Depends: 1.1, 3.1_
  - _Boundary: CinemaRow_

---

## 4. Integration: согласовать с `home_screen.dart`

- [x] 4.1 Адаптировать `home_screen.dart` к семантическому изменению `onItemFocus`
  - В `lib/features/home/home_screen.dart` метод `_onHoveredItemChanged(NowPlayingItem? item)` сейчас имеет собственный `_hoveredClearDebounce` (200 мс) для clear; этот debounce **сохраняется** (он защищает Hero от моргания при null-промежутке между плитками).
  - **Не дублировать** debounce 400 мс в `home_screen.dart`: это уже сделано на стороне `CinemaRow.3.3`. Хвостовой `_previewTimer` (7 секунд до preview-видео) сохраняется без изменений.
  - Если в `home_screen.dart` есть assumptions о мгновенности `onItemFocus(item)` — снять их (никакой логики, требующей синхронности, не должно остаться).
  - Наблюдаемое: при удержании стрелки в ряду Hero обновляется через ~400 мс после остановки на плитке; preview-видео по-прежнему запускается через 7 секунд после стабильного hover; null-clear (уход фокуса из ряда) обрабатывается за ~200 мс как раньше.
  - _Requirements: 4.1, 4.2, 10.5_
  - _Depends: 3.3_
  - _Boundary: HomeScreen_

- [x] 4.2 Удалить из `home_screen.dart` параметры, перешедшие в `_grid_tokens.dart` (если использовались)
  - Просканировать `home_screen.dart` на любые magic numbers, относящиеся к ряду (например, отступы между рядами в `Padding(bottom: 20.h)`); если они логически принадлежат grid-системе — заменить на `GridTokens.rowVerticalGapDp.h`.
  - Импорт `_grid_tokens.dart` не требуется в `home_screen.dart`, если magic numbers остаются специфичными для shell-layout (между рядами и Hero) — оставить локальными.
  - Наблюдаемое: визуально вертикальный gap между рядами совпадает с текущим (или 20.h, или GridTokens.rowVerticalGapDp.h — оба ≈ 20).
  - _Requirements: 8.5_
  - _Depends: 4.1_
  - _Boundary: HomeScreen_

---

## 5. Validation: автотесты и ручная приёмка

- [ ] 5.1 (P) Юнит-тест функции `pickColumns` на граничных значениях
  - Создать `test/features/home/widgets/grid_tokens_test.dart` с testами: `pickColumns(0)` → 3, `pickColumns(800)` → 3, `pickColumns(1279)` → 3, `pickColumns(1280)` → 4, `pickColumns(1920)` → 4, `pickColumns(2559)` → 4, `pickColumns(2560)` → 5, `pickColumns(3840)` → 5.
  - Дополнительный тест на сумму: при `n = pickColumns(W)` сумма `n*cardW + (n-1)*gap + 2*pad ≈ W` (с допуском на округления при делении).
  - Запуск: `flutter test test/features/home/widgets/grid_tokens_test.dart`.
  - Наблюдаемое: все assertions зелёные; команда `flutter test` возвращает exit code 0.
  - _Requirements: 1.1, 1.2, 1.3, 1.4_
  - _Depends: 1.1_
  - _Boundary: GridTokens_

- [ ] 5.2 Widget-тест: компактный/полный overlay в `CinemaCard`
  - Создать `test/features/home/widgets/cinema_card_overlay_test.dart`. Сценарии: (1) `pumpWidget(CinemaCard(isFocused: false, ...))` → `find.byKey(ValueKey('rating-badge'))` не находится; имя канала находится. (2) `pumpWidget(CinemaCard(isFocused: true, ...))` → после `pump(Duration(milliseconds: 200))` (запас на fade) rating-badge найден; имя канала найдено.
  - Для упрощения теста добавить `Key`-ваня в ключевых виджетах overlay: `Key('rating-badge')`, `Key('age-rating')`, `Key('genre-emoji')`, `Key('progress-section')`, `Key('programme-title')`. Эти ключи добавляются в task 2.4 как часть рефакторинга.
  - Наблюдаемое: тест зелёный; покрывает Req 5.3 и 6.1.
  - _Requirements: 5.3, 6.1, 6.2, 6.3_
  - _Depends: 2.4_
  - _Boundary: CinemaCard_

- [ ] 5.3 Widget-тест: debounce 400 мс на `onItemFocus`
  - Создать `test/features/home/widgets/cinema_row_debounce_test.dart`. Сценарий: смонтировать `CinemaRow` с тремя элементами и `onItemFocus` mock-callback'ом. Программно установить фокус на index 0, через `pump(50ms)` уйти на index 1, через `pump(50ms)` уйти из ряда. Проверить, что `onItemFocus(non-null)` ни разу не вызвался; `onItemFocus(null)` вызвался один раз.
  - Второй сценарий: установить фокус на index 0, `pump(500ms)`. Проверить, что `onItemFocus(items[0])` вызвался ровно один раз.
  - Наблюдаемое: оба теста зелёные.
  - _Requirements: 4.1, 4.2_
  - _Depends: 3.3_
  - _Boundary: CinemaRow_

- [ ] 5.4 Widget-тест: левое выравнивание скролла
  - Создать `test/features/home/widgets/cinema_row_scroll_test.dart`. Смонтировать `CinemaRow` с 10 элементами на `MediaQuery` 1920×1080. Программно установить фокус на index 5. После `pump(GridTokens.scrollAnimation + 50ms)` прочитать `_scrollController.offset` (через `find.byType(ListView)` и `Scrollable.of(...)`); offset должен быть равен `5 * (cardW + gap.w)` с допуском 2px.
  - Наблюдаемое: тест зелёный; offset совпадает с ожидаемым.
  - _Requirements: 2.1, 2.2_
  - _Depends: 3.2_
  - _Boundary: CinemaRow_

- [ ] 5.5 Manual acceptance: ручная приёмка на референсном TV
  - Запустить `flutter run` на устройстве `192.168.100.8:5555` (через ADB). Пройти по чек-листу из `design.md` (раздел Testing Strategy → Manual / E2E Tests):
    1. Удерживая стрелку вправо, ряд скроллится без визуального stutter (Req 9.1).
    2. Левый край первой плитки фиксирован (Req 1.6).
    3. При переключении фокуса соседи не «прыгают» (Req 3.6).
    4. Быстрый скролл не вызывает мигания бейджей (Req 4.1, 4.2).
    5. На остановленной плитке через ~400 мс появляются все бейджи (Req 6.1).
    6. Ряд «Фильмы в эфире» зацикливается (Req 8.1).
    7. Пагинация при скролле к концу подгружает ещё (Req 8.2).
    8. SELECT/ENTER открывает канал (Req 10.1).
    9. На последней плитке стрелка вправо не уводит фокус (Req 10.2).
    10. Вертикальный переход между рядами (стрелка вверх/вниз) приземляется на близкую плитку (Req 10.3).
    11. ESC/BACK работают как раньше (Req 10.4).
    12. Пустой ряд скрывается; ошибочный ряд показывает короткое сообщение (Req 11.3, 11.4).
  - Наблюдаемое: все 12 пунктов чек-листа отмечены пройдёнными (комментарий под каждым в финальном отчёте задачи). Если хотя бы один не прошёл — задача остаётся `in_progress`, оператор фиксирует, что именно не работает, и переходит к остаточному анализу.
  - _Requirements: 1.6, 2.1, 3.6, 4.1, 4.2, 6.1, 8.1, 8.2, 9.1, 9.2, 9.3, 9.5, 10.1, 10.2, 10.3, 10.4, 11.3, 11.4_
  - _Depends: 4.2, 5.4_
  - _Boundary: ReferenceDevice_

- [ ] 5.6 Подтверждение performance / idle (Req 9.4)
  - На референсном TV в idle-состоянии (главный экран открыт, нет нажатий пульта 30 секунд) убедиться, что `flutter` performance overlay (`flutter run --profile`, P для overlay) не показывает постоянных тяжёлых перерисовок: GPU thread в зелёной зоне, нет постоянной работы UI thread.
  - Если перерисовки наблюдаются — диагностировать (включить `debugRepaintRainbowEnabled`/`debugProfileBuildsEnabled`) и устранить. Чаще всего это `AnimatedOpacity` с `opacity: 0` всё равно ребилдит child — в этом случае обернуть `_buildFullOverlay()` в `Visibility(visible: widget.isFocused, child: ...)` поверх `AnimatedOpacity` (или использовать `IgnorePointer` + `Visibility`).
  - Наблюдаемое: в performance overlay в idle оба графика плоские; comment с замером (например, скриншот overlay) приложен к выполнению задачи.
  - _Requirements: 9.4_
  - _Depends: 5.5_
  - _Boundary: CinemaCard, CinemaRow_

- [ ] 5.7 Финальный smoke на различных размерах окна (опционально, но рекомендуется)
  - В эмуляторе или через `flutter run -d chrome --web-renderer canvaskit` (если включён Web как target) либо изменением resolution на TV-боксе пройти три ширины: 1280, 1920, 2560. Подтвердить визуально: 3, 4 и 5 плиток в ряду соответственно; левый край фиксирован; gap 16.w виден; все плитки одной ширины.
  - Наблюдаемое: скриншоты или замечание оператора, что число колонок переключается на ожидаемых порогах.
  - _Requirements: 1.1, 1.2, 1.3, 1.6_
  - _Depends: 5.5_
  - _Boundary: CinemaRow_
