# Implementation Plan — epg-screen

> Спек: `epg-screen`. См. `requirements.md` (14 requirements) и `design.md` (12 components + sealed state + 9 tests).
>
> Принципы:
> 1. **Closed-spec безопасность**: 0 writes в `lib/features/player/widgets/epg_overlay.dart`, 0 writes в существующие методы `lib/core/api/api_client.dart`, 0 writes в существующие провайдеры `lib/core/providers/providers.dart`, 0 writes в `lib/core/playlist/models/epg_program.dart`. Только READ-ONLY импорты + add-only расширение `lib/core/epg/`.
> 2. **Один файл = одна сущность**, parallel-friendly. Каждая sub-task ставит свой Key, помечает _Boundary:_ и регистрирует `_Depends:_` cross-task.
> 3. **Perf gate**: каждый task проходит `grep -rE "BackdropFilter|ShaderMask|ImageFilter\.blur" lib/features/epg/ lib/core/epg/` → 0 hits, и `grep -rE "blurRadius:\s*([2-9][0-9]+|1[3-9])" lib/features/epg/ lib/core/epg/` → 0 hits. Final task 6.3 повторяет это глобально + verify `git diff` для closed-spec файлов.
> 4. **Regression gate**: финальный task 6.3 запускает `flutter test` (включая player-overlay invariant test 6.2) — ожидание: baseline + все новые green.
> 5. **Foundation first**: phase 1 целиком создаёт data-layer (`lib/core/epg/`) до того, как любой UI-widget начнёт от него зависеть.

---

## 1. Foundation: data-layer extension (`lib/core/epg/*`)

- [x] 1.1 `EpgRepository` — batch programme query
  - Создать `megav_iptv/lib/core/epg/epg_repository.dart` с публичным классом `EpgRepository`:
    - Конструктор `EpgRepository(this._api)` принимает существующий `ApiClient` через DI.
    - Метод `Future<Map<int, List<EpgProgram>>> programmesInWindow(DateTime from, DateTime to, List<int> channelIds)` (Req 11.2).
    - Внутренний кэш: `Map<String, _CacheEntry>` с TTL 60 sec (Req 11.4). Ключ — `_cacheKey(from, to, sortedChannelIds)`.
    - Стратегия выборки: попробовать `_api.getEpgWindow(from, to, ids)` если метод существует (через try/catch на `NoSuchMethodError` ИЛИ feature-flag, реализатель выбирает менее-инвазивный путь). Иначе fan-out — параллельные `_api.getUpcomingPrograms(channelId)` с in-flight de-dup через `Map<int, Future<List<EpgProgram>>>` (Req 11.5). После fetch отфильтровать `EpgProgram` по `[from..to]`.
    - **Не модифицировать** `EpgProgram` модель (Req 11.7).
    - **Не модифицировать** существующие методы `ApiClient` (Req 11.6).
  - Наблюдаемое: `flutter analyze megav_iptv/lib/core/epg/epg_repository.dart` чисто; класс публичный; baseline тесты не сломаны.
  - _Requirements: 11.1, 11.2, 11.4, 11.5, 11.7_
  - _Boundary: EpgRepository data-layer extension_

- [x] 1.2 `epgWindowProvider` Riverpod family
  - Создать `megav_iptv/lib/core/epg/epg_window_provider.dart` с:
    - `class EpgWindowKey` — value-object с `from: DateTime`, `to: DateTime`, `channelIds: List<int>`. Реализует `==`/`hashCode` через `(from, to, sortedJoin(channelIds))` для корректного family-cache.
    - `final epgRepositoryProvider = Provider<EpgRepository>((ref) { final api = ref.watch(apiClientProvider); return EpgRepository(api); });`
    - `final epgWindowProvider = FutureProvider.family<Map<int, List<EpgProgram>>, EpgWindowKey>((ref, key) async { final repo = ref.watch(epgRepositoryProvider); return repo.programmesInWindow(key.from, key.to, key.channelIds); });` (Req 11.3).
  - **Не модифицировать** `lib/core/providers/providers.dart` существующие провайдеры (Req 11.1, Req 14).
  - Наблюдаемое: `flutter analyze megav_iptv/lib/core/epg/epg_window_provider.dart` чисто; провайдер импортируется без cycle; baseline тесты не сломаны.
  - _Requirements: 11.1, 11.3, 11.4_
  - _Depends: 1.1_
  - _Boundary: epgWindowProvider_

- [-] 1.3 (OPTIONAL) Append `ApiClient.getEpgWindow` if backend supports batch
  - Если backend имеет batch-endpoint (e.g., `/api/epg/window?from=...&to=...&channels=...`): добавить **ровно один новый метод** `Future<Map<int, List<EpgProgram>>> getEpgWindow(DateTime from, DateTime to, List<int> channelIds)` в конец `megav_iptv/lib/core/api/api_client.dart` (Req 11.6).
  - Если backend НЕ поддерживает batch — пропустить этот task; в `EpgRepository._fetch` использовать только N-fan-out путь (Req 11.5).
  - **Hard rule**: 0 модификаций существующих методов `ApiClient`. `git diff lib/core/api/api_client.dart` показывает только append (или ничего).
  - Наблюдаемое: если task выполнен — `git diff` показывает только новый метод; baseline тесты остаются зелёными.
  - _Requirements: 11.6_
  - _Depends: 1.1_
  - _Boundary: ApiClient.getEpgWindow append-only_

