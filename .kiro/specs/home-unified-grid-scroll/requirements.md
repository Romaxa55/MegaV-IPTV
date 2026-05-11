# Requirements Document

## Introduction

Пользователь — оператор Android TV-бокса Realtek `rtd2851a` (32-bit ARM, Mali-class GPU, 512 МБ RAM), управляющий MegaV-IPTV пультом с D-pad. На текущем главном экране (cinematic) hero и rails живут как два независимых scroll-вьюера в одном `Stack(Positioned)`: hero сидит сверху на фиксированных 620 dp, rails — в отдельном `ListView.builder` под ним. Hero пытается «сворачиваться в плитку» через `HeroTileMorph` (300 ms morph), но это не соответствует ментальной модели пользователя.

Желаемое поведение: главный экран — единый вертикально-скроллящийся grid, где hero является обычной row-0 шириной во всю экранную область (1×4 при 4-колоночной сетке на 1920 dp). Фокус всегда закреплён за одним и тем же экранным слотом — second visible row, second slot horizontally (по аналогии с уже существующим горизонтальным `pinnedSlotIdx=1`). Стрелки D-pad сдвигают grid под фокусом, фокус сам никогда не движется в screen-space. ↑/↓ скроллят ряды вертикально, ←/→ скроллят плитки внутри ряда (наследуют уже работающий горизонтальный Pinned-Slot Invariant). Hero естественно «уплывает» наверх как обычная row при скролле вниз и возвращается на экран при скролле наверх.

Это поведение должно работать одинаково на референсном TV-боксе `rtd2851a` (worst-case envelope: ≤ 16.7 ms на GPURasterizer::Draw, 60 fps) и на macOS desktop (parity для разработки и smoke-сессий — стрелки клавиатуры работают как D-pad). Legacy `/home`, плеер, EPG, mobile, settings — не затрагиваются.

## Boundary Context

- **In scope**:
  - Cinematic-главный экран (`/home` cinematic route).
  - Hero как row-0 (`1×4` на 1920 dp), полноширинный, обычный child единого вертикального ListView.
  - Vertical Pinned-Slot Invariant (вертикальный аналог уже работающего горизонтального).
  - Удаление `HeroTileMorph` и его тестов; hero больше не сворачивается в плитку.
  - Vertical scroll анимация (≤ 300 ms, `easeInOutCubic`) при движении фокуса между рядами.
  - D-pad ←/→ внутри ряда — продолжают работать через существующий `CinemaRow` без изменений.
  - macOS desktop parity (стрелки клавиатуры как D-pad).
  - Widget-тест для vertical pinned-slot (по аналогии с существующим `cinema_row_pinned_slot_test.dart`).
- **Out of scope**:
  - Legacy `/home` (`HomeScreen`) — не трогаем.
  - Плеер (`/player/...`), EPG, search, mobile, settings — не трогаем.
  - Backend / API / playlist data flow — не трогаем (те же providers).
  - 6 palettes / theming — read-only.
  - Структура самих rails (`CinemaRow`, `CinemaCard`) — переиспользуется как есть.
- **Adjacent expectations**:
  - `home-grid-stability-pass`: горизонтальный Pinned-Slot Invariant и `cardHeightDp = 720` остаются неизменными; vertical-вариант расширяет тот же контракт на вторую ось.
  - `home-grid-optimization`: `pickColumns`, `GridTokens.gapDp`, `GridTokens.horizontalPaddingDp` — read-only.
  - `home-cinematic-redesign`: `CinematicHeroContent`, `CinematicRail` content остаются нетронутыми; меняется только их размещение в дереве.
  - `flutter-tv-perf.md`: правила (no BackdropFilter, no ShaderMask, no `AnimatedContainer.height`, `BoxShadow.blurRadius ≤ 12`) обязательны.
  - `hero-collapse-tile-morph`: становится obsolete; код удаляется в рамках этой спеки, история спеки остаётся в `.kiro/specs/`.

## Requirements

### Requirement 1: Унифицированный вертикальный grid

**Objective:** Как оператор Android TV, я хочу видеть главный экран как одну непрерывную вертикальную сетку из рядов, чтобы перемещение пультом ощущалось как один цельный grid, а не два разных скролл-блока.

#### Acceptance Criteria

