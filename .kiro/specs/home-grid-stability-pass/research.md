# Research & Design Decisions — home-grid-stability-pass

## Summary

- **Feature**: `home-grid-stability-pass`
- **Discovery Scope**: Extension (расширение поверх существующих закрытых
  спеков `home-grid-optimization`, `home-grid-visual-polish`, `home-cinematic-redesign`).
- **Key Findings**:
  - Netflix-style pin-at-slot-1 уже реализован в `cinema_row.dart` как метод
    `_scrollFocusedTileToLeadingEdge`, где `pinnedSlotIdx = 1` — но эта
    константа объявлена локально внутри метода и не вынесена в `GridTokens`.
    Контракт «грид стоит, обложки слайдятся через слот» работает эмпирически,
    но не доступен ни тестам, ни внешним консьюмерам.
  - Текущий `GridTokens.focusedScale = 1.02` (`_grid_tokens.dart:69`) уже
    низкий, но при чёткой границе фокус-рамки `focusBorderWidth = 3.0` +
    тени `blurRadius = 12` визуально соседи всё-таки воспринимаются как
    «толкаемые». Сводить scale ниже (1.00 или 1.01) безопасно: scale
    при `AnimatedScale` — GPU-only операция (`flutter-tv-perf.md`,
    «Что вредно → AnimatedContainer.width»).
  - Высота плитки сейчас задана через `availableHeight ?? 450.h` в
    `cinema_row.dart:297`. Ширина плитки — арифметически из `pickColumns`
    и горизонтальных отступов. На 4 колонках при 1920 width получается
    `cardW ≈ (1920 - 96 - 48) / 4 = 444 dp`, при `cardH = 450.h` это
    `aspect ≈ 1.0` — почти квадрат. Brief требует aspect `1.6–1.7`, что
    при cardW ≈ 444 даёт cardH ≈ 710 dp — это значительно выше текущего
    450 dp.
  - Carded metadata уже частично решена через `_buildBottomChannelLine()` +
    `_buildFullOverlay()` в `cinema_card.dart`. Compact-overlay (channel
    name) рендерится всегда; full-overlay (rating/age/genre/progress/programme)
    — только при focus, под `Visibility(visible: _shouldRenderFullOverlay)`.
    Высота нижней зоны на сегодня НЕ зафиксирована — она зависит от
    `_buildProgrammeInfo()`, где `Text` имеет `maxLines: 1` для title и
    `Flexible` для category, но переменная длина двух строк может
    варьировать высоту full-overlay'я в diapazone ~2 строки.
  - Layout-логика расчёта `cardH` из `availableHeight` сейчас завязана на
    геометрию ListView в `CinemaRow` (Positioned `top: -72.h`, `top: 56.h`,
    `bottom: 24.h`). Это нужно учесть при подъёме `cardH`: row height
    меняется, hero collapse offset в `CinematicHomeScreen` (`expandedH = 620`)
    тоже завязан на размер первой полосы — но первая полоса сидит
    ниже hero и не пересекается с ним (см. `cinematic_home_screen.dart:509`,
    `Positioned(top: expandedH, ..., child: ListView.builder)`).

## Research Log

### Pinned-slot реализация — где живёт сейчас

- **Context**: Brief требует оформить pinned-slot как явный verifiable
  invariant с тестом. Чтобы планировать тест и токен, нужно понять
  текущий контракт.
- **Sources Consulted**:
  - `/Users/romaxa55/MegaV-IPTV/megav_iptv/lib/features/home/widgets/cinema_row.dart`,
    метод `_scrollFocusedTileToLeadingEdge` (строки 244–265).
  - `/Users/romaxa55/MegaV-IPTV/megav_iptv/lib/features/home/widgets/_grid_tokens.dart` —
    все существующие токены.
- **Findings**:
  - `pinnedSlotIdx = 1` — magic-number, объявлен `const` внутри метода.
  - Алгоритм: `targetOffset = (index - pinnedSlotIdx) * (cardW + gap)`,
    clamp в `[0, maxScrollExtent]`. Guard `(clamped - current).abs() < 0.5`
    предотвращает no-op scroll.
  - Анимация: `GridTokens.scrollAnimation = 250 ms`, `GridTokens.scrollCurve =
    Curves.fastOutSlowIn`.
  - Дёрг — `WidgetsBinding.instance.addPostFrameCallback` после focus
    change в `Focus.onFocusChange` (`cinema_row.dart:406-409`).
