# Requirements Document

## Introduction

Главная сетка `MegaV-IPTV` после закрытия спека `home-grid-optimization` (commit `e78e84c`) визуально и поведенчески корректна, но имеет два класса остаточных недостатков, которые видны на референсном TV-боксе (`192.168.100.8:5555`):

1. **Визуальная резкость** правого края ряда — частично-видимая 4-я плитка обрезается прямой линией, без затухания.
2. **Перформанс-долг** — performance overlay при скролле показывает `avg 20.3 ms/frame, max 34.2 ms/frame`, что выше целевого 16.7 мс бюджета 60 fps.

Этот спек закрывает оба класса минимально-инвазивными правками: ShaderMask для fade-edge, `Visibility` обёртка для отключения билда невидимого `_buildFullOverlay`, и косметический фикс bottom-padding в compact-overlay. Никакого расширения публичного API виджетов; ни одного из 17 существующих тестов не должно сломаться.

Целевой пользователь — оператор приложения, тестирующий вживую на TV-боксе. Качество приёмки определяется (a) визуальным сравнением `baseline_clean.png` ↔ `after_clean.png`, (b) численным сравнением `baseline_perf_overlay.png` ↔ `after_perf_overlay.png`.

## Boundary Context

- **In scope**:
  - Визуальное затухание правого края горизонтального ряда плиток.
  - Управление условным билдом `_buildFullOverlay` в `CinemaCard` (build только когда плитка в фокусе или в процессе fade-out).
  - Незначительная подстройка нижнего padding'а в compact-строке `CinemaCard` (где находится имя канала).
  - Расширение `_grid_tokens.dart` одной константой (`fadeEdgeFraction`).
  - Авто-тесты на новое поведение: присутствие fade-маски в дереве ряда; отсутствие билда полного overlay у нефокусированной карточки.
  - After-снапшоты с TV (clean + perf overlay) для приёмочного сравнения.
- **Out of scope**:
  - Любые изменения в HeroSection, BootOverlay, плеере, EPG, sidebar.
  - Замена `Image.network` на дисковый кэш (`CachedNetworkImage` или собственный).
  - `RepaintBoundary` хирургия и `CustomPainter` для прогресс-бара.
  - Изменения в data-providers, моделях, app_colors.
  - Срезание постера сверху на macOS-сборке — на TV не воспроизводится.
- **Adjacent expectations**:
  - `home-grid-optimization` спек уже закрыт и не должен быть изменён, кроме добавления одной константы в `_grid_tokens.dart`.
  - `FastScrollDetector` и его API остаются read-only.
  - `app_colors.dart` остаётся read-only.

## Requirements

### Requirement 1: Затухание правого края ряда

**Objective:** Как пользователь TV, я хочу, чтобы частично-видимая плитка справа плавно «уходила» в темноту, а не обрезалась прямой линией, чтобы интерфейс выглядел как у эталонных TV-приложений.

#### Acceptance Criteria

1. While a horizontal row of tiles is rendered on the home screen, the Home Grid shall apply a visual fade-out gradient to the right edge of that row's viewport.
2. The fade-out gradient shall span approximately 5% of the row's horizontal width (configurable via a single token).
3. While the row is rendered, the Home Grid shall NOT apply a fade-out gradient to the left edge of the row.
4. While a tile is partially visible at the right edge of the row, the Home Grid shall render that tile with progressively increasing transparency from its leading (visible) side toward its trailing (off-screen) side.
5. The Home Grid shall preserve all existing tile content, focus, scroll, and animation behavior unchanged when the fade-out is active.

### Requirement 2: Условный билд полного overlay у неактивной плитки

**Objective:** Как пользователь, я хочу, чтобы интерфейс работал плавнее, прекратив тратить ресурсы на построение невидимого контента у неактивных плиток.

#### Acceptance Criteria