- [x] 1.4 Repository + provider tests
  - Создать `megav_iptv/test/core/epg/epg_repository_test.dart`:
    - Тест 1: `programmesInWindow` возвращает map keyed by channelId.
    - Тест 2: TTL cache — два последовательных вызова с одинаковыми args дают один сетевой запрос (через мок-`ApiClient` со счётчиком).
    - Тест 3: in-flight de-dup — два параллельных вызова с одинаковым `channelId` дают один сетевой запрос (Req 11.5).
    - Тест 4: фильтрация по `[from..to]` — программы вне окна отбрасываются.
  - Создать `megav_iptv/test/core/epg/epg_window_provider_test.dart`:
    - Тест 1: `EpgWindowKey` `==` / `hashCode` правильно нормализуют `channelIds` через сортировку.
    - Тест 2: `epgWindowProvider` через `ProviderContainer` отдаёт `AsyncData` с ожидаемой картой при моке `EpgRepository`.
  - Наблюдаемое: все тесты зелёные; `flutter analyze test/core/epg/` чисто.
  - _Requirements: 11.2, 11.3, 11.4, 11.5, 14.2_
  - _Depends: 1.1, 1.2_
  - _Boundary: data-layer tests_

---

## 2. UI scaffold + state machine

- [x] 2.1 Sealed `EpgUiState` + `_transition` skeleton
  - Создать `megav_iptv/lib/features/epg/state/epg_screen_state.dart`:
    - `sealed class EpgUiState { const EpgUiState(); }`
    - `final class EpgLoadingState extends EpgUiState { const EpgLoadingState(); }`
    - `final class EpgReadyState extends EpgUiState { final List<Channel> channels; final Map<int, List<EpgProgram>> programmes; final DateTime windowFrom; final DateTime windowTo; final String? selectedCategory; final int? focusedChannelIndex; final int? focusedProgrammeId; const EpgReadyState({...}); }`
    - `final class EpgErrorState extends EpgUiState { final Object error; final StackTrace stackTrace; const EpgErrorState({...}); }`
  - **Hard rule**: ни один потребитель не должен мутировать поля; `copyWith(...)` для transition'ов внутри `EpgReadyState`.
  - Наблюдаемое: `flutter analyze` чисто; экспортируется чистый sealed type; нет внешних потребителей пока.
  - _Requirements: 12.1, 12.4_
  - _Boundary: EpgUiState sealed type_

- [x] 2.2 `EpgScreen` skeleton + entry route
  - Создать `megav_iptv/lib/features/epg/epg_screen.dart` с `class EpgScreen extends ConsumerStatefulWidget` (Req 1.1).
  - В `build` — `Scaffold(body: SafeArea(child: const SizedBox.shrink()))` + root `Key('epg-screen-root')` (placeholder; subtree заполнят phase 3-5).
  - Скелет state-машины: `EpgUiState _state = const EpgLoadingState(); Timer? _focusDebounceTimer; bool _inFlight = false; void _transition(EpgUiState newState) { _focusDebounceTimer?.cancel(); _focusDebounceTimer = null; setState(() => _state = newState); }` (Req 12.2, 12.3, 9.6).
  - **Entry route**: добавить ONE-LINE GoRoute entry `/epg` в существующий router (например, `lib/main.dart` или `lib/app/app_router.dart`). Существующие routes не модифицируются (Req 1.3, 14.7). Implementer документирует выбранный файл в commit message.
  - Наблюдаемое: legacy `HomeScreen` остаётся reachable; новый route reachable; `flutter analyze` чисто; baseline тесты не сломаны; `git diff <router-file>` содержит ровно одно добавление.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 12.1, 12.2, 12.3, 14.7_
  - _Depends: 2.1, 1.2_
  - _Boundary: EpgScreen scaffold + entry route_

- [ ] 2.3 Smoke test для пустого скелета
  - Создать `megav_iptv/test/features/epg/epg_screen_smoke_test.dart`.
  - Тест pump'ит `EpgScreen` внутри `ProviderScope` + `MaterialApp` с замоканным `epgWindowProvider` (override через `ProviderScope(overrides: [...])`); `await tester.pump(); await tester.pump();` → ожидает no exception + `find.byKey(const Key('epg-screen-root'))` finds one + `find.byType(BackdropFilter)` finds none + `find.byType(ShaderMask)` finds none.
  - Наблюдаемое: `flutter test test/features/epg/epg_screen_smoke_test.dart` зелёный; baseline + 1 новый.
  - _Requirements: 13.1, 14.2, 14.3_
  - _Depends: 2.2_
  - _Boundary: smoke test scaffold_

---

## 3. Channel rail + time axis + programme cell