- **Implications**:
  - Чтобы тест мог проверить инвариант без скрейпа исходников, нужно
    вынести `pinnedSlotIdx` в `GridTokens` как новый именованный токен.
  - Существующее поведение **корректное по контракту** — менять алгоритм
    не нужно, нужно только закрепить его контрактом и тестом.

### Геометрия плитки и aspect-ratio

- **Context**: Brief требует `cardH/cardW ≈ 1.6–1.7`. Нужно понять,
  как именно cardH сейчас прокидывается через CinemaRow → CinemaCard.
- **Sources Consulted**: `cinema_row.dart:296-298, 449-461`, `cinema_card.dart:99-124`.
- **Findings**:
  - В `CinemaRow.build`: `AnimatedContainer(height: widget.availableHeight ?? 450.h)`.
    Внутри — `Stack`, `Positioned(top: -72.h, bottom: 0)`, внутри `ListView.builder`.
    Внутри itemBuilder через `LayoutBuilder(constraints)` берётся `rowH =
    constraints.maxHeight` и прокидывается в `CinemaCard(cardHeight: rowH)`.
  - Поэтому фактическая `cardHeight` — это `availableHeight + 72.h - 56.h - 24.h
    = availableHeight - 8.h` (Stack-смещение + padding). При `availableHeight =
    450.h` cardHeight ≈ 442.h.
  - Значит для целевого `cardH = 1.6 × cardW ≈ 710.h` нужно поднять
    `availableHeight` на ~270.h (с 450.h до ~720.h).
- **Implications**:
  - Новый токен `cardHeightDp` (или эквивалент) должен быть введён в
    `GridTokens` как явное значение row height на TV-target. Чтобы не
    привязываться к `screenutil` в `_grid_tokens.dart` (он pure-leaf),
    значение хранится как raw double (по конвенции файла), а consumer
    в `CinemaRow` умножит на `.h`.
  - Все потребители 450.h в `cinema_row.dart` (включая loading placeholder
    на строке 116 и `tileHeight = 336.h` на строке 145) должны быть
    приведены к согласованной геометрии. Loading-placeholder использует
    отдельную высоту 336.h — это число тоже привязано к старой `cardH`;
    его нужно пересчитать.

### Фиксированная зона metadata и existing text-rendering pattern

- **Context**: Brief требует fixed-height wrapper для подписей под обложкой,
  чтобы переменная длина названия не сдвигала baseline.
- **Sources Consulted**: `cinema_card.dart:194-296` — overlays.
- **Findings**:
  - Compact-overlay содержит channel-icon + channel-name (`maxLines: 1,
    overflow: ellipsis`) внутри `Padding(EdgeInsets.only(bottom: 6.h))`.
  - Full-overlay содержит `_buildProgrammeInfo(prog)` где programme title
    `maxLines: 1, overflow: ellipsis`, year + category — Flexible.
  - Высота compact-line ≈ 22.h (18.w icon + 14.sp text). Резерв
    в full-overlay'е сделан через `SizedBox(height: 22.h + 4.h)` в конце
    `_buildFullOverlay` (cinema_card.dart:291).
  - Резерв СЕЙЧАС есть, но его значение «22.h + 4.h» — magic-number,
    разбросан в коде, не вынесен в токен.
- **Implications**:
  - Новый токен `metadataReservedHeightDp` (raw double) фиксирует общую
    высоту метаданной зоны (channel-line + опциональный second-line slot
    для programme title). Сейчас «реально» внутри full-overlay'я programme
    title ещё одна строка — но в нефокусном состоянии она убрана через
    Visibility, и compact-overlay показывает только channel-name. Чтобы
    избежать ощущения «прыжка metadata высоты при focus», новая
    спецификация фиксирует общий vertical region в одинаковой высоте
    в обоих состояниях.
  - Возможный путь: ввести wrapper `SizedBox(height: metadataReservedHeightDp.h)`
    в compact-overlay'е, в котором channel-line с потенциальным запасом
    под programme title (с `maxLines: 2, overflow: ellipsis`). Тогда
    при focus/unfocus вертикальный baseline остаётся неизменным.

### Pinned-slot инвариант — как протестировать

- **Context**: Req 5 требует automated widget test, который двигает фокус
  через 5 плиток и проверяет, что `RenderBox.localToGlobal(Offset.zero)`
  стабильна.
- **Sources Consulted**: existing tests in `megav_iptv/test/features/home/`
  (структура), `flutter_test` `WidgetTester` API.
