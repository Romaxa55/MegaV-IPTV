# Research & Design Decisions

## Summary
- **Feature**: `home-grid-optimization`
- **Discovery Scope**: Extension (рефакторинг двух существующих файлов: `cinema_row.dart`, `cinema_card.dart`)
- **Key Findings**:
  - Главные источники тормозов — `boxShadow.blurRadius=50` при фокусе и relayout-каскад при изменении ширины активной плитки. Не количество плиток как таковое.
  - AndroidX Leanback (база Netflix Android TV) даёт готовые тайминги: `lb_card_activated_animation_duration=150ms`, `lb_card_selected_animation_delay=400ms`, `lb_browse_rows_anim_duration=250ms` — все они применимы без копирования кода.
  - Netflix не использует expanded-режим карточек: при фокусе только `scale 1.05–1.2 + рамка`, без relayout соседей. Это и есть главный архитектурный инсайт.

## Research Log

### Анализ текущей реализации `cinema_card.dart` (471 строк)
- **Context**: Понять, что именно греет рендер на TV.
- **Sources Consulted**: `lib/features/home/widgets/cinema_card.dart`, `lib/core/ui/ui_performance.dart`.
- **Findings**:
  - `boxShadow` с `blurRadius: 50, spreadRadius: -12` при фокусе — самая дорогая операция в кадре. Существующая ветка `effectiveLowPowerUi` снижает blur до 8, но порог срабатывания «low power» не охватывает все TV-боксы.
  - На каждой карточке двойная implicit-анимация: `AnimatedScale` (200 мс) + `AnimatedContainer` (200 мс), при этом `AnimatedContainer` анимирует `width`, что вызывает re-layout всего поддерева.
  - `_pseudoRating()`, `_pseudoAgeRating()`, `_genreEmoji()` — псевдо-данные, пересчитываются на каждом `build()` без кэша.
  - `Stack` карточки содержит постер + градиент + оверлей с 11+ декорированных Container'ов (LIVE-бейдж со своими тенями, рейтинг, возрастной рейтинг, эмодзи жанра, прогресс-бар, год, название, имя канала, логотип канала). На неактивной плитке всё это рендерится впустую.
- **Implications**: Дизайн должен (1) убрать тяжёлый blur, (2) разделить overlay на compact/full, (3) кэшировать псевдо-данные, (4) запретить анимировать `width`.

### Анализ `cinema_row.dart` (461 строка)
- **Context**: Понять модель сетки и focus-handling.
- **Sources Consulted**: `lib/features/home/widgets/cinema_row.dart`.
- **Findings**:
  - Активная плитка в 2 раза шире неактивной: `narrowW = usableWidth/6`, `fullW = narrowW*2`. На каждый шаг фокуса меняется ширина → `ListView` пересчитывает layout всего ряда.
  - Сложная логика `_activeCol`: мерджит `_hoveredCol` (мышь), `_focusedCol` (D-pad) и `_lastActiveCol` (запоминание). После отказа от expanded достаточно одного `_focusedIndex`.
  - `_scrollFocusedCardToLeadingEdge` уже реализует Netflix-стиль (левое выравнивание), но логика offset зависит от того, что только активная плитка `fullW` — после фиксации ширины упрощается до `index × (cardW + gap)`.
  - Текущий `Curves.easeOut` (длительность 280 мс) для скролла — близко к Leanback, но не deceleration-форма.
  - `cacheExtent: 1500.w` хороший — оставляем.
  - Шапка ряда содержит чевроны для мыши, пагинационный счётчик, индикатор «Фильмы в эфире» — всё сохраняем.
- **Implications**: Модель упрощается значительно. `_focusedIndex` единственный, ширина фиксированная, scroll-offset арифметически точный.

### Сравнение с AndroidX Leanback / Netflix Android TV
- **Context**: Какие тайминги и поведения брать как эталон.
- **Sources Consulted**: декомпиляция Netflix Android TV APK 12.1.9 (`/tmp/netflix-decoded/res/values/integers.xml`, `dimens.xml`, `anim/`).
- **Findings**:
  - `lb_card_activated_animation_duration = 150 ms` — длительность активации фокуса карточки.
  - `lb_card_selected_animation_delay = 400 ms` — задержка перед запуском «полного» selection-эффекта (Netflix-debounce). При быстром скролле полный эффект не запускается вообще.
  - `lb_card_selected_animation_duration = 150 ms`.
  - `lb_browse_rows_anim_duration = 250 ms` — длительность скролла строк.
  - `lb_browse_padding_start = 56dp`, `lb_browse_padding_end = 56dp`, `lb_browse_item_horizontal_spacing = 8dp`.
  - `decelerateInterpolator factor=2.0` для скролла. В Flutter эквивалент — `Curves.fastOutSlowIn` (или `Curves.decelerate`).
  - Карточка визуально проще нашей: постер + одна нижняя строка с заголовком. Богатые бейджи показываются у выбранной через hovercard.