- [ ] 3.1 `EpgChannelRail`
  - Создать `megav_iptv/lib/features/epg/widgets/epg_channel_rail.dart` с `class EpgChannelRail extends ConsumerStatefulWidget` (Req 3).
  - Параметры: `List<Channel> channels`, `ScrollController verticalCtl` (shared с time-grid, Req 2.4, 3.2), `int? focusedChannelIndex`, `ValueChanged<int> onFocusChanged`.
  - Build: `ListView.builder(controller: verticalCtl, scrollDirection: Axis.vertical, cacheExtent: 1500, addAutomaticKeepAlives: true, addRepaintBoundaries: true, clipBehavior: Clip.none, itemCount: channels.length, itemBuilder: (ctx, i) => SizedBox(width: 240.w, height: 88.h, key: Key('epg-channel-cell-${channels[i].id}'), child: Focus(child: AnimatedScale(scale: focused ? 1.05 : 1.0, duration: 150ms, curve: Curves.easeOutCubic, child: SafeFocusRing(focused: focused, child: Row([Brand(...), Column([Text(name, style: titleMedium), Text(groupTitle, style: metaMono)])]))))))` (Req 3.1, 3.3, 3.5, 13.5).
  - Корневой widget получает `Key('epg-channel-rail')` (Req 3.5).
  - **Не модифицировать** `Channel` модель и существующие провайдеры (Req 3.4).
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится; key present; ListView имеет правильные перф-флаги.
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 13.1, 13.2, 13.3, 13.5_
  - _Depends: 2.1_
  - _Boundary: EpgChannelRail_

- [ ] 3.2 `EpgChannelRail` widget test
  - Создать `megav_iptv/test/features/epg/epg_channel_rail_test.dart`.
  - Тест 1: pump с 5 моковыми Channel; `find.byKey(const Key('epg-channel-rail'))` finds one; `find.byKey(const Key('epg-channel-cell-1'))` finds one (или ≥ 1 в viewport).
  - Тест 2: ListView имеет `cacheExtent == 1500.0`, `addAutomaticKeepAlives == true`, `addRepaintBoundaries == true`, `clipBehavior == Clip.none` (Req 13.5).
  - Тест 3: `find.byType(BackdropFilter)` / `find.byType(ShaderMask)` — оба empty (Req 13.1).
  - Наблюдаемое: 3 теста зелёные.
  - _Requirements: 13.1, 13.5, 14.2_
  - _Depends: 3.1_
  - _Boundary: channel rail test_

- [ ] 3.3 `EpgTimeAxis`
  - Создать `megav_iptv/lib/features/epg/widgets/epg_time_axis.dart` с `class EpgTimeAxis extends StatelessWidget` (Req 5).
  - Параметры: `DateTime windowFrom`, `int slotCount` (default 10), `ScrollController horizontalCtl` (shared с time-grid, Req 5.2), `double slotW = 180`.
  - Build: sticky horizontal header — `SizedBox(height: 32.h, child: ListView.builder(controller: horizontalCtl, scrollDirection: Axis.horizontal, physics: NeverScrollableScrollPhysics() // controlled-only, cacheExtent: 1500, addAutomaticKeepAlives: true, addRepaintBoundaries: true, clipBehavior: Clip.none, itemCount: slotCount, itemBuilder: (ctx, i) => SizedBox(width: slotW.w, child: Center(child: Text(formatTime(windowFrom.add(Duration(minutes: 30 * i))), style: theme.megavText.metaMono)))))` (Req 5.1, 5.2, 5.4, 13.5).
  - Корневой `Key('epg-time-axis')` (Req 5.5).
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится.
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 13.1, 13.5_
  - _Depends: 2.1_
  - _Boundary: EpgTimeAxis_

- [ ] 3.4 `EpgProgramCell`
  - Создать `megav_iptv/lib/features/epg/widgets/epg_program_cell.dart` с `class EpgProgramCell extends StatelessWidget` (Req 4).
  - Параметры: `EpgProgram program`, `bool focused`, `double slotW = 180`, `double rowH = 88`, `VoidCallback? onTap`, `VoidCallback? onFocusChange`.
  - Build:
    ```dart
    final spanW = (program.duration.inMinutes / 30.0).ceil() * slotW;
    return SizedBox(width: spanW.w, height: rowH.h, child:
      Focus(child: AnimatedScale(scale: focused ? 1.05 : 1.0, duration: 150ms, curve: Curves.easeOutCubic, child:
        AnimatedContainer(duration: 140ms, decoration: BoxDecoration(color: focused ? accent : surface, borderRadius: AppRadius.md, boxShadow: focused ? [SafeFocusRing.shadow] : null), child:
          Row([Text(formatTime(program.start), style: metaMono),
               Expanded(child: Column([Text(program.title, style: titleMedium.copyWith(fontStyle: FontStyle.normal)),
                                       if (program.isNow) MvTrack(progress: program.progress)])),
               if (program.isNow) Chip(variant: ChipVariant.live, label: 'LIVE')])))));
    ```
    (Req 4.1, 4.2, 4.3, 4.4, 4.5, 4.6).
  - **Hard rule**: `fontStyle: FontStyle.normal` на title (Req 4.1, brief explicit «без курсива»).
  - Title `Shadow(blurRadius: kSafeShadowBlurMax)` — НЕ выше (Req 13.2).
  - Корневой `Key('epg-programme-cell-${program.id}')` (Req 4.7).
  - **Perf gate**: те же два grep-чека → 0; `grep "AnimatedContainer.*width:" lib/features/epg/widgets/epg_program_cell.dart` → 0 (Req 13.3).
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится с program.isNow=true и =false вариантами.
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 13.1, 13.2, 13.3_
  - _Depends: 2.1_
  - _Boundary: EpgProgramCell_

