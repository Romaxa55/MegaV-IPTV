# Brief: home-grid-optimization

## Problem
Главная сетка каналов на главном экране (`HomeScreen`) ощутимо тормозит на реальных Android TV-боксах: при скролле и переключении фокуса между плитками заметны лаги, интерфейс ощущается «перегруженным». Пользователь — владелец проекта, тестирует вживую на TV-боксе подключённом по ADB (`192.168.100.8:5555`).

Корневые причины (выявлены в ходе ревизии `cinema_row.dart` и `cinema_card.dart` + сравнения с эталонами Netflix Android TV / AndroidX Leanback):
1. **Дорогая `boxShadow` с `blurRadius: 50`** при фокусе карточки — самая тяжёлая операция в кадре на TV-GPU калибра Mali-G31/G52. Существующая ветка `isLowPower` срабатывает не на всех TV-боксах.
2. **Двойная implicit-анимация** `AnimatedScale` + `AnimatedContainer` с длительностью 200 мс одновременно меняет width, border, boxShadow — вызывает re-layout всего поддерева карточки.
3. **Expanded-режим карточки**: активная плитка раздувается до `narrowW × 2`, что триггерит **re-layout всего ListView** (соседи сдвигаются) на каждый шаг фокуса по горизонтали.
4. **Перегруженный Stack карточки**: 11+ декорированных Container'ов на каждую неактивную плитку (LIVE-бейдж со своими тенями, рейтинг, возрастной рейтинг, эмодзи жанра, прогресс-бар, год, название программы, имя канала, логотип канала). На экране одновременно ~5–6 видимых карточек = 60+ декорированных контейнеров.
5. **Hover-эффекты запускаются мгновенно** при focus-change, что при быстром скролле вызывает «дрожание интерфейса».

## Current State
- `lib/features/home/widgets/cinema_row.dart` (461 строка): горизонтальный `ListView.builder` с переменной шириной плиток (`narrowW` для неактивных, `fullW = narrowW × 2` для активной), focus-handling через `Focus`/`MouseRegion`, кастомный левый-выровненный скролл `_scrollFocusedCardToLeadingEdge`, `cacheExtent: 1500.w`, `Curves.easeOut` для скролла длительностью 280 мс.
- `lib/features/home/widgets/cinema_card.dart` (471 строка): `AnimatedScale` (200 мс) + `AnimatedContainer` (200 мс), `boxShadow` с blur=50/spread=−12 при фокусе, `Stack` из 5 слоёв (постер + градиент + оверлей с 7 элементами), псевдо-данные (`_pseudoRating`, `_pseudoAgeRating`, `_genreEmoji`) пересчитываются на каждый build.
- `lib/features/home/home_screen.dart`: предзагружает 28 × N_категорий + 28 для movies + featured = ~200+ изображений параллельно перед снятием boot-overlay (отдельная история, в этот spec не входит).

Уже сделанные хорошие вещи (сохраняем):
- `RepaintBoundaries` в ListView.builder включены.
- `cacheExtent: 1500.w` — широкий буфер рендера.
- `FastScrollDetector` отключает scale-анимации во время быстрого скролла (после коммита `d12285e`).
- Прекеш постеров через `precacheImage` после ребилда ряда.
- `gaplessPlayback: true` + `cacheWidth: 400` на постерах.
- Левое выравнивание активной плитки через `_scrollFocusedCardToLeadingEdge` (Netflix-стайл, явный комментарий в коде).

