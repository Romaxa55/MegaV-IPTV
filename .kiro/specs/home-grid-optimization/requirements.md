# Requirements Document

## Introduction

Главный экран MegaV-IPTV отображает горизонтально-скроллируемые ряды каналов («сетку») над hero-баннером. На реальных Android TV-боксах текущая реализация работает с заметными лагами и ощущается визуально перегруженной. Этот спек определяет требования к **облегчённой и плавной модели сетки**: фиксированная адаптивная ширина плиток без раздувания активной, упрощённое визуальное наполнение неактивных плиток, отзывчивые анимации с короткими таймингами, и debounce hover-эффектов для устранения «мерцания» при быстром скролле пультом.

Целевой пользователь — человек, управляющий приложением **только пультом** на Android TV-боксе. Качество приёмки определяется субъективной оценкой плавности на референсном устройстве (TV-бокс пользователя по ADB `192.168.100.8:5555`), а также измеримыми поведенческими критериями (фиксированный левый край, число видимых плиток, тайминги).

Полный контекст подхода и архитектурных решений — в `brief.md`.

## Boundary Context

- **In scope**:
  - Поведение и визуальное наполнение горизонтальных рядов главного экрана, включая ряды категорий и специальный ряд «Фильмы в эфире» (`live-movies`).
  - Поведение фокуса D-pad внутри ряда: переход между плитками, выравнивание активной плитки, debounce hover-эффектов.
  - Анимации появления фокуса на плитке и анимации горизонтального скролла ряда.
  - Видимость и состав информации на плитке в зависимости от того, активна она или нет.
  - Сохранение существующих особенностей рядов: циклическое поведение `live-movies` (`wrapAround`), ленивая подгрузка через пагинацию (`loadMore`), интеграция с детектором быстрого скролла.
- **Out of scope**:
  - Hero-баннер сверху главного экрана и его поведение.
  - Boot-overlay и логика прекеша изображений на старте.
  - Видео-предпросмотр канала при удержании фокуса (preview-плеер в hero).
  - Плеер и его OSD, навигация между каналами в плеере, EPG-оверлеи.
  - Замена бэкенда загрузки изображений на дисковый кэш.
  - Удаление любой пользовательской функциональности с плитки (рейтинг, возрастной рейтинг, эмодзи жанра, прогресс-бар) — только перекомпоновка их видимости.
- **Adjacent expectations**:
  - Источники данных рядов (`categoryNotifierProvider`, `moviesNotifierProvider`, `featuredNowPlayingProvider`) предоставляют корректные списки `NowPlayingItem` — этот спек ничего в них не меняет.
  - Hero-баннер потребляет события «плитка стала активной» через существующий callback. Контракт callback должен сохраниться или измениться с минимальной адаптацией на стороне Hero.
  - Детектор быстрого скролла продолжает работать как раньше: при стремительной навигации по пульту он отключает дорогие анимации; debounce hover-эффектов **дополняет** этот механизм, а не заменяет.

## Requirements

### Requirement 1: Адаптивная фиксированная ширина плиток

**Objective:** Как пользователь Android TV, я хочу видеть в каждом ряду ровно столько плиток, сколько разумно умещается на моём экране — без раздувания и сжатия отдельных плиток при перемещении фокуса, чтобы интерфейс ощущался стабильным и предсказуемым.

#### Acceptance Criteria

1. While the home grid is rendered on a screen with width below 1280 logical pixels, the Home Grid shall display exactly 3 tiles per row in the visible area.
2. While the home grid is rendered on a screen with width between 1280 and 2559 logical pixels (inclusive), the Home Grid shall display exactly 4 tiles per row in the visible area.
3. While the home grid is rendered on a screen with width 2560 logical pixels or greater, the Home Grid shall display exactly 5 tiles per row in the visible area.
4. The Home Grid shall keep the width of every tile in a row identical, regardless of which tile (if any) currently holds focus.
5. When focus moves between tiles within a row, the Home Grid shall not change the width of any tile.
6. The Home Grid shall align the leading (left) edge of the first visible tile to a fixed horizontal offset from the screen edge that does not change while the user navigates within the row.

### Requirement 2: Левое выравнивание активной плитки при скролле

**Objective:** Как пользователь, перемещающийся по ряду стрелкой вправо, я хочу чтобы текущая активная плитка всегда оказывалась прижатой к левому краю видимой области, чтобы взгляд не «бегал» за центрируемой плиткой.

#### Acceptance Criteria

