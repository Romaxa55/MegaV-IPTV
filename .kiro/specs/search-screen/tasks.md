# Implementation Plan

> Спек: `search-screen`. См. `requirements.md` (12 requirements) и `design.md` (10 components + 1 API extension).
>
> Принципы: **scaffold keyboard layout grid first** (foundation для D-pad-навигации) → **sealed state + controller** → **input + results-grid** → **API extension с backward-compat assertion** → **integration (route + affordance)** → **tests + regression**. Все коммиты атомарные, все 65 существующих тестов остаются зелёными (Req 12.8). API-extension — отдельная task с явной backward-compat verification (Req 8.3, 8.7).
>
> Последовательность чтобы избежать boundary collision: сначала pure-data + sealed types (никто не зависит, не блокирует), потом виджеты с D-pad, потом controller, потом UI integration, потом API. Tests добавляются в task 7.x.

---

## 1. Foundation: keyboard layout grid + sealed key types

- [ ] 1.1 Scaffold 6×6 cyrillic keyboard layout matrix + sealed `KeyboardKey`
  - Создать `megav_iptv/lib/features/search/widgets/keyboard_key.dart`:
    - `enum KeyboardLocale { ru, en }`.
    - `sealed class KeyboardKey { const KeyboardKey(); }`.
    - 4 final подкласса: `Char(String glyph)`, `Space()`, `Backspace()`, `LocaleToggle()`.
  - Создать `megav_iptv/lib/features/search/widgets/keyboard_layouts.dart`:
    - `const List<List<String>> kKeyboardRu` — точно 6×6, рядки из `KB_ROWS`:
      - `['А','Б','В','Г','Д','Е']`
      - `['Ё','Ж','З','И','Й','К']`
      - `['Л','М','Н','О','П','Р']`
      - `['С','Т','У','Ф','Х','Ц']`
      - `['Ч','Ш','Щ','Ъ','Ы','Ь']`
      - `['Э','Ю','Я','SP','BS','LT']` (utility sentinels).
    - `const List<List<String>> kKeyboardEn` — 6×6, A..Z + utility (`['A','B','C','D','E','F']`, …, последний row `['Y','Z','-','SP','BS','LT']` или эквивалент закрывающий 26 латинских + utility).
    - Top-level `List<List<String>> keyboardLayout(KeyboardLocale)` returning matching matrix.
  - Pure const data — никаких imports кроме SDK.
  - Наблюдаемое: `flutter analyze` чисто на обоих файлах; `kKeyboardRu.length == 6 && kKeyboardRu.every((r) => r.length == 6)` верно. Это **first task** scaffolds keyboard layout grid per pipeline convention.
  - _Requirements: 2.1, 2.2, 2.5_
  - _Boundary: keyboard_layouts.dart, keyboard_key.dart_

---

## 2. Sealed UI state + provider scaffolding

- [ ] 2.1 Создать sealed `SearchUiState` + provider hookup
  - Создать `megav_iptv/lib/features/search/widgets/search_state.dart`:
    - `sealed class SearchUiState { const SearchUiState(); String get query; }`.
    - 5 final подклассов: `Idle`, `Loading(query)`, `Empty(query)`, `Error({message, lastQuery})`, `Results({items, total, query, hasMore})`.
    - Const factories на parent class (`SearchUiState.idle()`, etc.).
    - Re-export `searchControllerProvider` placeholder (заглушка: `final searchControllerProvider = ...` будет дополнен в task 3).
  - Импорт `Channel` из `lib/core/playlist/models/channel.dart`.
  - Наблюдаемое: `flutter analyze` чисто; exhaustive switch over `SearchUiState` компилируется без `default:`.
  - _Requirements: 10.1, 10.4, 6.1_
  - _Boundary: search_state.dart_

---

## 3. SearchController с debounce + paging + re-entry guard