- [ ] 3.5 `EpgProgramCell` widget test
  - Создать `megav_iptv/test/features/epg/epg_program_cell_test.dart`.
  - Тест 1: pump с программой `isNow == true` → `find.byType(Chip)` finds one (live variant); `find.byType(MvTrack)` finds one.
  - Тест 2: pump с программой `isNow == false` → `find.byType(Chip)` finds none.
  - Тест 3: title style проверка — `tester.widget<Text>(find.text('test title'))` имеет `style.fontStyle == FontStyle.normal` (Req 4.1 explicit).
  - Тест 4: `find.byType(BackdropFilter)` / `find.byType(ShaderMask)` — оба empty.
  - Наблюдаемое: 4 теста зелёные.
  - _Requirements: 4.1, 4.3, 13.1, 14.2_
  - _Depends: 3.4_
  - _Boundary: programme cell test_

---

## 4. Time grid + NOW marker

- [ ] 4.1 `EpgTimeGrid` virtualised 2-axis
  - Создать `megav_iptv/lib/features/epg/widgets/epg_time_grid.dart` с `class EpgTimeGrid extends StatefulWidget` (Req 2).
  - Параметры: `List<Channel> channels`, `Map<int, List<EpgProgram>> programmes`, `DateTime windowFrom`, `int slotCount`, `ScrollController verticalCtl` (shared с channel rail, Req 2.4), `ScrollController horizontalCtl` (shared с time axis, Req 2.5), `int? focusedChannelIndex`, `int? focusedProgrammeId`, `ValueChanged<({int channelIdx, int programmeId})>? onCellFocusChanged`, `ValueChanged<EpgProgram>? onCellTap`.
  - Build outer (вертикальный): `ListView.builder(controller: verticalCtl, scrollDirection: Axis.vertical, cacheExtent: 1500, addAutomaticKeepAlives: true, addRepaintBoundaries: true, clipBehavior: Clip.none, itemCount: channels.length, itemBuilder: ...)` (Req 2.3, 13.5).
  - Build inner (горизонтальный): per-row `SizedBox(height: 88.h, child: ListView.builder(controller: <derived from horizontalCtl>, scrollDirection: Axis.horizontal, cacheExtent: 1500, addAutomaticKeepAlives: true, addRepaintBoundaries: true, clipBehavior: Clip.none, itemCount: programmes[channels[i].id]?.length ?? 0, itemBuilder: (ctx, j) => EpgProgramCell(program: programmes[channels[i].id]![j], focused: ..., onTap: ..., onFocusChange: ...)))` (Req 2.3, 13.5).
  - **Critical**: для горизонтального синхрона между всеми row'ами и time-axis — реализовать lite `ScrollControllerGroup` (один master `ScrollController`, который реплицирует `offset` через `addListener` на child controllers ИЛИ использовать `linked_scroll_controller`-подобный inline-helper, без новых пакетов в pubspec). Implementer выбирает naimenее-инвазивный подход.
  - Корневой `Key('epg-time-grid')`.
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится с моковой data; `cacheExtent` propagated.
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 13.1, 13.2, 13.5_
  - _Depends: 3.4, 3.3, 3.1_
  - _Boundary: EpgTimeGrid_

- [ ] 4.2 `EpgTimeGrid` widget test
  - Создать `megav_iptv/test/features/epg/epg_time_grid_test.dart`.
  - Тест 1: pump с 3 каналами × 5 программами; `find.byKey(const Key('epg-time-grid'))` finds one; `find.byType(EpgProgramCell)` finds ≥ 1 (в viewport).
  - Тест 2: outer ListView (vertical) имеет правильные перф-флаги (`cacheExtent == 1500.0`, ...).
  - Тест 3: inner ListView (horizontal) имеет правильные перф-флаги.
  - Тест 4: `find.byType(BackdropFilter)` / `find.byType(ShaderMask)` — оба empty.
  - Тест 5: time-axis синхронизация — программно `horizontalCtl.jumpTo(360)` → `EpgTimeAxis` mock также сдвигается (через shared controller).
  - Наблюдаемое: 5 тестов зелёных.
  - _Requirements: 2.3, 2.4, 2.5, 13.1, 13.5, 14.2_
  - _Depends: 4.1_
  - _Boundary: time grid test_