1. While a tile in the Home Grid is not focused and has not been focused within the last 150 milliseconds, the Home Grid shall NOT include the full-overlay subtree (rating, age-rating, genre emoji, programme title, year, category, progress bar) in its rendered widget tree.
2. When a tile receives focus, the Home Grid shall include the full-overlay subtree in the rendered widget tree before the focus animation completes, so that the fade-in defined by Requirement 6 of the closed `home-grid-optimization` spec remains visible to the user.
3. When a tile loses focus, the Home Grid shall keep the full-overlay subtree present in the widget tree until the fade-out animation completes (approximately 150 milliseconds), and only then remove it.
4. The Home Grid shall preserve the channel name, channel logo, and LIVE indicator in the compact overlay regardless of focus state, exactly as required by the closed `home-grid-optimization` spec.

### Requirement 3: Компактная строка канала не упирается в нижний край

**Objective:** Как пользователь, я хочу, чтобы текст имени канала в нижней строке плитки не был визуально прижат к самому краю карточки.

#### Acceptance Criteria

1. The Home Grid shall render the channel name in the compact overlay with a bottom padding that visually separates the text from the lower edge of the tile.
2. The bottom padding shall be at least 6 logical pixels.
3. The Home Grid shall preserve the existing channel-name typography (font, weight, color) without changes.

### Requirement 4: Производительность на референсном устройстве при скролле

**Objective:** Как оператор, тестирующий приложение на TV-боксе, я хочу видеть в performance overlay, что средняя длительность кадра при скролле сетки укладывается в бюджет 60 fps.

#### Acceptance Criteria

1. While the user actively scrolls a row in the Home Grid on the reference TV device with a Flutter profile build and the performance overlay enabled, the GPU thread average frame time shown by the overlay shall be at or below 16.7 milliseconds.
2. While the user actively scrolls a row in the Home Grid on the reference TV device with a Flutter profile build, the GPU thread maximum (peak) frame time shown by the overlay shall be at or below 25 milliseconds.
3. If the reference TV device cannot achieve the average target in (1) due to hardware limitations after this spec's changes are applied, the operator shall record the residual gap (delta to 16.7 ms) and the performance overlay screenshot in the spec's `snapshots/` directory, and the spec shall close with the residual gap explicitly documented as out of scope for further work.
4. The Home Grid shall not introduce continuous redraws while the home screen is idle (no remote input).

### Requirement 5: Регрессионная безопасность

**Objective:** Как оператор, я хочу быть уверен, что изменения этого спека не сломают существующее поведение, проверенное в закрытом спеке `home-grid-optimization`.

#### Acceptance Criteria

1. The Home Grid shall preserve the public widget API of `CinemaCard` and `CinemaRow` exactly as defined at commit `e78e84c` (no parameter additions, removals, or renames; no changes to existing parameter types).
2. While the Home Grid is rendered, all 17 existing automated tests under `test/features/home/widgets/` shall continue to pass without modification.
3. The Home Grid shall preserve the `wrapAround` parameter, the pagination trigger, the leading-edge scroll behavior, the 400-millisecond focus debounce, the FastScrollDetector integration, the LIVE indicator, the chevron buttons, and the focused-row title highlight exactly as implemented at commit `e78e84c`.

### Requirement 6: Приёмочные снапшоты для сравнения

**Objective:** Как оператор, я хочу видеть наглядное визуальное и численное сравнение «до» и «после», чтобы подтвердить эффект изменений.

#### Acceptance Criteria

1. While the spec implementation is being verified on the reference TV device, the operator shall capture an "after" clean screenshot (without performance overlay) into `.kiro/specs/home-grid-visual-polish/snapshots/after_clean.png`.
2. While the spec implementation is being verified on the reference TV device, the operator shall capture an "after" screenshot with the performance overlay enabled and showing the GPU thread frame time during a scroll session into `.kiro/specs/home-grid-visual-polish/snapshots/after_perf_overlay.png`.
3. The spec shall be considered ready for closure only after both `after_clean.png` and `after_perf_overlay.png` exist on disk and have been reviewed against the corresponding baseline files.