- [ ] 3.1 Создать `SearchController` `StateNotifier` + Riverpod provider
  - Создать `megav_iptv/lib/features/search/state/search_controller.dart` с `class SearchController extends StateNotifier<SearchUiState>`:
    - Поля: `ApiClient _api`, `Timer? _debounce`, `bool _inFlight = false`, `String _query = ''`, `int _offset = 0`, `int _total = 0`, `List<Channel> _items = const []`.
    - Метод `onKeyPressed(KeyboardKey)`:
      - `Char(g)` → `_query += g`; `Space()` → `_query += ' '`; `Backspace()` (when query non-empty) → trim last; `Backspace()` empty → return; `LocaleToggle()` → return.
      - В конце вызывает `_scheduleSearch()`.
    - `_scheduleSearch()`: `_debounce?.cancel()`; если `_query.isEmpty` → `_transition(Idle())`, return; иначе `_debounce = Timer(Duration(ms: 350), _runSearch)`.
    - `_runSearch()`: `if (_inFlight) return; _inFlight = true; _transition(Loading(_query))` → `try` `_api.searchChannels(query: _query, limit: 20, offset: 0)` → branch на empty/non-empty/exception → `finally _inFlight = false`.
    - `requestNextPage()`: guard на `_inFlight` + `_offset >= _total`; иначе append page и обновляет state с `hasMore = _offset < _total`. Failure: keep items, no state replace (Req 7.5).
    - `_transition(SearchUiState next)`: `if (!mounted) return; state = next;`. Single mutation point per Req 10.2.
    - `dispose()`: cancel `_debounce` then super.
  - Объявить `final searchControllerProvider = StateNotifierProvider.autoDispose<SearchController, SearchUiState>((ref) => SearchController(ref.watch(apiClientProvider)));`. (Использует существующий `apiClientProvider` из codebase; если нет — task 3.1 поднимает issue, но текущий codebase его уже содержит для `ApiClient` потребления.)
  - Импорты: `package:flutter_riverpod/flutter_riverpod.dart`, `dart:async`, `Channel`, `ApiClient`, `KeyboardKey` types, `SearchUiState`.
  - Наблюдаемое: `flutter analyze` чисто; `_inFlight` поле читается в `_runSearch` И `requestNextPage`; debounce cancel вызывается до `_transition` в `_scheduleSearch`.
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 7.1, 7.2, 7.3, 7.4, 7.5, 10.2, 10.3_
  - _Depends: 1.1, 2.1_
  - _Boundary: search_controller.dart_

---

## 4. CyrillicKeyboard widget с D-pad navigation

- [ ] 4.1 Создать `CyrillicKeyboard` `StatefulWidget` с D-pad-handlers
  - Создать `megav_iptv/lib/features/search/widgets/cyrillic_keyboard.dart`:
    - `class CyrillicKeyboard extends StatefulWidget` props: `onKeyPressed`, `onExitRight`, `locale = KeyboardLocale.ru`, `@visibleForTesting initialFocus = (0,0)`.
    - `_CyrillicKeyboardState`: state `(int focusRow, int focusCol)`, инициализирован из `widget.initialFocus`.
    - Build: `Column` of 6 rows × `Row` of 6 cells. Каждая cell — `Focus(autofocus: focusRow==r && focusCol==c, onKeyEvent: ...)`:
      - `LogicalKeyboardKey.arrowUp` → `setState(() => focusRow = (focusRow - 1).clamp(0, 5));` return `KeyEventResult.handled`.
      - `LogicalKeyboardKey.arrowDown` → `setState(() => focusRow = (focusRow + 1).clamp(0, 5));` handled.
      - `LogicalKeyboardKey.arrowLeft`: если `focusCol > 0` — decrement, handled; иначе `KeyEventResult.ignored` (parent decides — Req 3.5).
      - `LogicalKeyboardKey.arrowRight`: если `focusCol < 5` — increment, handled; иначе `widget.onExitRight()`, handled (Req 3.7).
      - `LogicalKeyboardKey.select`: lookup glyph через `keyboardLayout(widget.locale)[focusRow][focusCol]`. Если glyph == 'SP' → `widget.onKeyPressed(const Space())`; 'BS' → `Backspace()`; 'LT' → setState swap locale + `widget.onKeyPressed(const LocaleToggle())`; иначе `widget.onKeyPressed(Char(glyph))`. handled.
    - Cell rendering: `MvKey(glyph: ...)` (или эквивалент через atom barrel) обёрнутый в `Transform.scale(scale: focused ? 1.05 : 1.0)` + `SafeFocusRing(isFocused: focused)`. **Запрещено `AnimatedContainer.width`** (Req 9.4).
    - Импорты: `package:flutter/services.dart` (LogicalKeyboardKey), atoms barrel, `keyboard_layouts.dart`, `keyboard_key.dart`, perf widgets.
  - Наблюдаемое: `flutter analyze` чисто; `grep "AnimatedContainer" lib/features/search/widgets/cyrillic_keyboard.dart` → 0 hits; widget tree содержит `Transform.scale` И `SafeFocusRing`.
  - _Requirements: 2.3, 2.4, 2.6, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 9.4_
  - _Depends: 1.1_
  - _Boundary: cyrillic_keyboard.dart_