1. While пользователь находится на cinematic-главном экране, the Home Screen shall отображать единый вертикальный список рядов, где первый ряд (row-0) — это hero, а последующие ряды (row-1..row-N) — обычные cinema rows с плитками.
2. The Home Screen shall использовать ровно один вертикальный scroll-вьюер для всего содержимого экрана (hero и rails не имеют независимых вертикальных скроллов).
3. When экран отрисовывается на ширине ≥ 1920 dp, the Home Screen shall показывать hero как полноширинный блок размером во всю экранную ширину (`1×N`, где `N = pickColumns(screenW)`).
4. While данные hero загружаются или отсутствуют, the Home Screen shall сохранять row-0 место под hero, но не блокировать прокрутку остальных рядов.
5. The Home Screen shall не отображать hero одновременно в двух местах (например, и как row-0, и как отдельный `Positioned` блок сверху).

### Requirement 2: Vertical Pinned-Slot Invariant

**Objective:** Как оператор TV-бокса, я хочу чтобы фокусированный ряд всегда был на одной и той же экранной позиции, чтобы глаз не «прыгал» при перемещении вверх-вниз — grid едет под фокусом, а не наоборот.

#### Acceptance Criteria

1. The Home Screen shall закреплять focused ряд за screen-space позицией, соответствующей `verticalPinnedSlotIdx = 1` (вторая видимая row сверху).
2. When фокус переходит с одного ряда на следующий (focused row index изменяется `i → i+1` или `i → i-1`) и оба ряда находятся в middle-region (не leading, не trailing edge), the Home Screen shall сохранять screen-space Y-позицию focused ряда с допуском ≤ 1.0 dp относительно предыдущего шага.
3. When focused row index ∈ `[0, verticalPinnedSlotIdx]`, the Home Screen shall выставлять вертикальный scrollOffset = 0 (leading-edge clamp: контент не уходит «выше» начала).
4. When focused row index приближается к последним `(visibleRowsCount − verticalPinnedSlotIdx)` рядам, the Home Screen shall выставлять вертикальный scrollOffset = `maxScrollExtent` (trailing-edge clamp: контент не уходит «ниже» конца).
5. While пользователь не двигает D-pad, the Home Screen shall не инициировать самопроизвольный вертикальный скролл.

### Requirement 3: D-pad вертикальная навигация ↑/↓

**Objective:** Как оператор пульта, я хочу нажимать ↑/↓ и видеть как grid плавно сдвигается под фокусом, а сам фокус оставался на месте — это даёт ощущение «сетка движется, я нет».

#### Acceptance Criteria

1. When пользователь нажимает D-pad ↓ на пульте и focused row index < N − 1, the Home Screen shall переводить фокус на следующий ряд (`i → i+1`) и анимировать вертикальный scrollOffset так, чтобы новый focused ряд оказался в pinned slot.
2. When пользователь нажимает D-pad ↑ на пульте и focused row index > 0, the Home Screen shall переводить фокус на предыдущий ряд (`i → i-1`) и анимировать вертикальный scrollOffset так, чтобы новый focused ряд оказался в pinned slot.
3. The Home Screen shall завершать каждую вертикальную scroll-анимацию за ≤ 300 ms.
4. The Home Screen shall использовать кривую анимации `easeInOutCubic` для вертикального скролла рядов.
5. If пользователь нажимает D-pad ↓ на последнем ряду (`focused row index == N − 1`), the Home Screen shall не двигать фокус и не вызывать визуальный сдвиг grid.
6. If пользователь нажимает D-pad ↑ на row-0, the Home Screen shall не двигать фокус и не вызывать визуальный сдвиг grid.
7. While вертикальная scroll-анимация выполняется, the Home Screen shall не запускать вторую конкурирующую вертикальную анимацию (повторные нажатия отрабатываются после её завершения или плавно сменяют цель).

### Requirement 4: D-pad горизонтальная навигация ←/→ внутри ряда

**Objective:** Как оператор пульта, я хочу чтобы стрелки ←/→ продолжали работать как сейчас в `CinemaRow` (горизонтальный Pinned-Slot Invariant), потому что это уже привычное и протестированное поведение.

#### Acceptance Criteria