- **Findings**:
  - Существующие тесты для editorial home (`editorial_home_screen_smoke_test.dart`),
    pick_columns regression test — все используют `pumpWidget` + `tester.element`.
  - Для замера screen-space позиции `Finder` → `tester.getRect(finder)` или
    `tester.renderObject<RenderBox>(finder).localToGlobal(Offset.zero)`.
  - Чтобы программно двигать focus через 5 плиток подряд, тест должен
    эмулировать `LogicalKeyboardKey.arrowRight` через
    `tester.sendKeyEvent(LogicalKeyboardKey.arrowRight)`. Между нажатиями —
    `await tester.pumpAndSettle()` чтобы дождаться `scrollAnimation` 250 ms
    + frame post-callback `_scrollFocusedTileToLeadingEdge`.
- **Implications**:
  - Тест должен мокать `pickColumns` ширину через `MediaQueryData(size:
    Size(1920, 1080))` (где `pickColumns → 4`).
  - Тест должен использовать deterministic dataset из `NowPlayingItem`
    fixture, длиной N ≥ pinnedSlot + 4 + 2 = 7 элементов.
  - Tolerance 1.0 dp учитывает sub-pixel rounding в `clamp`-guard.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Новые токены в `GridTokens` | Расширить существующий класс новыми константами (`focusedScale` → 1.00/1.01, `cardHeightDp`, `metadataReservedHeightDp`, `pinnedSlotIdx`, `unfocusedNeighbourOpacity`). | Минимальная поверхность изменений; согласованность; уже принятый паттерн `home-grid-optimization`. | Закрытая спека `home-grid-optimization` запрещает повторное открытие — но добавление новых констант без удаления/изменения существующих НЕ является повторным открытием контракта (старые токены остаются с теми же значениями). | Принято. |
| Создать новый файл токенов `_stability_tokens.dart` | Изолировать новые константы от `_grid_tokens.dart`. | Чёткий boundary, нет риска «случайно поправил old token». | Дублирование инфраструктуры, два источника правды на одну сетку. Старые консьюмеры всё равно должны импортировать оба. | Отклонено. |
| Pinned-slot инкапсулировать в отдельный `PinnedSlotPolicy` объект | Вынести логику scroll-to-pinned в strategy-объект с интерфейсом. | Чистая абстракция, удобно тестировать. | Over-engineering для одной строки кода; `_scrollFocusedTileToLeadingEdge` уже достаточно изолирован. | Отклонено. |
| FixedHeight metadata через extension widget | Создать `FixedHeightMetadata({required this.child, required this.height})` wrapper. | Переиспользование; единая точка fixed-height policy. | Один потребитель (`CinemaCard`); излишний widget-слой. | Отклонено: достаточно `SizedBox(height: ...)` внутри `cinema_card.dart`. |

## Design Decisions

### Decision: Все новые токены — в существующем `GridTokens`

- **Context**: Brief требует не открывать закрытые спеки. `_grid_tokens.dart`
  принадлежит `home-grid-optimization`, но добавление новых констант,
  не модифицируя существующие, не нарушает контракт спеки (доказательство:
  все потребители существующих токенов сохраняют наблюдаемое поведение).
- **Alternatives Considered**:
  1. Отдельный `_stability_tokens.dart` — отвергнут из-за дублирования.
  2. Inline-константы в `cinema_card.dart` / `cinema_row.dart` — отвергнут
     из-за необходимости referenceability из теста (Req 1.5, 2.3, 3.6).
- **Selected Approach**: Расширить `GridTokens` блоком `// --- v2 (stability
  pass): новые токены, не модифицируют существующие ---`, в котором лежат
  `focusedScale` (новое значение через **новую отдельную константу**, не
  переопределяя старую), `pinnedSlotIdx`, `cardHeightDp`,
  `metadataReservedHeightDp`, `unfocusedNeighbourOpacity`. Старый
  `focusedScale = 1.02` оставлен на месте как deprecated alias только если
  что-то ещё на него ссылается — фактически на момент задачи он
  используется ТОЛЬКО в `cinema_card.dart:110`, поэтому можно безопасно
  заменить значение на новое и оставить имя.
- **Rationale**: Не открываем `home-grid-optimization` (его контракт —
  существование токена `focusedScale` и pickColumns алгоритм; конкретное
  значение `1.02` не было acceptance criterion закрытой спеки). Меняем
  ровно одно значение и добавляем новые рядом. Это extension, не
  модификация контракта.