---

## 5. SearchInput с blinking caret в RepaintBoundary

- [ ] 5.1 Создать `SearchInput` `StatefulWidget` с caret через `AnimationController`
  - Создать `megav_iptv/lib/features/search/widgets/search_input.dart`:
    - `class SearchInput extends StatefulWidget` props: `String query`, `String placeholder = 'Найти что-то стоящее'`.
    - `_SearchInputState with SingleTickerProviderStateMixin`:
      - `late final AnimationController _caret;` в `initState`: `_caret = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);`.
      - `dispose()`: `_caret.dispose(); super.dispose();`.
    - Build: `Row` из:
      - `Expanded(child: Text(query.isEmpty ? placeholder : query, style: Theme.of(context).megavText.displayLarge.copyWith(color: query.isEmpty ? AppColors.textDim : AppColors.text)))`.
      - `RepaintBoundary(child: FadeTransition(opacity: Tween(begin: 1.0, end: 0.2).animate(_caret), child: Container(width: 3, height: 36, color: AppColors.accent)))`. **`RepaintBoundary` обязателен per Req 4.3, 9.3.**
  - Наблюдаемое: `flutter analyze` чисто; в widget tree находится ровно один `RepaintBoundary` с потомком `FadeTransition`; controller-tick не ребилдит parent (verified в task 7.x widget test).
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 9.3_
  - _Boundary: search_input.dart_

---

## 6. SearchResultsGrid с exhaustive sealed switch + lazy paging

- [ ] 6.1 Создать `SearchResultsGrid` `ConsumerWidget` с per-state rendering
  - Создать `megav_iptv/lib/features/search/widgets/search_results_grid.dart`:
    - Top-level helper `int pickColumnsClamped(double w)`: вызывает существующий `pickColumns(w)` (из `lib/features/home/widgets/_grid_tokens.dart`) и `.clamp(2, 4)` (правая панель уже full screen).
    - `class SearchResultsGrid extends ConsumerWidget`. Build: `final state = ref.watch(searchControllerProvider);` и `switch(state) { Idle() => _IdleHint(), Loading() => _LoadingOverlay(), Empty(:final query) => _EmptyMessage(query), Error(:final message) => _ErrorRetry(message: message), Results(:final items, :final hasMore) => _ResultsGridView(items: items, hasMore: hasMore) }`. **Без `default:`** (Req 10.4).
    - Private widgets:
      - `_IdleHint` — placeholder text «Начните вводить запрос».
      - `_LoadingOverlay` — `Center(child: CircularProgressIndicator())` поверх предыдущих результатов с `Opacity(opacity: 0.5)` (Req 6.3) — для simplicity `_LoadingOverlay` рисует только spinner; previous-results-fade реализуется через preserve `Stack` в `SearchResultsGrid` build (отдельный layer ниже switch).
      - `_EmptyMessage` — «Ничего не найдено по запросу "$query"».
      - `_ErrorRetry` — текст ошибки + `MvButton.ghost(label: 'Повторить', onPressed: () => ref.read(searchControllerProvider.notifier)._scheduleSearch())` (или public `retry()` метод в controller — добавить если надо).
      - `_ResultsGridView extends ConsumerWidget` — `GridView.builder`:
        - `crossAxisCount: pickColumnsClamped(MediaQuery.of(context).size.width)`.
        - `cacheExtent: 1500, addAutomaticKeepAlives: true, addRepaintBoundaries: true` (Req 6.8, 9.5).
        - `itemBuilder`: при `i == items.length - 1 && hasMore` вызывает `ref.read(searchControllerProvider.notifier).requestNextPage()` (post-frame через `WidgetsBinding.instance.addPostFrameCallback` чтобы не вызывать setState во время build).
        - Cell — `Poster(image: NetworkImage(channel.logoUrl ?? thumbnailUrl), title: channel.name)` через atoms barrel.
  - Импорты: `flutter_riverpod`, atoms barrel, `Channel` model, `_grid_tokens` `pickColumns`, perf widgets, search_state.
  - Наблюдаемое: `flutter analyze` чисто; `grep "default:" search_results_grid.dart` → 0 hits внутри `switch (state)`; `cacheExtent: 1500` присутствует.
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 7.2, 9.5, 10.4, 11.1, 11.7_
  - _Depends: 2.1, 3.1_
  - _Boundary: search_results_grid.dart_