- [ ] 4.3 `EpgNowMarker` + `_NowMarkerLine` (private const ConsumerWidget)
  - Создать `megav_iptv/lib/features/epg/widgets/epg_now_marker.dart` с:
    - `class EpgNowMarker extends StatelessWidget` (public, Req 6.1).
    - Параметры: `DateTime windowFrom`, `double slotW`, `double gridHeight`, `Color accent`.
    - Build: `Positioned(left: nowOffsetX(currentTime, windowFrom, slotW), top: 0, height: gridHeight.h, width: 2.w, key: const Key('epg-now-marker'), child: const _NowMarkerLine())` (Req 6.1, 6.2, 6.5).
    - **NOW marker позиционируется в начале visible window** — explicit `nowOffsetX` clamps to ≥ 0 from left edge (Req 6.2 + brief: «в начале а не в середине»).
    - `class _NowMarkerLine extends ConsumerStatefulWidget { const _NowMarkerLine(); }`. State: `Timer.periodic(Duration(seconds: 30), ...)` triggers minute-tick rebuild (Req 6.4). Inside `RepaintBoundary` (Req 13.4).
    - Visual: thin vertical accent line + «NOW» label at top. `BoxShadow.blurRadius ≤ kSafeShadowBlurMax` (Req 6.3, 13.2).
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; private leaf use const ctor.
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 13.1, 13.2, 13.4_
  - _Depends: 2.1_
  - _Boundary: EpgNowMarker_

- [ ] 4.4 `EpgNowMarker` widget test
  - Создать `megav_iptv/test/features/epg/epg_now_marker_test.dart`.
  - Тест 1: pump с `windowFrom = now() - 30min` → marker positioned at offset corresponding to ~ slotW/2 (verify через `tester.getTopLeft(find.byKey(const Key('epg-now-marker')))`).
  - Тест 2: `_NowMarkerLine` is private — verify `find.ancestor(of: ..., matching: find.byType(RepaintBoundary))` finds one (Req 13.4).
  - Тест 3: `find.byType(BackdropFilter)` / `find.byType(ShaderMask)` — оба empty.
  - Тест 4: `BoxShadow.blurRadius` в дереве не превышает `kSafeShadowBlurMax` — проверка через визит дерева или `find.byType(BoxShadow)` + assert (Req 13.2).
  - Наблюдаемое: 4 теста зелёных.
  - _Requirements: 6.2, 6.3, 13.1, 13.2, 13.4, 14.2_
  - _Depends: 4.3_
  - _Boundary: now marker test_

---

## 5. Day picker + category filter + preview strip + focus controller

- [ ] 5.1 `EpgDayPicker`
  - Создать `megav_iptv/lib/features/epg/widgets/epg_day_picker.dart` с `class EpgDayPicker extends StatelessWidget` (Req 7).
  - Параметры: `DateTime today`, `int selectedOffset`, `ValueChanged<int> onDaySelected`.
  - Build: `Row(children: [for (var offset = -2; offset <= 4; offset++) MvButton(...)])` — 7 day cells from `today − 2` до `today + 4` (Req 7.1).
  - Active day: использует `SafePill` accent + `SafeFocusRing` (Req 7.2). Inactive day: plain `MvKey` / `MvButton.secondary`.
  - On select → `onDaySelected(offset)` (caller отвечает за `_transition(EpgLoadingState)` + перевыборку данных, Req 7.3).
  - Использует `MvButton` или `MvKey` атомы — НЕ `RawMaterialButton` (Req 7.4).
  - Корневой `Key('epg-day-picker')` (Req 7.5).
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится; key present.
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 13.1, 13.2_
  - _Depends: 2.1_
  - _Boundary: EpgDayPicker_

- [ ] 5.2 `EpgCategoryFilter`
  - Создать `megav_iptv/lib/features/epg/widgets/epg_category_filter.dart` с `class EpgCategoryFilter extends StatelessWidget` (Req 8).
  - Параметры: `List<String> categories`, `String? selectedCategory`, `ValueChanged<String?> onCategorySelected`.
  - Build: `Stack(children: [SizedBox(height: 56.h, child: GenreTabs(tabs: ['Все', ...categories], activeIndex: ..., onSelected: ...)), Positioned(left: 0, top: 0, bottom: 0, width: 32.w, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [palette.background, palette.background.withAlpha(0)]))))), Positioned(right: 0, top: 0, bottom: 0, width: 32.w, child: ... mirrored ...)])` — ТОЛЬКО `DecoratedBox` + `LinearGradient`, никакого `ShaderMask` (Req 8.3).
  - Filter применяется client-side caller'ом без re-fetch (Req 8.2 — caller отвечает; этот widget просто эмитит callback).
  - Корневой `Key('epg-category-filter')` (Req 8.5).
  - **Не модифицировать** `GenreTabs` атом (Req 8.4).
  - **Perf gate**: те же два grep-чека → 0; `find.byType(ShaderMask)` finds none.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится.
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 13.1_
  - _Depends: 2.1_
  - _Boundary: EpgCategoryFilter_