- **Implications**: Тайминги 150/250/400 берём напрямую. Curves — `fastOutSlowIn` для scroll, `easeOutCubic` для scale (текущий хороший). Padding — компромисс 40dp (текущий) → 48dp (мягкое увеличение); spacing 24 → 16 (компромисс между Leanback 8 и текущим 24).

### Адаптивная модель «3/4/5 плиток»
- **Context**: Как выбирать число колонок на разных экранах.
- **Sources Consulted**: `flutter_screenutil` поведение, наблюдения за реальными разрешениями TV.
- **Findings**:
  - Типовые разрешения Android TV: 1280×720 (HD-боксы), 1920×1080 (FullHD), 2560×1440 (редко), 3840×2160 (4K).
  - `flutter_screenutil` уже сконфигурирован в проекте — `.w` / `.h` / `.r` / `.sp` уже работают.
  - Брать ширину из `MediaQuery.sizeOf(context).width` (uses logical pixels, не pixel-ratio).
- **Implications**: Пороги — `< 1280 → 3`, `1280..2559 → 4`, `>= 2560 → 5`. Реализация — простой `int pickColumns(double screenW)`.

### Интеграция с `FastScrollDetector`
- **Context**: Текущий код уже использует `FastScrollDetector` для отключения scale-анимации. Как это сочетается с новым debounce?
- **Sources Consulted**: `lib/core/ui/utils/fast_scroll_detector.dart`, `cinema_card.dart:46-47`.
- **Findings**:
  - FastScrollDetector — singleton, сам считает «быстрый скролл» по частоте `onEvent()` вызовов.
  - При fast-scroll он возвращает true для `context.isFastScrolling`, и карточка отключает scale-анимацию.
  - Debounce 400 мс — это **другая** оптимизация: отложить **тяжёлые side effects** (раскрытие full overlay, callback в Hero) до момента, когда фокус «устаканился».
- **Implications**: Сохраняем оба механизма. FastScrollDetector — про мгновенные визуальные анимации (scale). Debounce 400 мс — про побочные эффекты (overlay, hero update). Они не конфликтуют.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| **A. Status quo + tweaks** | Только убрать blur=50 и снизить анимации до 150 мс | Минимум риска, ~1 день | Сохраняет expanded → relayout остаётся, перегруз карточки остаётся | Отвергнут — не решает корневые причины |
| **B. Сбалансированный** (выбран) | Фикс. ширина + scale-only фокус + compact/full overlay + debounce 400 мс + Leanback-тайминги | Решает все 5 пунктов brief, минимум новых концепций, ~3 дня | Visual change: пользователь увидит новое поведение карточки | Прямой Netflix-паттерн, идеальный fit для TV |
| **C. Радикальный** | Б + CachedNetworkImage + RepaintBoundary гигиена + CustomPainter для прогресс-бара | Максимальная производительность | +зависимость, ~5–7 дней, риск over-engineering | Отложен в отдельный спек (если после Б не хватит) |

**Selected**: Option B.

## Design Decisions

### Decision: Отказ от expanded-режима карточки
- **Context**: Текущая модель раздувает активную плитку в 2× ширины, что триггерит re-layout соседей.
- **Alternatives Considered**:
  1. Сохранить expanded, но дешевле (Transform.scaleX вместо AnimatedContainer width) — сложно сделать без визуальных артефактов на сайдсах.
  2. Полностью убрать expanded, выделять только scale + рамкой — Netflix-паттерн.
- **Selected Approach**: (2) — все плитки в ряду одной ширины, активная отличается только `Transform.scale(1.08)` и цветной рамкой.
- **Rationale**: Это GPU-операция, не layout. Соседи не двигаются, левый край ряда фиксирован, ощущение «болтанки» уходит. Производительность улучшается двукратно.
- **Trade-offs**: Визуально активная плитка не «разворачивается». Польза стабильности интерфейса перевешивает.
- **Follow-up**: Проверить на референсном TV, нет ли визуального ощущения «ничего не происходит» при фокусе. При необходимости усилить рамку или добавить glow в виде статичного PNG.