---

## 7. SearchScreen с 2-pane layout + integration

- [ ] 7.1 Создать `SearchScreen` `ConsumerWidget` с two-pane layout
  - Создать `megav_iptv/lib/features/search/search_screen.dart`:
    - `class SearchScreen extends ConsumerWidget` (НЕ `ConsumerStatefulWidget` — Req 10.5).
    - Build: `Scaffold(backgroundColor: Theme.of(context).colorScheme.surface, body: SafeArea(child: Row(children: [SizedBox(width: 360, child: _LeftPane()), const Expanded(child: SearchResultsGrid())])))`.
    - `_LeftPane` `ConsumerWidget` — `Column`:
      - Header `SectionTitle(title: 'Поиск', em: 'найти')` (atom from barrel).
      - `SearchInput(query: ref.watch(searchControllerProvider).query)`.
      - `CyrillicKeyboard(onKeyPressed: (k) => ref.read(searchControllerProvider.notifier).onKeyPressed(k), onExitRight: () { /* TODO transfer focus to results pane via FocusScope.of(context).focusInDirection(TraversalDirection.right) или через явный FocusNode на results */ })`.
      - Optional `RemoteHint(...)` footer (atom from barrel).
  - Импорты: `flutter_riverpod`, atoms barrel, search-feature widgets.
  - Наблюдаемое: `flutter analyze` чисто; widget tree содержит `Row` с двумя children, левый child имеет `width: 360`.
  - _Requirements: 1.5, 10.5, 11.1, 11.2, 11.3, 11.5_
  - _Depends: 4.1, 5.1, 6.1_
  - _Boundary: search_screen.dart_

---

## 8. Route registration + home-screen affordance

- [ ] 8.1 Зарегистрировать `/search` route в `lib/app.dart`
  - Открыть `megav_iptv/lib/app.dart` и в существующий `_router` `routes:` список добавить **ровно одну** строку: `GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),`.
  - Импорт `import 'features/search/search_screen.dart';`.
  - Никакие другие routes (`/`, `/home`, `/player`, `/settings`) не модифицируются.
  - Наблюдаемое: `git diff lib/app.dart` показывает добавление exactly 2 строк (1 import + 1 GoRoute); все остальные routes идентичны pre-spec.
  - _Requirements: 1.1, 1.2_
  - _Boundary: app.dart (1-line addition)_

- [ ] 8.2 Добавить search-affordance в home-screen header
  - Найти существующий header home-screen (`lib/features/home/home_screen.dart` или `lib/features/home/widgets/<header>.dart`) — секция с logo/status и т.п.
  - Добавить `MvIconButton(icon: Icons.search, onPressed: () => context.push('/search'))` (atom from barrel) внутрь header `Row`. Должно быть focusable (atom уже использует `SafeFocusRing` per Req 1.4 — verify).
  - Никакая другая логика home-screen не меняется.
  - Наблюдаемое: `git diff` ограничен одним home-header файлом, добавлено ≤ 5 lines (import + button entry); запуск приложения → home показывает мag-glass icon в header; `OK` на нём ведёт на `/search`.
  - _Requirements: 1.3, 1.4_
  - _Boundary: home-screen header (1 widget addition)_

---

## 9. API extension: `searchChannels` с backward-compat verification