- [ ] 5.3 `EpgPreviewStrip` + `_PreviewThumb` (private RepaintBoundary)
  - Создать `megav_iptv/lib/features/epg/widgets/epg_preview_strip.dart` с `class EpgPreviewStrip extends StatelessWidget` (Req 10).
  - Параметры: `EpgProgram? program`, `Channel? channel`, `VoidCallback? onWatch`, `VoidCallback? onDetails`.
  - Build: `Container(height: 96.h, decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.divider))), child: Row([_PreviewThumb(channel: channel, programme: program), Expanded(child: Column([Text(program.title, style: titleMedium), Text('${channel.name} · ${formatRange(program)}', style: metaMono)])), if (program.isNow) MvButton.primary(label: 'Смотреть', onPressed: onWatch) else MvButton.secondary(label: 'Подробнее', onPressed: onDetails)]))` (Req 10.1).
  - `class _PreviewThumb extends StatelessWidget { const _PreviewThumb(...); @override Widget build(...) => RepaintBoundary(child: SizedBox(width: 132.w, height: 76.h, child: Poster(...))); }` (Req 10.2).
  - Корневой `Key('epg-preview-strip')` (Req 10.5).
  - Caller отвечает за 400 ms debounce обновления через `EpgFocusController` (Req 10.3, 9.5).
  - **Perf gate**: те же два grep-чека → 0.
  - Наблюдаемое: `flutter analyze` чисто; widget pump'ится с program.isNow=true и =false вариантами.
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 13.1, 13.2_
  - _Depends: 2.1_
  - _Boundary: EpgPreviewStrip_

- [ ] 5.4 `EpgFocusController` (D-pad logic)
  - Создать `megav_iptv/lib/features/epg/state/epg_focus_controller.dart` с `class EpgFocusController` (Req 9 logic; pure class, без widgets).
  - Поля:
    - `Map<int, FocusNode> channelFocusNodes`, `Map<int, FocusNode> programmeFocusNodes`.
    - `ScrollController verticalCtl`, `ScrollController horizontalCtl`.
    - `Timer? _focusDebounceTimer`, `bool _inFlight = false`.
  - Методы:
    - `KeyEventResult onKey(FocusNode node, KeyEvent event, EpgReadyState state)` — обрабатывает arrow keys (Req 9.1, 9.2). На ↑/↓ снапит column to live programme index новой row через `_snapToLive(newRowIdx, state)` (Req 9.2). На OK — `_handleSelect(state)` (Req 9.3).
    - `void _ensureFocusInViewport(int channelIdx, int programmeIdx, EpgReadyState state)` — проверяет позицию ячейки против `viewport` через `verticalCtl.position.viewportDimension` / `pixels` и анимирует `animateTo(...)` если расстояние до edge < 80 px (Req 9.4).
    - `void onFocusStabilised(VoidCallback heavy)` — `_focusDebounceTimer?.cancel(); _focusDebounceTimer = Timer(Duration(ms: 400), () { if (mounted check) heavy(); });` (Req 9.5).
    - `Future<void> _handleSelect(EpgReadyState state) async` — guarded by `_inFlight` (Req 9.6).
  - **Не вызывает** методы из `lib/features/player/widgets/epg_overlay.dart` напрямую — только через router / правильно-выставленные callbacks (Req 1.4).
  - Наблюдаемое: `flutter analyze` чисто; класс публичный; unit-тесты в 6.1 будут проверять `onKey` логику.
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 12.3_
  - _Depends: 2.1_
  - _Boundary: EpgFocusController_

- [ ] 5.5 Day picker + category filter + preview strip widget tests
  - Создать `megav_iptv/test/features/epg/epg_day_picker_test.dart`:
    - Тест 1: pump → `find.byKey(const Key('epg-day-picker'))` finds one; `find.byType(MvButton)` finds 7.
    - Тест 2: `find.byType(ShaderMask)` / `find.byType(BackdropFilter)` — empty.
  - Создать `megav_iptv/test/features/epg/epg_category_filter_test.dart`:
    - Тест 1: pump → `find.byKey(const Key('epg-category-filter'))`; `find.byType(GenreTabs)` finds one.
    - Тест 2: edge-fade overlays — `find.byType(DecoratedBox)` ≥ 2.
    - Тест 3: `find.byType(ShaderMask)` finds none (Req 8.3 enforcement).
  - Создать `megav_iptv/test/features/epg/epg_preview_strip_test.dart`:
    - Тест 1: pump c live program → `find.text('Смотреть')` finds one; `find.byType(Poster)` finds one (внутри `_PreviewThumb`).
    - Тест 2: pump c not-live program → `find.text('Подробнее')` finds one.
    - Тест 3: `find.ancestor(of: find.byType(Poster), matching: find.byType(RepaintBoundary))` finds one (Req 10.2).
    - Тест 4: `find.byType(BackdropFilter)` empty.
  - Наблюдаемое: 9 тестов зелёных (2 + 3 + 4).
  - _Requirements: 7.5, 8.3, 8.5, 10.2, 10.5, 13.1, 14.2_
  - _Depends: 5.1, 5.2, 5.3_
  - _Boundary: day picker + cat filter + preview strip tests_

---

## 6. Integration + regression + perf gate