1. When пользователь нажимает D-pad → внутри focused ряда (row-1..row-N), the Home Screen shall перемещать фокус на следующую плитку внутри того же ряда и сдвигать горизонтальный scrollOffset ряда, не меняя focused row index.
2. When пользователь нажимает D-pad ← внутри focused ряда, the Home Screen shall перемещать фокус на предыдущую плитку и сдвигать горизонтальный scrollOffset ряда, не меняя focused row index.
3. While focused row — это row-0 (hero), the Home Screen shall передавать D-pad ←/→ существующим focusable элементам hero (кнопки «Смотреть», «Программа», «В избранное»), не вызывая горизонтального скролла.
4. The Home Screen shall сохранять горизонтальный Pinned-Slot Invariant внутри row-1..row-N в неизменном виде (контракт `cinema_row_pinned_slot_test.dart` остаётся зелёным).
5. When фокус переходит с последней плитки одного ряда на следующий ряд через D-pad ↓, the Home Screen shall сохранять горизонтальный slot index focused плитки в новом ряду насколько это возможно (если в новом ряду меньше плиток, фокус становится на последнюю).

### Requirement 5: Поведение hero как row-0

**Objective:** Как оператор, я хочу чтобы hero вёл себя как обычная часть сетки: видим при скролле вверх, уезжает при скролле вниз, без «сворачивания в плитку».

#### Acceptance Criteria

1. While focused row — это row-1 (вторая по списку, занимает pinned slot), the Home Screen shall показывать hero как row-0 полностью видимым над focused ряду.
2. When focused row index ≥ 2 и пользователь продолжает скроллить вниз, the Home Screen shall выводить hero за пределы видимой области через стандартный вертикальный scrollOffset (без отдельной morph-анимации сжатия).
3. When focused row = row-0 (hero), the Home Screen shall делать активными focusable элементы hero (кнопка «Смотреть» и др.) и hero занимает pinned slot screen-space позицию для row-0 (leading-edge clamp: hero полностью видна).
4. The Home Screen shall не отображать hero в виде «свернутой плитки» (compact tile / morphed tile) ни при каких условиях.
5. The Home Screen shall сохранять hero data flow (`featuredNowPlayingProvider`, carousel rotation, hover preview) в части доступности данных; визуальное представление hero — content внутри row-0.
6. While focused row — это row-0, the Home Screen shall запускать hero carousel rotation (8-секундный интервал) при наличии ≥ 2 featured items.
7. While focused row ≠ row-0, the Home Screen shall останавливать hero carousel rotation timer.

### Requirement 6: Удаление HeroTileMorph

**Objective:** Как разработчик, я хочу убрать ненужный код morph-логики, потому что новая ментальная модель делает её обсолетной.

#### Acceptance Criteria

1. The Home Screen shall не использовать виджет, который анимирует geometry+opacity hero в плитку первого ряда.
2. The Home Screen shall не зависеть от `FirstSlotConfig`-механизма (slot-0 override в `CinemaRow`) для hero.
3. While реализация выкатывается, the Project shall удалить `hero_tile_morph.dart` и `hero_tile_morph_test.dart` из кодовой базы.
4. The Project shall сохранить упоминания спеки `hero-collapse-tile-morph` в `.kiro/specs/` (история не удаляется), но пометить её obsolete через эту спецификацию.

### Requirement 7: TV-perf compliance

**Objective:** Как оператор `rtd2851a`, я хочу 60 fps скролл (≤ 16.7 ms на GPU-кадр), потому что любая регрессия делает экран неприемлемым на referenced железе.

#### Acceptance Criteria

1. The Home Screen shall не использовать `BackdropFilter`, `ImageFilter.blur` или `ShaderMask` в горячем (повторно-перерисовываемом) пути нового вертикального scroll-механизма.
2. The Home Screen shall не использовать `BoxShadow.blurRadius` > 12 (`kSafeShadowBlurMax`) в горячем пути.
3. The Home Screen shall не использовать `AnimatedContainer.height` или `AnimatedContainer.width` для анимации hero — единственное анимируемое свойство при вертикальном скролле это `ScrollPosition.pixels`.
4. While пользователь активно перемещает фокус ↑/↓ или ←/→, the Home Screen shall сохранять avg `GPURasterizer::Draw` ≤ 16.7 ms на reference-устройстве `rtd2851a` (60 fps target).
5. The Home Screen shall сохранять `cacheExtent` (≥ 1500 dp) и `addRepaintBoundaries: true` для основного вертикального scroll-вьюера, чтобы рендер соседних рядов был изолирован.
6. The Home Screen shall не превышать лимит 600 строк на файл (pre-commit hook) — большие компоненты должны быть декомпозированы.