## Desired Outcome
1. Плавный скролл главной сетки на референсном TV-боксе (`192.168.100.8`) — субъективно «без лагов и подёргиваний» при удержании стрелки на пульте.
2. **Фиксированный левый край** ряда: первая плитка всегда на одном горизонтальном смещении (без «болтанки» от expanded-режима).
3. **Адаптивно «до 4 плиток»** в видимой области: 3 на узких экранах, 4 на FullHD, 5 на 4K. Ширина плитки = `(screenW − padding) / N − gap × (N−1)`, где N выбирается по диапазону ширины экрана.
4. Активная плитка визуально выделяется через **`Transform.scale(1.08)` + рамку**, без раздувания ширины и без relayout соседей.
5. Hover-эффекты (изменение вида карточки, расширение оверлея) запускаются с **debounce 400 мс** — при быстром пролистывании ничего не «вспыхивает».
6. Карточка визуально облегчена: у неактивных плиток показываются **только постер + минимальный bottom-overlay** (название канала, LIVE-индикатор если live). Полный набор бейджей (рейтинг, возрастной рейтинг, эмодзи жанра, прогресс-бар, год, название программы) показывается **только у активной плитки** через fade-in 150 мс.
7. Тайминги анимаций приведены к Leanback-эталонам: card animation 150 мс (вместо 200), скролл `Curves.fastOutSlowIn` (вместо `Curves.easeOut`).
8. Псевдо-данные кэшированы через `late final` (вычисление один раз на инстанс карточки, а не на каждый build).

## Approach
**Подход 2 «Сбалансированный»** — выбран среди трёх рассмотренных вариантов.

**Что меняем в `cinema_row.dart`**:
- Удаляем дуальный `narrowW`/`fullW` и логику `_focusedCol`-зависимой ширины. Все плитки одной ширины: `cardW = (screenW − 2 × horizontalPadding − (N−1) × gap) / N`, где `N = pickColumns(screenW)`.
- `pickColumns(screenW)`: `screenW < 1280 → 3`, `1280 ≤ screenW < 1920 → 4`, `screenW ≥ 1920 → 4` для FullHD, `screenW ≥ 2560 → 5` для 4K (точные пороги уточняем на этапе design).
- `gap` снижаем с 24 до 16 (Leanback использует 8dp; компромисс 16 — баланс между плотностью и читаемостью).
- `_scrollFocusedCardToLeadingEdge` сохраняется, но упрощается: все плитки одной ширины, поэтому offset = `index × (cardW + gap)`.
- `Curves.easeOut → Curves.fastOutSlowIn` в обоих местах (`_scrollBy`, `_scrollFocusedCardToLeadingEdge`).
- Длительность скролла 280 мс → 250 мс (Leanback `lb_browse_rows_anim_duration`).
- Добавляем `_hoverDebounceTimer` (400 мс) перед коллбэком `widget.onItemFocus?.call` и перед триггером раскрытия overlay в карточке.

**Что меняем в `cinema_card.dart`**:
- `AnimatedScale.duration` 200 → 150 мс.
- `AnimatedContainer` остаётся, но **не анимирует width** (width теперь фиксирован). Анимирует только border и boxShadow.
- `boxShadow.blurRadius`: 50 → 12 (или полный отказ от тени, замена на яркую рамку 3px). Решаем на этапе design после теста на реальном TV.
- `_buildOverlay` разделяется на `_buildOverlayCompact()` (всегда видимый, для неактивных) и `_buildOverlayFull()` (только для `widget.isFocused == true`, fade-in через `AnimatedOpacity` 150 мс).
- `_buildOverlayCompact`: только нижняя строка с названием канала + LIVE-индикатор если live.
- `_buildOverlayFull`: всё что есть сейчас (рейтинг, возрастной рейтинг, эмодзи жанра, прогресс-бар, год, название программы).
- `_pseudoRating()` / `_pseudoAgeRating()` / `_genreEmoji()` → `late final String _ratingCached = _pseudoRating();` и т.д.

## Scope
- **In**:
  - Рефакторинг `lib/features/home/widgets/cinema_row.dart` (модель сетки, тайминги, debounce).
  - Рефакторинг `lib/features/home/widgets/cinema_card.dart` (анимации, тени, разделение оверлея, кэш псевдо-данных).
  - Возможные мелкие правки в `home_screen.dart` если изменится контракт `onItemFocus` (например, добавится передача debounced-флага). Минимизировать.
  - Self-verification на реальном TV-боксе через `flutter run` + ADB (`192.168.100.8:5555`).
  - Сохранение всех существующих особенностей: `wrapAround` для `live-movies`, `loadMore` пагинация, левое выравнивание активной плитки, `FastScrollDetector` интеграция.
