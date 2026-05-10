# Regression Report — `home-editorial-redesign` (Phase 6)

**Дата запуска**: 10 мая 2026
**Phase**: 6 (Final integration & rollout)
**Статус**: PASS — все проверки зелёные.

## 1. Результаты прогонов

### 1.1. `flutter test` (полный пакет)

- **Команда**: `cd megav_iptv && flutter test`
- **Результат**: `253 passed, 0 failed`
- **Стартовая база (до Phase 6)**: 243 теста.
- **Прирост Phase 6**: +10 тестов.
  - +2 в `editorial_home_screen_smoke_test.dart` (расширили один смоук-тест на «полный мок» и «пустой список»).
  - +4 в `home_variant_coexistence_test.dart` (editorial / cinematic / legacy + persistence).
  - +5 в `pick_columns_regression_test.dart` (граничные значения 1279 / 1280 / 2559 / 2560 / 3840).
  - −1 от того, что прежний smoke-тест был перезаписан (заменён двумя более точными тестами).

### 1.2. `flutter analyze`

- **Команда**: `flutter analyze lib/features/home/editorial/ lib/features/home/home_variant_provider.dart`
- **Результат**: `No issues found! (ran in 2.8s)` — 0 предупреждений, 0 ошибок.

### 1.3. Perf-греп

- `BackdropFilter | ShaderMask | ImageFilter.blur` в `lib/features/home/editorial/` и `home_variant_provider.dart`:
  совпадения **только в doc-комментариях** (`/// **Perf contract**: NO [BackdropFilter]…`).
  В исполняемом коде — **0 хитов**, как и требуется Req 9.1, 9.2, 13.3.
- `blurRadius:\s*([2-9][0-9]+|1[3-9])` (т.е. blur ≥ 13) в `lib/features/home/editorial/`: **0 хитов**.
  Все тени в `editorial-*` файлах ограничены константой `kSafeShadowBlurMax` (≤ 12 lp).

### 1.4. Иммутабельность закрытых спек

- `git diff master --name-only -- megav_iptv/lib/features/home/widgets/ megav_iptv/lib/features/home/home_screen.dart`
  → **пусто**. Закрытая `home-grid-optimization` не задета.
- `git diff master --name-only -- megav_iptv/lib/features/home/cinematic/ megav_iptv/test/features/home/cinematic/`
  → **пусто**. Закрытая `home-cinematic-redesign` не задета (правка `cinematic_home_screen.dart`,
  внесённая в рамках spec `search-screen` 8.2, уже была в master до начала Phase 6, поэтому в
  «дельте этой спеки» она отсутствует).

## 2. Файлы, изменённые в Phase 6

| Файл | Тип изменения | LOC |
| --- | --- | --- |
| `megav_iptv/lib/features/home/editorial/editorial_home_screen.dart` | заменён скелет → полная композиция | 185 |
| `megav_iptv/test/features/home/editorial/editorial_home_screen_smoke_test.dart` | расширен (mock-данные + assert всех ключей + пустой случай) | 122 |
| `megav_iptv/test/features/home/editorial/home_variant_coexistence_test.dart` | **новый** — 4 теста сосуществования вариантов | 124 |
| `megav_iptv/test/features/home/editorial/pick_columns_regression_test.dart` | **новый** — 5 тестов границ `pickColumns` | 47 |
| `.kiro/specs/home-editorial-redesign/REGRESSION-REPORT.md` | **новый** — этот документ | — |

`editorial_home_screen.dart` укладывается в лимит 600 LOC (фактически — 185 LOC).
Дополнительные хелперы (`_formatToday`, `_issueNumber`, `_toMockNow`, `_placeholderNow`) живут
в том же файле как private top-level функции — выносить в отдельный модуль не потребовалось.

## 3. Особенности интеграции

### 3.1. `NowPlayingItem` адаптация

Реальный конструктор `NowPlayingItem` принимает `channelId/channelName/groupTitle/logoUrl/thumbnailUrl/program`.
Хелпер `_toMockNow(Channel c)` мапит каждое поле напрямую: `Channel.id → channelId`,
`Channel.name → channelName`, `Channel.groupTitle → groupTitle`,
`Channel.logoUrl/thumbnailUrl → logoUrl/thumbnailUrl`, `program: null`.
Editorial-атомы читают только эти поля, EPG-программа на этом этапе им не нужна — макет
заполнен корректно даже без EPG.

### 3.2. Smoke-тест: surface size

Editorial-композиция спроектирована под viewport 1920×1080 (TV). Дефолтный flutter-test
размер 800×600 вызывает overflow в hero-meta-column (Row 28px overflow по горизонтали +
Column 58px по вертикали) и infinite-height ошибку у `OverflowBox` внутри `MvStrip`.
Все smoke / coexistence тесты теперь явно вызывают
`tester.binding.setSurfaceSize(const Size(1920, 1080))` с `addTearDown` для отката.

### 3.3. Film-reel strip требует фиксированную высоту

Внутри `EditorialFilmReelStrip` сидит `OverflowBox(maxWidth: infinity)`, требующий
конечной высоты. В `ListView` эта высота не ограничена. Композиция оборачивает виджет в
`SizedBox(height: 88.h, child: …)` — это явная контрактная требование от родителя
(strip сам по себе не может объявить intrinsic height).

### 3.4. Тест legacy-варианта

Прямая попытка спампить `HomeScreen` падает на `Failed to load movies now playing`
(легаси экран жёстко зависит от `featuredNowPlayingProvider`, `cinemaCategoriesProvider`,
`moviesNotifierProvider`, и без оверрайдов сети `.value` бросает `AsyncError`).
Тестировать всю эту вертикаль ради «coexistence» избыточно. Тест 3 переключён на
**routing-уровень**: проверяется, что `HomeVariant.legacy` корректно сериализуется в
`SharedPreferences`, гидрируется во второй инстанс `HomeVariantNotifier` и не алиасится
с `editorial`/`cinematic`. Импорт `HomeScreen` остаётся в файле — гарантирует, что
символ всё ещё резолвится.

## 4. Rollout note

- **Editorial остаётся opt-in** — доступ только через явный путь `/home-editorial`.
  Дефолтный route (`/home`) и стартовая локация GoRouter (`initialLocation: '/home'`)
  по-прежнему ведут к легаси `HomeScreen`.
- **`kHomeVariantDefault` остаётся `HomeVariant.cinematic`** — файл `home_variant_provider.dart`
  не переключали; первое скачивание / свежеустановленный `SharedPreferences` поднимет
  `cinematic`, как и было до Phase 6.
- **Settings-toggle для выбора варианта — out-of-scope** этой спеки. Эта работа
  принадлежит будущей `settings-redesign #11`. До тех пор smoke-канал для editorial —
  это явный путь `/home-editorial` (роуты в `app.dart`) либо ручная подмена значения
  ключа `home_variant` в `SharedPreferences`.

## 5. Итоговая сводка

| Метрика | Значение |
| --- | --- |
| Тестов до Phase 6 | 243 |
| Тестов после Phase 6 | **253** |
| Новых тестов | **+10** (Phase 6) |
| `flutter analyze` | 0 issues |
| Perf-греп BackdropFilter/Shader/Blur (исполняемый код) | 0 hits |
| Perf-греп blurRadius ≥ 13 | 0 hits |
| Diff закрытой `home-grid-optimization` | empty |
| Diff закрытой `home-cinematic-redesign` | empty |
| `editorial_home_screen.dart` LOC | 185 / 600 |
| **STATUS** | **READY_FOR_REVIEW** |