### Requirement 8: macOS desktop parity

**Objective:** Как разработчик, я хочу чтобы поведение на macOS desktop в `flutter run -d macos` было идентично TV-устройству, потому что smoke-сессии и спек-валидация делаются на macOS.

#### Acceptance Criteria

1. When пользователь нажимает клавишу ↑ / ↓ / ← / → на клавиатуре в macOS-сборке, the Home Screen shall обрабатывать события как соответствующие D-pad-нажатия (Vertical/Horizontal Pinned-Slot Invariant работают одинаково).
2. While приложение запущено на macOS desktop, the Home Screen shall сохранять тот же layout (hero как row-0, 4-колоночная сетка на 1920+ dp) что и на TV-устройстве.
3. The Home Screen shall использовать одну и ту же реализацию vertical scroller на обеих платформах (нет platform-specific ветвлений «if macOS then X else Y» для основной логики).

### Requirement 9: Тестируемость Vertical Pinned-Slot Invariant

**Objective:** Как разработчик, я хочу автоматический widget-тест, который защищает контракт от регрессии, по аналогии с уже существующим тестом для горизонтальной оси.

#### Acceptance Criteria

1. The Project shall содержать widget-тест, проверяющий middle-traversal vertical invariant: при переходе focused row `i → i+1 → i+2 → ...` в middle-region, screen-space Y focused row остаётся стабильным с допуском ≤ 1.0 dp.
2. The Project shall содержать widget-тест, проверяющий leading-edge clamp: при focused row index ∈ `[0, verticalPinnedSlotIdx]` вертикальный scrollOffset = 0.
3. The Project shall содержать widget-тест, проверяющий trailing-edge clamp: при focused row на последних `(visibleRowsCount − verticalPinnedSlotIdx)` ряду вертикальный scrollOffset = `maxScrollExtent` (с допуском ≤ 1.0 dp).
4. The Project shall сохранять зелёным существующий горизонтальный `cinema_row_pinned_slot_test.dart` (контракт горизонтального invariant не регрессирует).
5. While CI или локальные тесты запускаются, the Project shall проходить весь корпус home-тестов целиком; счётчик зелёных home-тестов после удаления `hero_tile_morph_test.dart` не должен уменьшаться больше, чем на число тестов внутри удалённого файла.

### Requirement 10: Совместимость с существующими data providers и focus-policy

**Objective:** Как пользователь, я хочу чтобы существующие фичи (carousel, hover preview, остановка timers при потере фокуса, focus traversal policy) продолжали работать, потому что они уже отлажены.

#### Acceptance Criteria

1. The Home Screen shall использовать `featuredNowPlayingProvider` как источник данных для hero (без изменений в data flow).
2. The Home Screen shall использовать `cinemaCategoriesProvider`, `moviesNotifierProvider`, `categoryNotifierProvider` как источники данных для остальных рядов (без изменений в data flow).
3. The Home Screen shall сохранять hover-preview логику для плиток (preview-player запускается через 7 секунд после стабильного фокуса на плитке).
4. The Home Screen shall использовать `WidgetOrderTraversalPolicy` (или эквивалентный детерминированный policy) для D-pad traversal, чтобы порядок «row-0 (hero) → row-1 → ...» был стабилен на macOS и на TV.
5. The Home Screen shall сохранять обработку ESC / BACK на cinematic-экране (как минимум — остановка preview-player, если он активен).

### Requirement 11: Сохранение boot overlay и status bar

**Objective:** Как оператор, я хочу чтобы boot overlay (показ ошибки подключения, retry URL) и часы статус-бара продолжали работать как сейчас, потому что это не часть скролл-механики.

#### Acceptance Criteria

1. While данные ещё загружаются и `_showBootOverlay = true`, the Home Screen shall показывать boot overlay поверх grid, как сейчас.
2. When загрузка успешно завершается, the Home Screen shall плавно затухать boot overlay (420 ms `easeOutCubic`) и передавать фокус на hero (row-0) через `_heroWatchFocusNode` или эквивалентный механизм.
3. If загрузка данных завершается ошибкой, the Home Screen shall показывать сообщение об ошибке и кнопку retry в boot overlay (текущее поведение).
4. The Home Screen shall продолжать обновлять отображение часов в статус-баре раз в 30 секунд (текущее поведение).