- **Out**:
  - HeroSection (большой баннер сверху).
  - HomeBootOverlay и логика прекеша 200+ изображений.
  - Preview-видео при наведении (`_startPreview` / `_stopPreview` в home_screen).
  - Player и его OSD.
  - EPG и боковое меню каналов в плеере.
  - Замена `Image.network` на `CachedNetworkImage` (диск-кеш) — отдельный spec при необходимости.
  - `RepaintBoundary` гигиена и `CustomPainter` для прогресс-бара — отдельный spec при необходимости (Подход 3, отложен).
  - Удаление псевдо-данных (`_pseudoRating` и пр.) — это технический долг, не оптимизация рендера. Отдельная задача.

## Boundary Candidates
- **Layout-модель сетки** (`cinema_row.dart`): сколько плиток, какой ширины, как считается, как ведёт себя при скролле и фокусе.
- **Визуальная карточка** (`cinema_card.dart`): постер, оверлей, тени, анимации, бейджи.
- **Тайминги и debounce** (общие константы): пороги переключения колонок, длительности анимаций, задержка debounce. Кандидат на отдельный файл `lib/features/home/widgets/_grid_timings.dart` или extension в `app_theme.dart`.
- **Контракт hover-callback** (`onItemFocus`): сейчас вызывается мгновенно, должен учитывать debounce. Возможно, превратится из `void Function(NowPlayingItem?)` в нечто с явным `isStable` флагом.

## Out of Boundary
- Оптимизация бэкенда / API / прекеша вне ряда.
- Замена движка плеера и его взаимодействие с превью на главном экране.
- Левое меню категорий (на сейчас его нет, рассматриваем только горизонтальные ряды).
- Удаление функциональности (псевдо-данные, бейджи) — только перекомпоновка их видимости.
- Бэкенд EPG, парсинг плейлистов, IPTV-протоколы.

## Upstream / Downstream
- **Upstream**:
  - `lib/core/playlist/models/now_playing.dart` — модель `NowPlayingItem`, читается as-is, не меняется.
  - `lib/core/providers/providers.dart` — `categoryNotifierProvider`, `moviesNotifierProvider`, читаются as-is.
  - `lib/core/ui/utils/fast_scroll_detector.dart` — интеграция сохраняется, debounce **не заменяет** FastScrollDetector, а дополняет его (FastScroll отключает scale во время резкого скролла, debounce задерживает heavy-overlay при медленной навигации).
  - `lib/core/theme/app_colors.dart`, `lib/core/theme/app_theme.dart` — берём цвета и токены, не меняем.
- **Downstream**:
  - `lib/features/home/home_screen.dart` — потребитель `CategoryRowWrapper`/`CinemaRow`. Контракт `onItemTap`/`onItemFocus` должен остаться совместимым, либо изменения минимальны и адаптируются на стороне `home_screen`.
  - Будущий spec про оптимизацию загрузки изображений (кэш, диск, lazy) — наследует более чистую модель карточки.
  - Будущий spec про OSD плеера — может позаимствовать debounce-паттерн отсюда.

## Existing Spec Touchpoints
- **Extends**: нет (это первый spec в проекте).
- **Adjacent**: нет (нет других специй).

## Constraints
- **Stack**: Flutter (текущая версия из проекта), Riverpod (из `pubspec.yaml`), `flutter_screenutil` для adaptive sizing. Ничего нового не добавляем.
- **Платформа**: Android TV. Целевое устройство для приёмки — реальный TV-бокс пользователя по ADB `192.168.100.8:5555`. Тестирование iOS/Web не требуется (но и не должно сломаться — Flutter код сохраняет cross-platform совместимость).
- **Совместимость**: не ломать существующие фичи — `live-movies` `wrapAround`, пагинация через `onLoadMore`, навигация пультом (D-pad), интеграция с `FastScrollDetector`.
- **Тестирование**: `flutter run` на TV-боксе. Глазная проверка плавности и фокуса. Юнит-тесты желательны для функции `pickColumns(screenW)` (граничные значения), но не блокирующие.
- **Без новых зависимостей** в `pubspec.yaml` (этот spec).
- **Принцип**: «не оптимизировать вслепую» — после реализации Подхода 2 проверяем на реальном TV. Если плавность достаточна — закрываем работу. Если нет — открываем отдельный spec на Подход 3 (CachedNetworkImage, RepaintBoundary, CustomPainter).