- **Trade-offs**: Pro — минимальная поверхность. Con — `GridTokens`
  растёт. Митигация — секционные комментарии по версиям.
- **Follow-up**: Проверить, что pre-commit hook `check-file-size` не
  ругается на `_grid_tokens.dart` после расширения (текущий размер
  ~92 строки, лимит ≈ 600 строк).

### Decision: Pinned-slot инвариант — оставить существующий алгоритм, формализовать через токен + dartdoc + тест

- **Context**: Brief требует «verifiable invariant», но текущий код уже
  правильный. Нет смысла переписывать.
- **Alternatives Considered**:
  1. Переписать `_scrollFocusedTileToLeadingEdge` через strategy-pattern —
     отвергнут (over-engineering).
  2. Заменить `addPostFrameCallback` на `Scrollable.ensureVisible` —
     отвергнут (последний прячет от теста pinned-slot smyl, контролируя
     viewport-edges, а не slot-position).
- **Selected Approach**:
  - Вынести magic-number `1` в `GridTokens.pinnedSlotIdx`.
  - Заменить локальную `const pinnedSlotIdx = 1` на референс токена.
  - Добавить dartdoc-блок на класс `CinemaRow` с описанием инварианта
    (см. Req 1.6).
  - Написать widget-тест, который мокает size и dataset, гоняет фокус,
    замеряет `RenderBox.localToGlobal(Offset.zero)` для фокусной плитки.
- **Rationale**: Контракт фиксируется текстом + тестом, не кодом. Тест
  ловит регрессию в момент изменения, до code-review.
- **Trade-offs**: Pro — minimal-touch, no risk of breaking existing
  behaviour. Con — нет formalного контракт-объекта (но это и не нужно).
- **Follow-up**: Убедиться, что тест работает с `tester.sendKeyEvent`
  без живого `RawKeyboard` сервиса — обычно достаточно `WidgetTester`
  + `FocusManager`.

### Decision: Fixed-height metadata через `SizedBox` обёртку внутри `cinema_card.dart`

- **Context**: Req 3.3, 3.4 требуют фиксированной зоны метаданных.
- **Alternatives Considered**:
  1. Отдельный widget `FixedHeightMetadata` — отвергнут (single consumer).
  2. Полностью переписать `_buildCompactOverlay` / `_buildFullOverlay` —
     отвергнут (риск breaking compact-overlay контракта из `home-grid-optimization`
     Req 5).
- **Selected Approach**:
  - В `_buildCompactOverlay` обернуть `_buildBottomChannelLine` в
    `SizedBox(height: GridTokens.metadataReservedHeightDp.h, child: ...)`.
  - Внутри — `Column` с двумя слотами: `channel-line` (maxLines: 1) +
    зарезервированный слот под programme title (виден только при focus,
    но место в нефокусной плитке сохранено через прозрачный placeholder
    или просто пустой `Expanded`).
  - В `_buildFullOverlay` синхронизировать SizedBox-резерв с новым
    значением `metadataReservedHeightDp` (заменить magic-number
    `22.h + 4.h`).
- **Rationale**: Минимальное хирургическое изменение, не ломает
  закрытые контракты по compact/full overlay'ям.
- **Trade-offs**: Pro — surgical. Con — двойная книжка между compact и
  full; митигируется через один токен `metadataReservedHeightDp` (single
  source of truth).
- **Follow-up**: Решить — отображать ли programme title в нефокусном
  состоянии (Brief дополнительно упоминает «2 строки максимум»). По
  умолчанию — нет (compact-overlay показывает только channel-name), но
  fixed-height зона уже зарезервирована под обе строки.

### Decision: Neighbour de-emphasis — опционально, через `Opacity` на нефокусных плитках

- **Context**: Req 2.2 разрешает «optional neighbour de-emphasis (opacity
  ниже 1.0)». Brief: «соседние плитки получают `Opacity(0.92)` для
  усиления фокуса без геометрических сдвигов».
- **Alternatives Considered**:
  1. `ColorFiltered(matrix: brightness 0.92)` — `ColorFiltered` относительно
     дорог на Mali (saveLayer + shader compile при первом использовании).
     Отвергнут.
  2. `Opacity` обёртка над `CinemaCard` в `CinemaRow.itemBuilder` для
     нефокусных индексов — выбран. На Flutter Impeller `Opacity` дёшев
     (`flutter-tv-perf.md`: «Opacity дёшев в Flutter Impeller», уточнение —
     стоит только saveLayer при opacity < 1, но это локально).
