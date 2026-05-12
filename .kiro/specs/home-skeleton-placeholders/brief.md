# Brief: home-skeleton-placeholders

## Problem

Сейчас при первом запуске Cinematic-экрана юзер ждёт **boot-overlay**
до тех пор пока полный bootstrap-fetch не пройдёт:
- `cinemaCategoriesProvider.future`
- `featuredNowPlayingProvider.future`
- `moviesNotifierProvider.waitForInit()`
- `categoryNotifierProvider(cat.name).waitForInit()` для **каждой** category

(см. `cinematic_home_screen.dart:_runHomeBootstrap` строки 168–204).

Плюс **eager precache** до `precachePerRow = 28` изображений × N rows.
На реальном Realtek `rtd2851a` это секунды чёрного экрана.

Пользователь сказал словесно (2026-05-12): «preloading можно как-то
сокращать убирать, лучше плейсхолдеры показывать пока идёт загрузка
так интереснее».

## Current State

- `cinematic_home_screen.dart:74` — `bool _showBootOverlay = true` →
  пока bootstrap не финиширует, hero+rails не видны.
- `cinematic_home_screen.dart:168–204` — `_runHomeBootstrap` ждёт
  всех categories sequentially: `for (cat in categories) await
  categoryNotifierProvider(cat.name).waitForInit()`.
- `cinematic_home_screen.dart:180–196` — `precacheImage` для top-28
  каждой row через `Future.wait` (network round-trip).
- `home_boot_overlay.dart` — full-screen overlay с brand + spinner +
  optional baseUrl prompt.
- `_cinema_row_loading.dart` — `CinemaRowLoadingPlaceholder` уже
  существует, но используется только если `asyncData.isLoading &&
  !asyncData.hasValue` (см. `cinema_row.dart:71`). На первом запуске
  он не виден из-за boot-overlay.

## Desired Outcome

1. Hero и rails **появляются сразу** после первой запрошенной
   категории (или вообще параллельно с запросом — со скелетоном).
2. Boot-overlay показывается **только** если есть ошибка
   (`_bootError != null`) или baseUrl пуст (нужен prompt).
3. На каждой row, пока данные грузятся — `CinemaRowLoadingPlaceholder`
   (skeleton tiles) виден сразу.
4. Hero без данных — skeleton (placeholder backdrop + skeleton text
   blocks).
5. `precacheImage` уходит из критического пути bootstrap. Делается
   **lazily** через `IntersectionObserver`-аналог (whenVisible) или
   просто через `addPostFrameCallback` без `await`.
6. Sequential `await` цикл по categories → заменяется на параллель
   (`Future.wait`) ИЛИ убирается совсем — `Riverpod` уже async, провайдеры
   сами триггерят rebuild.

## Approach

**Skeleton-first**: убираем `_showBootOverlay` гейт. Экран сразу
рисует `UnifiedHomeGridScroller` со skeleton-hero (row-0) + skeleton-rows.
По мере того как соответствующий provider возвращает данные —
каждая row сама переключается с skeleton на content (через `ref.watch`).
`_runHomeBootstrap` сжимается до thin error-watcher, без eager precache.

## Scope

### In
- `cinematic_home_screen.dart`: убрать `_showBootOverlay`,
  `_runHomeBootstrap` eager-await loop, `precachePerRow=28` eager
  precache.
- Новый `HeroSkeleton` widget — placeholder для hero пока
  `featuredNowPlayingProvider` ещё не выдал данные.
- `cinema_row.dart` / `_cinema_row_loading.dart`: убедиться что
  `CinemaRowLoadingPlaceholder` корректно работает при пустых items.
- `home_boot_overlay.dart`: переименовать в `HomeBootErrorOverlay` и
  показывать только при наличии error или missing baseUrl.
- Lazy `precacheImage` на focus или scroll (debounced).

### Out
- Player loading (отдельный spec).
- Detail screen skeleton (закрытый spec, не трогаем).
- Backend changes — API остаётся как было.

## Boundary Candidates
- `HomeBootController` — выносим bootstrap-логику из StatefulWidget
  в notifier (можно ProviderState или просто mixin).
- `HeroSkeleton`, `CinemaRowSkeleton` (уже существует) — atoms-level.
- `_HomeBootErrorOverlay` — переименование + сужение scope.

## Out of Boundary
- Изменение data layer (providers, API client) — остаётся как есть.
- Player initialization — отдельный spec.

## Upstream / Downstream

**Upstream**:
- `home-unified-grid-scroll` — оперируем внутри `CinematicHomeScreen`
  который уже использует `UnifiedHomeGridScroller`.
- `home-grid-stability-pass` — `CinemaRowLoadingPlaceholder` уже
  готов как atom.
- `design-system-atoms` — skeleton-style визуал (можно re-use
  существующих Poster placeholder if any).

**Downstream**: следующие специи для других экранов могут
переиспользовать паттерн «skeleton + lazy precache».

## Constraints
- TV-perf: skeleton placeholders не должны использовать
  `BackdropFilter`/`ShaderMask`. Только `ColoredBox` + `DecoratedBox`
  + `AnimatedOpacity` (если нужен shimmer — отдельная задача).
- Realtek `rtd2851a`: первый кадр на экране должен появиться за
  ≤ 500 ms от старта приложения.
- Russian-first content.

## Existing Spec Touchpoints
- **Extends**: `home-unified-grid-scroll` (новые changes inside
  CinematicHomeScreen).
- **Adjacent**: `home-cinematic-redesign` (visual layer — НЕ
  открываем, но re-use atoms).

## Direct Implementation Candidates
- Lazy `precacheImage` через `onItemFocus` callback — это уже почти
  реализовано в `CategoryRowWrapper._schedulePrecache`, нужно
  убедиться что оно работает после убирания eager-loop.