- [ ] 6.1 Wire all components в `EpgScreen`
  - Модифицировать `megav_iptv/lib/features/epg/epg_screen.dart` (созданный в 2.2) — заполнить body composition согласно design.md §3 component layout:
    1. Header row: italic display 56 px «Программа передач» (через `MegaVTextStyles.displayLarge.copyWith(fontStyle: FontStyle.italic)`) + `EpgDayPicker`.
    2. `EpgCategoryFilter`.
    3. Main `Expanded` Stack:
       - `Row([Column([SizedBox(height: timeAxisH), Expanded(child: EpgChannelRail)]), Expanded(child: Column([EpgTimeAxis, Expanded(child: EpgTimeGrid)]))])`.
       - `EpgNowMarker` positioned absolute поверх grid.
    4. `EpgPreviewStrip` (sticky bottom).
  - State wiring:
    - На mount: `_transition(EpgLoadingState())` → `ref.read(epgWindowProvider(EpgWindowKey(...)))` → `_transition(EpgReadyState(channels, programmes, ...))`.
    - На day-picker change: `_transition(EpgLoadingState)` → новый fetch.
    - На category-filter change: client-side filter, без re-fetch (Req 8.2).
    - На D-pad navigation: `EpgFocusController.onKey` → `_transition(EpgReadyState.copyWith(focusedChannelIndex: ..., focusedProgrammeId: ...))`. Heavy preview-strip update — debounced 400 ms (Req 9.5).
    - На OK: `EpgFocusController._handleSelect(...)` — guarded by `_inFlight` (Req 9.6).
  - Все Keys из Req 14.2 mounted (каждая sub-component уже несёт свой Key из phase 3-5).
  - Initial focus на live programme в первом канале (`MvButton`-like initially focused on mount).
  - **Perf gate**: `grep -rE "BackdropFilter|ShaderMask|ImageFilter\.blur" lib/features/epg/ lib/core/epg/` → 0; `grep -rE "blurRadius:\s*([2-9][0-9]+|1[3-9])" lib/features/epg/ lib/core/epg/` → 0.
  - Обновить smoke test из 2.3 для проверки всех keys (часть этого task'а): после mount + 2 pumps в smoke test находятся все 9 ключей: `epg-screen-root`, `epg-day-picker`, `epg-category-filter`, `epg-channel-rail`, `epg-time-axis`, `epg-time-grid`, `epg-now-marker`, `epg-preview-strip`, как минимум один `epg-channel-cell-*` и `epg-programme-cell-*`.
  - Наблюдаемое: smoke test зелёный + теперь обнаруживает все keys; `flutter analyze` чисто.
  - _Requirements: 1.1, 1.5, 9.5, 9.6, 12.2, 13.1, 13.2, 13.4, 13.5, 14.2_
  - _Depends: 3.1, 3.3, 3.4, 4.1, 4.3, 5.1, 5.2, 5.3, 5.4_
  - _Boundary: EpgScreen integration_

- [ ] 6.2 Player-overlay EPG invariant regression test
  - Создать `megav_iptv/test/features/epg/epg_player_overlay_invariant_test.dart` (Req 11.8, 14.4 — **критично для проверки что закрытый player-overlay-state-machine не сломан**).
  - Тест 1: программный вызов `currentProgramProvider(<channelId>)` через `ProviderContainer` с моковым `ApiClient` возвращает ожидаемое `EpgProgram?` — поведение **идентично** baseline (до данного спека). Сигнатура провайдера не изменилась.
  - Тест 2: программный вызов `upcomingProgramsProvider(<channelId>)` через `ProviderContainer` — поведение идентично baseline. Сигнатура не изменилась.
  - Тест 3: `EpgOverlay` (закрытый widget из `lib/features/player/widgets/epg_overlay.dart`) корректно pump'ится в test environment с моковым `ApiClient` — `find.byType(EpgOverlay)` finds one, no exception. (Этот тест ВАЖЕН — именно он сигналит о любой случайной регрессии closed-spec.)
  - Тест 4: `git diff master --name-only -- megav_iptv/lib/features/player/widgets/epg_overlay.dart megav_iptv/lib/core/playlist/models/epg_program.dart` → empty (через test infra OR documented manual check; если runtime-проверка невозможна в pure dart-тесте, добавить в task 6.3).
  - Наблюдаемое: 3-4 теста зелёных; **0 регрессий closed-spec**.
  - _Requirements: 11.1, 11.7, 11.8, 14.1, 14.4_
  - _Depends: 1.1, 1.2_
  - _Boundary: player-overlay invariant regression_

- [ ] 6.3 Final regression — full `flutter test` + perf greps + closed-spec diff
  - Run `flutter test` в `megav_iptv/`. Ожидаемый итог: **baseline + новые epg-screen tests все зелёные** (Req 14.1).
  - Подсчитать общее число тестов после landing — задокументировать в commit message (e.g., «baseline N + 30 новых = (N+30)/(N+30) зелёных»).
  - Run `flutter analyze megav_iptv/lib/features/epg/ megav_iptv/lib/core/epg/` — 0 issues (Req 14.6).
  - Run `grep -rE "BackdropFilter|ShaderMask|ImageFilter\.blur" megav_iptv/lib/features/epg/ megav_iptv/lib/core/epg/` → 0 hits (Req 13.1).
  - Run `grep -rE "blurRadius:\s*([2-9][0-9]+|1[3-9])" megav_iptv/lib/features/epg/ megav_iptv/lib/core/epg/` → 0 hits (Req 13.2).
  - Verify `pubspec.yaml` без новых пакетов (Req 14.5) — `git diff master -- megav_iptv/pubspec.yaml` → empty.
  - Verify closed-spec файлы НЕ модифицированы (Req 11.1, 14.4):
    - `git diff master --name-only -- megav_iptv/lib/features/player/widgets/epg_overlay.dart` → empty.
    - `git diff master --name-only -- megav_iptv/lib/core/playlist/models/epg_program.dart` → empty.
    - `git diff master --name-only -- megav_iptv/lib/features/home/widgets/ megav_iptv/lib/features/home/home_screen.dart` → empty.
    - `git diff master -- megav_iptv/lib/core/providers/providers.dart` → empty (existing providers unchanged).
    - `git diff master -- megav_iptv/lib/core/api/api_client.dart` → either empty или ровно один appended метод `getEpgWindow` (Req 11.6).
  - Verify router file modification — ровно одна добавленная route entry (`git diff master -- <router-file>` показывает single-line addition).
  - Manual VM Service smoke pass on rtd2851a (если доступен): avg `GPURasterizer::Draw ≤ 16.7 ms` при scroll по EPG screen вдоль обеих осей (Req 13.6).
  - Наблюдаемое: все checks зелёные; commit message содержит конкретные числа.
  - _Requirements: 11.1, 11.6, 11.7, 11.8, 13.1, 13.2, 13.6, 14.1, 14.4, 14.5, 14.6, 14.7_
  - _Depends: 6.1, 6.2, 5.5, 4.4, 4.2, 3.5, 3.2, 2.3, 1.4_
  - _Boundary: final regression gate_

---

## Implementation order

Внутри phase'ов sub-tasks независимы (помечены _Boundary:_), можно делать (P) parallel. Между phases — sequential per `_Depends:_`.

```
1.1 → 1.2 → 1.3 (opt) ↘
                       1.4
                       ↓
              2.1 → 2.2 → 2.3
                          ↓
        ┌───────────────────────────────────┐
        │  Phase 3 (P): 3.1, 3.3, 3.4       │
        │  3.2 (after 3.1), 3.5 (after 3.4) │
        └───────────────────────────────────┘
                          ↓
        ┌───────────────────────────────────┐
        │  Phase 4: 4.1 (depends 3.1/3.3/3.4) →  4.2 │
        │           4.3 → 4.4                       │
        └───────────────────────────────────┘
                          ↓
        ┌───────────────────────────────────┐
        │  Phase 5 (P): 5.1, 5.2, 5.3, 5.4   │
        │  5.5 after 5.1/5.2/5.3             │
        └───────────────────────────────────┘
                          ↓
                       6.1 (integration)
                       6.2 (invariant regression — independent of 6.1)
                          ↓
                       6.3 final regression
```

## Test count expectation

| Phase | New tests added | Cumulative (delta) |
|---|---|---|
| Phase 1 | 6 (4 repo + 2 provider) | +6 |
| Phase 2 | 1 (smoke skeleton) | +7 |
| Phase 3 | 3 (channel rail) + 4 (programme cell) | +14 |
| Phase 4 | 5 (time grid) + 4 (now marker) | +23 |
| Phase 5 | 2 (day picker) + 3 (category filter) + 4 (preview strip) | +32 |
| Phase 6 | 3-4 (invariant regression); smoke updated | +36 (≈) |

Total expected new tests after spec lands: **~36 new** (baseline + 36). Implementer должен зафиксировать актуальное число в commit message task 6.3.

## Perf gate summary (per-task enforcement)

Каждый task создающий новый файл в `lib/features/epg/` или `lib/core/epg/` обязан локально пройти:

```bash
grep -rE "BackdropFilter|ShaderMask|ImageFilter\.blur" megav_iptv/lib/features/epg/ megav_iptv/lib/core/epg/
# expected: 0 hits

grep -rE "blurRadius:\s*([2-9][0-9]+|1[3-9])" megav_iptv/lib/features/epg/ megav_iptv/lib/core/epg/
# expected: 0 hits
```

И в финальном task 6.3 — глобальный gate + closed-spec diff verification.

## Closed-spec invariants summary

| Closed spec | What MUST stay unchanged |
|---|---|
| `player-overlay-state-machine` | `lib/features/player/widgets/epg_overlay.dart` — read-only. Test 6.2 verifies `EpgOverlay` все ещё pump'ится. |
| `home-grid-optimization`, `home-grid-visual-polish` | `lib/features/home/widgets/*`, `home_screen.dart`, `cinema_row.dart`, `cinema_card.dart`, `_grid_tokens.dart` — read-only. `git diff` gate в 6.3. |
| Existing data layer | `lib/core/providers/providers.dart` existing providers (`currentProgramProvider`, `upcomingProgramsProvider`, ...), `EpgProgram` model, existing `ApiClient` methods — read-only. Test 6.2 + `git diff` gate. |
| Foundation specs (`design-system-foundation`, `perf-safe-widgets`, `design-system-atoms`) | `lib/core/theme/*`, `lib/core/perf/*`, `lib/core/ui/atoms/*` — read-only. Imported via barrel only. |