- [ ] 9.1 Расширить `ApiClient` методом `searchChannels` (без касания других)
  - Открыть `megav_iptv/lib/core/api/api_client.dart`.
  - **Pre-condition**: зафиксировать текущий список public методов класса. Запустить:
    ```bash
    grep -E "^\s*(Future|String|void)\s+\w+\(" megav_iptv/lib/core/api/api_client.dart | sort > /tmp/api_methods_before.txt
    ```
  - Добавить **ровно один** новый метод `searchChannels` в конец класса (перед `dispose()` или после `thumbnailUrl`):
    ```dart
    Future<({List<Channel> channels, int total})> searchChannels({
      required String query,
      int limit = 20,
      int offset = 0,
    }) async {
      final params = <String, String>{
        'search': query,
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      final uri = Uri.parse('$baseUrl/api/channels').replace(queryParameters: params);
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> channelsJson = data['channels'] ?? [];
        final total = data['total'] as int? ?? 0;
        return (channels: channelsJson.map((j) => Channel.fromJson(j)).toList(), total: total);
      }
      throw Exception('Failed to search channels');
    }
    ```
  - **Post-condition (backward-compat verification)**: повторить grep:
    ```bash
    grep -E "^\s*(Future|String|void)\s+\w+\(" megav_iptv/lib/core/api/api_client.dart | sort > /tmp/api_methods_after.txt
    diff /tmp/api_methods_before.txt /tmp/api_methods_after.txt
    ```
    Diff должен показать **только одну новую строку** (`Future<...> searchChannels(...)`). Все existing методы (`getCategories`, `getChannels`, `getFeaturedChannels`, `getNowPlaying`, `getUpcomingAll`, `getCategoryNowPlaying`, `getMoviesNowPlaying`, `getFeaturedNowPlaying`, `getCurrentProgram`, `getUpcomingPrograms`, `getBestStreamUrl`, `thumbnailUrl`, `_enrichThumbnail`, `dispose`) — идентичны.
  - **Constructor + private fields**: `ApiClient({required baseUrl, http.Client? client})`, `_client`, `baseUrl` — НЕ модифицировать (Req 8.4).
  - Наблюдаемое: `flutter analyze megav_iptv/lib/core/api/api_client.dart` чисто; existing call-sites `getChannels(search: 'q')` компилируются и работают без изменений; `git diff` ограничен ≤ 25 added lines, 0 modified existing lines.
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_
  - _Boundary: api_client.dart (single method addition, backward-compat asserted)_

---

## 10. Tests + regression + analyzer

- [ ] 10.1 Unit-test `SearchController` debounce + paging + `_inFlight`
  - Создать `megav_iptv/test/features/search/search_controller_test.dart`:
    - Stub `ApiClient` (можно через manual mock class implementing real signature).
    - Test: 2 синхронных `onKeyPressed(Char('А'))` + `Char('Б'))` + `await Future.delayed(400ms)` → assert `searchChannels` called **exactly once** с `query: 'АБ'` (Req 5.2, 5.3, 12.5).
    - Test: `Backspace()` на пустой query → no API call, state remains `Idle` (Req 5 backspace guard).
    - Test: успешный response `[ch1, ch2]`, total 2 → state == `Results(items: [ch1, ch2], total: 2, hasMore: false)`.
    - Test: empty response → state == `Empty(query)`.
    - Test: throw → state == `Error(message, lastQuery)`.
    - Test: `requestNextPage` while `hasMore=false` → no API call.
    - Test: `requestNextPage` while `_inFlight=true` (started но не resolved) → второй call returns immediately, не запускает API.
  - _Requirements: 5.1, 5.2, 5.3, 5.5, 7.2, 7.3, 12.2, 12.5_
  - _Depends: 3.1_
  - _Boundary: search_controller_test.dart_

- [ ] 10.2 Unit-test `searchChannels` parsing + `getChannels` regression
  - Создать `megav_iptv/test/features/search/api_client_search_test.dart`:
    - Mock `http.Client` returning `200` с body `{"channels":[{...}], "total": 42}` → assert `searchChannels(query: 'q')` returns `(channels.length == 1, total == 42)` (Req 8.5, 12.6).
    - Mock returning `500` → assert throws `Exception` whose message contains «search channels» (Req 8.6).
    - **Regression test**: тот же mock + call `getChannels(search: 'q', limit: 20, offset: 0)` → assert returns те же `(channels, total)` без throw (Req 8.7, 12.6 — proves API surface backward-compat).
  - _Requirements: 8.5, 8.6, 8.7, 12.6_
  - _Depends: 9.1_
  - _Boundary: api_client_search_test.dart_

- [ ] 10.3 Widget-test `CyrillicKeyboard` D-pad nav + OK callbacks
  - Создать `megav_iptv/test/features/search/cyrillic_keyboard_test.dart`:
    - Pump `CyrillicKeyboard(initialFocus: (0, 0), ...)` → simulate `arrowDown` via `tester.sendKeyEvent(LogicalKeyboardKey.arrowDown)` → assert focus moved to `(1, 0)` (Req 3.3, 12.3).
    - Pump `(5, 0)` + `arrowDown` → assert focus stays `(5, 0)` (no wrap — Req 3.3, 12.3).
    - Pump `(0, 5)` + `arrowRight` → assert `onExitRight` callback invoked once (Req 3.7).
    - Pump `(0, 0)` + `select` → assert `onKeyPressed(Char('А'))` invoked once (Req 3.8, 12.4).
    - Pump `(5, 3)` + `select` → assert `onKeyPressed(Space())` invoked (utility cell — Req 3.9).
  - _Requirements: 3.3, 3.7, 3.8, 3.9, 12.3, 12.4_
  - _Depends: 4.1_
  - _Boundary: cyrillic_keyboard_test.dart_