### Decision: Compact + Full overlay вместо одного перегруженного
- **Context**: Сейчас все 11+ Container'ов оверлея рендерятся на каждой карточке.
- **Alternatives Considered**:
  1. Оставить full overlay везде, но опустить часть бейджей за пределы видимой области (через `Visibility(visible: focused)` с замораживанием рендера).
  2. Разделить на compact (всегда) + full (только у активной), full fade-in 150 мс.
- **Selected Approach**: (2). Compact = постер + bottom-полоска с названием канала и LIVE-индикатором. Full = compact + рейтинг + возрастной рейтинг + эмодзи жанра + прогресс-бар + год + название программы.
- **Rationale**: На неактивных плитках рендерится в 3 раза меньше Widget'ов. Это и Netflix-паттерн (hovercard).
- **Trade-offs**: Появляется дополнительная анимация при фокусе. Риск визуального «мерцания» при быстром скролле — устраняется debounce 400 мс перед fade-in.

### Decision: Объединение `_hoveredCol` и `_focusedCol` в `_focusedIndex`
- **Context**: Текущая логика держит 3 состояния (`_hoveredCol`, `_focusedCol`, `_lastActiveCol`) и сложную мердж-функцию `_activeCol`.
- **Alternatives Considered**:
  1. Сохранить 3 состояния (мышь и фокус — разные источники).
  2. Слить в одно — мышь и D-pad оба триггерят focus через `Focus.requestFocus()`.
- **Selected Approach**: (2). MouseRegion в плитке вызывает `Focus.of(context).requestFocus()`, дальше всё через стандартный focus-pipeline.
- **Rationale**: Без expanded-режима нет смысла различать «mouse hover» и «D-pad focus» — оба показывают одинаковый эффект. Код проще, багов меньше.
- **Trade-offs**: Если мышь над одной плиткой, а D-pad на другой — побеждает последняя получившая фокус. На TV это не проблема (мыши обычно нет).

### Decision: Debounce только для тяжёлых побочных эффектов
- **Context**: Где именно ставить 400 мс таймер.
- **Alternatives Considered**:
  1. Debounce весь focus-change → scale-анимация будет с задержкой, ощущение «лагов».
  2. Debounce только: (a) fade-in full overlay, (b) callback в Hero `onItemFocus`.
- **Selected Approach**: (2). Scale и рамка появляются мгновенно (через 150 мс), а раскрытие overlay и обновление Hero отложены на 400 мс.
- **Rationale**: Пользователь чувствует мгновенный отклик, при этом дорогие операции не запускаются на каждой пролетающей плитке.
- **Trade-offs**: Два разных таймера (150 мс scale + 400 мс debounce) — чуть сложнее логика, но прозрачно.

## Risks & Mitigations

- **Риск**: На референсном TV-боксе после Подхода 2 всё ещё могут быть тормоза (если узкое место в декодинге PNG/JPEG постеров).
  - **Митигация**: Self-verification на этапе impl. Если плавность не достигнута — открываем отдельный спек на Подход 3 (CachedNetworkImage с диск-кешем + CustomPainter).
- **Риск**: Контракт `onItemFocus(NowPlayingItem?)` сейчас вызывается мгновенно. После debounce поведение изменится — Hero будет обновляться с задержкой 400 мс.
  - **Митигация**: Это ожидаемое поведение (см. Req 4). Hero уже имеет debounce `_hoveredClearDebounce` (200 мс) для обратного перехода. Согласовываем поведение в HomeScreen без изменения публичного API виджета.
- **Риск**: Удаление `_lastActiveCol` может сломать сценарий «вернулся в ряд после ухода в Hero» (раньше плитка восстанавливала last-active вид).
  - **Митигация**: Стандартный Flutter focus-traversal сам помнит последний фокусный child через `FocusTraversalGroup`. Проверяем при тестировании.
- **Риск**: При смене разрешения экрана (например, подключили внешний монитор) — `pickColumns` вернёт другое значение, сетка перестроится.
  - **Митигация**: Это ожидаемое поведение, не баг. На Android TV разрешение фиксировано на старте.

## References

- Netflix Android TV APK 12.1.9 build 23083 (`com.netflix.ninja`) — декомпилированные ресурсы как эталон таймингов.
- AndroidX Leanback library `androidx.leanback:leanback` — источник `lb_*` констант.
- Flutter docs: [`AnimatedScale`](https://api.flutter.dev/flutter/widgets/AnimatedScale-class.html), [`AnimatedOpacity`](https://api.flutter.dev/flutter/widgets/AnimatedOpacity-class.html), [`Curves.fastOutSlowIn`](https://api.flutter.dev/flutter/animation/Curves/fastOutSlowIn-constant.html) — стандартные виджеты, используем без новых либ.