1. When focus moves to a tile that is not currently the leftmost visible tile in its row, the Home Grid shall scroll the row so that the focused tile becomes the leftmost visible tile.
2. The Home Grid scroll animation that aligns the focused tile to the leading edge shall complete within 250 milliseconds.
3. The Home Grid shall use a deceleration-style easing for the alignment scroll, such that motion starts faster and slows toward the end without overshoot.
4. When focus moves backwards (to an earlier tile already visible at or near the left edge), the Home Grid shall not scroll the row.
5. While the user holds the right arrow on the remote and the row reaches its last tile, the Home Grid shall not loop or scroll past the end (except in rows configured for cyclic behavior — see Requirement 8).

### Requirement 3: Визуальное выделение активной плитки без relayout

**Objective:** Как пользователь, я хочу видеть, какая плитка выбрана в данный момент, при этом без «прыжков» и сдвигов соседних плиток, чтобы навигация ощущалась лёгкой.

#### Acceptance Criteria

1. When a tile receives focus, the Home Grid shall visually emphasize that tile by enlarging it via a transform-only scale animation, without changing the tile's allocated width or the position of neighboring tiles.
2. The scale animation triggered by focus change shall complete within 150 milliseconds.
3. When a tile receives focus, the Home Grid shall display a coloured focus border around the focused tile.
4. When focus leaves a tile, the Home Grid shall animate the tile back to its non-focused state within 150 milliseconds.
5. The Home Grid shall not render a heavy blur shadow around the focused tile that would degrade rendering performance on the reference TV device.
6. While focus is on a tile, the position of every other tile in the row shall remain unchanged compared to the un-focused state of that row.

### Requirement 4: Debounce hover-эффектов при быстром скролле

**Objective:** Как пользователь, удерживающий стрелку на пульте и быстро пролистывающий ряд, я хочу, чтобы интерфейс не «мерцал» дорогими переходами на каждой пролетающей плитке — тяжёлые эффекты должны включаться только когда я остановился.

#### Acceptance Criteria