- [ ] 10.4 Widget-test `SearchInput` caret blink + RepaintBoundary
  - Создать `megav_iptv/test/features/search/search_input_test.dart`:
    - Pump `SearchInput(query: '')` → assert placeholder rendered.
    - Pump `SearchInput(query: 'тест')` → assert query rendered; assert `find.byType(RepaintBoundary)` finds at least one RB whose subtree contains the caret `Container(width: 3)` (Req 4.3, 9.3).
  - _Requirements: 4.1, 4.2, 4.3, 4.4_
  - _Depends: 5.1_
  - _Boundary: search_input_test.dart_

- [ ] 10.5 Widget-test `SearchResultsGrid` per-state rendering
  - Создать `megav_iptv/test/features/search/search_results_grid_test.dart`:
    - Stub `searchControllerProvider` через `ProviderScope(overrides: ...)` для каждого из 5 состояний.
    - Idle → finds `_IdleHint` text «Начните вводить».
    - Loading → finds `CircularProgressIndicator`.
    - Empty(query: 'xyz') → finds text containing «xyz».
    - Error(message: 'oops') → finds text «oops» + «Повторить» button.
    - Results(items: [ch1, ch2], total: 2, hasMore: false) → finds 2 `Poster` atoms; assert `GridView.builder.cacheExtent == 1500`, `addAutomaticKeepAlives == true`, `addRepaintBoundaries == true` (Req 6.8, 9.5).
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.8, 9.5_
  - _Depends: 6.1_
  - _Boundary: search_results_grid_test.dart_

- [ ] 10.6 Regression + grep gates + analyzer
  - Запустить `flutter test` из `megav_iptv/` — все тесты (65 pre-existing + новые из task 10.1–10.5) зелёные (Req 12.8).
  - Запустить grep на perf-rules:
    ```bash
    grep -rn "BackdropFilter\|ShaderMask" megav_iptv/lib/features/search/  # 0 hits
    grep -rEn "blurRadius:\s*([2-9][0-9]+|1[3-9])" megav_iptv/lib/features/search/  # 0 hits
    grep -rn "AnimatedContainer" megav_iptv/lib/features/search/widgets/cyrillic_keyboard.dart  # 0 hits для focus visual
    ```
    Все три должны вернуть 0 production hits (Req 9.1, 9.2, 9.4).
  - Запустить `flutter analyze megav_iptv/lib/features/search/ megav_iptv/lib/core/api/api_client.dart megav_iptv/lib/app.dart` — 0 errors, 0 warnings (Req 12.7).
  - **Backward-compat re-check**: повторно сравнить grep сигнатур `ApiClient` (см. task 9.1 post-condition) — diff показывает only `searchChannels` added (Req 8.3).
  - Наблюдаемое: все три gates чистые; report артефакты прикрепляются к task review.
  - _Requirements: 8.3, 9.1, 9.2, 9.4, 12.7, 12.8_
  - _Depends: 8.1, 8.2, 9.1, 10.1, 10.2, 10.3, 10.4, 10.5_
  - _Boundary: regression-only — no new files_

---

## Implementation order summary

```
1.1 (layouts + sealed key types — first task per pipeline)
2.1 (sealed SearchUiState)
3.1 (SearchController, depends on 1.1+2.1)
4.1 (CyrillicKeyboard, depends on 1.1)
5.1 (SearchInput, independent)
6.1 (SearchResultsGrid, depends on 2.1+3.1)
7.1 (SearchScreen, depends on 4.1+5.1+6.1)
8.1 (route entry, depends on 7.1)
8.2 (home-screen affordance, depends on 8.1)
9.1 (API extension — separate task with explicit backward-compat verification per pipeline)
10.1–10.5 (tests — depend on respective production tasks)
10.6 (regression + grep + analyzer — depends on all)
```

Total: **11 tasks** (1 foundation + 1 sealed state + 1 controller + 4 widgets/screens + 2 integration + 1 API + 5 test + 1 regression). API-extension в **отдельной task 9.1** с pre/post grep diff для backward-compat (Req 8.3, 8.7).