- **Selected Approach**:
  - В `CinemaRow.itemBuilder` обернуть тайл в `Opacity(opacity:
    isRowFocused && !isFocused ? GridTokens.unfocusedNeighbourOpacity :
    1.0, child: ...)`. Условие `isRowFocused` означает «фокус внутри
    ряда»; нефокусные ряды остаются с opacity 1.0.
  - Значение `unfocusedNeighbourOpacity ≈ 0.92` (см. Brief).
- **Rationale**: GPU-cheap, не сдвигает геометрию.
- **Trade-offs**: Pro — наименьший cost. Con — `Opacity < 1.0` создаёт
  saveLayer (1 frame cost). Митигация — применяется только когда ряд
  активен (focus внутри ряда), что обычно один ряд на экране одновременно.
- **Follow-up**: Замерить avg `GPURasterizer::Draw` для фокусного ряда
  на rtd2851a после внедрения. Если регрессия — снять Opacity wrapper
  (Req 2.2 говорит «optional»).

## Risks & Mitigations

- **Риск**: Увеличение `cardHeightDp` ломает hero-offset в
  `CinematicHomeScreen` (`expandedH = 620`), если hero и первая полоса
  визуально пересекаются.
  - **Митигация**: Hero сидит в `Positioned(top: 0, height: expandedH)`,
    rails — в `Positioned(top: expandedH, ...)`. Они не пересекаются. Но
    высота viewport'а ниже hero уменьшается на 270 dp — это может
    обрезать первую полосу на 1280×720 экранах. **Проверить через тест**:
    смоук-тест `cinematic_home_screen` (если есть) либо вручную замерить
    `MediaQuery.sizeOf` под TV-target профилем.
- **Риск**: Loading placeholder в `cinema_row.dart:115-136` использует
  жёсткое `336.h` для тайл-высоты — после поднятия cardH placeholder
  будет визуально короче загруженной плитки, дёрг будет.
  - **Митигация**: Заменить `336.h` на `GridTokens.cardHeightDp.h -
    (рассчитанное смещение Stack/Padding)`, чтобы placeholder и загруженный
    тайл совпадали.
- **Риск**: Снижение `focusedScale` до 1.00 убирает любое тактильное
  «приподнятие» фокусной плитки — но Brief разрешает 1.00 ИЛИ 1.01.
  - **Митигация**: Выбрать 1.01 (компромисс: сосед визуально не
    сдвигается на пиксельной сетке, но фокусная плитка минимально
    приподнимается).
- **Риск**: Pinned-slot тест нестабильно работает из-за
  `addPostFrameCallback` + `scrollAnimation 250 ms` race condition.
  - **Митигация**: В тесте использовать `await tester.pumpAndSettle(const
    Duration(seconds: 1))` после каждого `sendKeyEvent`, чтобы
    гарантированно дождаться завершения анимации скролла.
- **Риск**: Existing widget-tests фейлятся из-за изменения cardH (числовые
  ожидания).
  - **Митигация**: Req 4.3 — допустимо обновить такие тесты. В рамках
    задач (см. tasks.md) делается явный pass через `grep` по существующим
    тестам и точечная правка только тех чисел, что прямо завязаны на
    cardH.

## References

- `.kiro/specs/home-grid-optimization/design.md` — оригинальный pickColumns
  + grid tokens контракт (read-only, не открываем).
- `.kiro/specs/home-grid-visual-polish/design.md` — fade-edge + Visibility
  wrapper контракт (read-only, не открываем).
- `.kiro/specs/home-cinematic-redesign/design.md` — двойной hero/rails
  layout (read-only).
- `.kiro/steering/flutter-tv-perf.md` — TV-perf rules для Mali GPU.
- `megav_iptv/lib/features/home/widgets/_grid_tokens.dart` — текущие токены.
- `megav_iptv/lib/features/home/widgets/cinema_row.dart` — pinned-slot
  реализация (`_scrollFocusedTileToLeadingEdge`, строки 244-265).
- `megav_iptv/lib/features/home/widgets/cinema_card.dart` — overlays +
  metadata (compact/full).
- `megav_iptv/lib/features/home/cinematic/cinematic_home_screen.dart` —
  Cinematic HomeScreen, потребитель CinemaRow.
- `megav_iptv/lib/features/home/home_screen.dart` — legacy HomeScreen
  (по grep, тоже потребитель).