1. When focus enters a tile and stays on it for at least 400 milliseconds, the Home Grid shall trigger any heavy hover-related side effects (such as expanding the tile's information overlay or notifying the hero banner of the new active item).
2. When focus enters a tile and leaves it before 400 milliseconds elapse, the Home Grid shall not trigger heavy hover-related side effects for that tile.
3. The 150-millisecond focus scale animation defined in Requirement 3 shall start immediately when focus changes, independent of the 400-millisecond debounce.
4. When the fast-scroll detector reports that the user is currently in a fast-scroll state, the Home Grid shall additionally suppress the focus scale animation, completing focus transitions instantly.
5. When the user stops navigating and the fast-scroll detector exits the fast-scroll state, the Home Grid shall resume the normal animated focus behavior on the next focus change.

### Requirement 5: Облегчённое содержимое неактивной плитки

**Objective:** Как пользователь, я хочу видеть на неактивных плитках только самое необходимое — постер и название канала — чтобы ряд воспринимался спокойно и не «кричал» бейджами на каждой плитке.

#### Acceptance Criteria

1. While a tile is not focused, the Home Grid shall render that tile with a compact information overlay containing at minimum the channel name.
2. While a tile is not focused and its current programme has live-broadcast status, the Home Grid shall display a LIVE indicator on that tile.
3. While a tile is not focused, the Home Grid shall not display the rating badge, the age-rating badge, the genre emoji badge, the elapsed/remaining duration row, the broadcast year, or the programme title on that tile.
4. While a tile is not focused, the Home Grid shall keep the channel logo visible on that tile if a logo URL is available.
5. The compact overlay shall not occupy more than approximately one quarter of the tile's height, leaving the poster as the dominant visual element.

### Requirement 6: Полное содержимое активной плитки

**Objective:** Как пользователь, выбравший плитку, я хочу увидеть подробную информацию о канале и программе на этой конкретной плитке, чтобы принять решение «смотреть или нет», не покидая сетку.

#### Acceptance Criteria

1. When a tile becomes focused and remains focused beyond the debounce defined in Requirement 4, the Home Grid shall reveal a full information overlay containing all of: rating badge, age-rating badge, genre emoji badge, programme title, broadcast year (when available), programme category (when available), channel logo and name, and — when the programme is currently live — the elapsed/remaining duration row and progress bar.
2. The full information overlay shall fade in within 150 milliseconds when the debounce condition from Requirement 4 is satisfied.
3. When the tile loses focus, the Home Grid shall fade the full information overlay out within 150 milliseconds and reveal the compact overlay defined in Requirement 5.
4. The Home Grid shall ensure that switching between compact and full overlays does not cause the channel name (which is present in both) to visibly jump, flicker, or re-flow.

### Requirement 7: Тайминги анимаций ряда

**Objective:** Как пользователь TV, я хочу, чтобы все движения в сетке завершались быстро и без «зависания», чтобы интерфейс ощущался мгновенно отзывчивым.

#### Acceptance Criteria

1. The Home Grid shall complete the focus scale animation within 150 milliseconds.
2. The Home Grid shall complete the focus border appearance/disappearance within 150 milliseconds.
3. The Home Grid shall complete the leading-edge scroll alignment within 250 milliseconds.
4. The Home Grid shall complete the full overlay fade-in or fade-out within 150 milliseconds.
5. The Home Grid shall use a deceleration-style easing curve for the leading-edge scroll alignment.
6. The Home Grid shall use a smooth ease-out curve for focus scale and overlay fade animations.

### Requirement 8: Сохранение существующих особенностей рядов

**Objective:** Как пользователь, я хочу, чтобы изменение визуала и навигации не сломало уже работающие особенности — циклический ряд «Фильмы в эфире», подгрузку дополнительных карточек по мере приближения к концу, заголовки рядов с количеством элементов и кнопками-шевронами.

#### Acceptance Criteria

1. While a row is configured with cyclic behavior (specifically the «Фильмы в эфире» row), the Home Grid shall continue to support cyclic navigation as it does today.
2. When focus is within 3 tiles of the end of a paginated row, the Home Grid shall request the next page from the row's data source.
3. The Home Grid shall display the row title above each row, including any leading indicator (such as the red dot before «Фильмы в эфире») and the count of items in the row.
4. The Home Grid shall display chevron buttons (left/right) in the row header that scroll the row horizontally when activated by mouse or pointer.
5. While a row is currently focused (any tile inside it has focus), the Home Grid shall visually emphasize the row title relative to non-focused rows.

### Requirement 9: Производительность на референсном устройстве

**Objective:** Как пользователь, тестирующий приложение на своём Android TV-боксе, я хочу, чтобы скролл и переключение фокуса в сетке ощущались плавно и без рывков на этом устройстве.

#### Acceptance Criteria

1. While the user holds the right arrow on the remote and the Home Grid scrolls through a row, the Home Grid shall maintain visually smooth motion on the reference TV device, without perceptible stutter or frame drops.
2. When the user changes focus rapidly between tiles, the Home Grid shall not introduce visible delays of more than approximately 100 milliseconds between key press and the start of the focus transition.
3. The Home Grid shall not retain focus highlights on tiles that no longer hold logical focus.
4. While the home screen is idle (no input from the user), the Home Grid shall not trigger continuous redraws of tiles caused by always-on heavy effects.
5. The reference test for the success of this requirement shall be a subjective acceptance check performed by the operator on the reference TV device using a real remote control under realistic data volumes (multiple categories with 20+ tiles each).

### Requirement 10: Совместимость с навигацией пультом

**Objective:** Как пользователь с пультом, я хочу, чтобы все клавиши пульта продолжали работать как раньше, без новых неожиданных побочных эффектов.

#### Acceptance Criteria

1. When the user presses the SELECT, ENTER, or game-button-A key on a focused tile, the Home Grid shall invoke the existing «open this channel» action for that tile.
2. When the user presses the right arrow key on the last tile of a non-cyclic row, the Home Grid shall not move focus outside the row and shall not produce visual artifacts.
3. When the user navigates vertically (up/down arrow) between rows, the Home Grid shall preserve the column index where reasonable, so the user lands on a nearby tile rather than always on the first tile of the new row.
4. When the user presses ESC or BACK while a tile is focused, the Home Grid shall delegate the event to the parent screen without consuming it (preserving existing screen-level behavior such as stopping preview).
5. The Home Grid shall continue to deliver focus-change notifications to the parent screen so that the hero banner and any other listeners can react to the new active tile.

### Requirement 11: Отображение состояний загрузки и пустых рядов

**Objective:** Как пользователь, я хочу, чтобы пока ряд грузится или если в нём нет данных, я видел понятный визуал, не вызывающий «дёргания» layout'а.

#### Acceptance Criteria

1. While a row is loading its initial data, the Home Grid shall display a placeholder of the same vertical height as a loaded row.
2. While the placeholder is shown, the Home Grid shall display a series of dim tile-shaped silhouettes consistent with the new fixed-width tile model.
3. If a row finishes loading with zero items and no error, the Home Grid shall hide the row entirely without leaving an empty band.
4. If a row finishes loading with zero items and an error, the Home Grid shall display a short error message in place of the row's tile area.
5. When a previously loaded row receives new data (e.g., via pagination), the Home Grid shall append the new tiles without changing the position of existing tiles or the position of the focused tile.
