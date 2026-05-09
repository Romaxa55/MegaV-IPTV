# Implementation Plan — detail-screen-fullbleed

> Спек: `detail-screen-fullbleed`. См. `requirements.md` (12 requirements) и `design.md` (8 components, 8 NEW lib files + 5 NEW test files + 3 modified).
>
> Принципы: **scaffold + providers** → **widget composites** → **screen + route wiring** → **home call-site patches + Hero wrap** → **tests**. Все коммиты атомарные, все 65+ существующих тестов остаются зелёными (Req 10.5, 12.6).
>
> Каждая task снабжена `_Requirements:_` mapping и `_Boundary:_` тегом. `(P)` пометка — задача parallel-friendly с предыдущей если impl-loop поддерживает parallel mode.

---

## Phase 1. Scaffold + Providers

- [x] 1.1 Создать directory scaffold + DetailArgs
  - Создать пустые директории: `megav_iptv/lib/features/detail/`, `megav_iptv/lib/features/detail/widgets/`, `megav_iptv/lib/features/detail/providers/`, `megav_iptv/test/features/detail/`.
  - Создать `megav_iptv/lib/features/detail/providers/detail_arguments.dart` с `class DetailArgs` (3 поля: `channelId`, `preloadedNowPlaying`, `posterImageProvider`) per design.md §1. Const constructor, immutable.
  - Наблюдаемое: `flutter analyze megav_iptv/lib/features/detail/` — 0 ошибок; `DetailArgs` импортируется без runtime instantiation.
  - _Requirements: 1.2_
  - _Boundary: detail/providers/detail_arguments.dart_

- [x] 1.2 Derived providers (`relatedChannelsProvider`, `castListProvider`)
  - Создать `megav_iptv/lib/features/detail/providers/detail_data_provider.dart` с двумя `Provider.family`:
    - `relatedChannelsProvider` per design.md §8 — siblings same `groupTitle`, exclude self, take 8.
    - `castListProvider` per design.md §8 — returns `const []` (stub; no metadata source yet).
  - Импортировать только `flutter_riverpod`, existing `Channel` model, и existing `playlistChannelsProvider` (или эквивалент — implementer проверяет имя в `lib/core/playlist/`).
  - **Important**: если `playlistChannelsProvider` не существует под этим именем — найти аналог через `grep -rn "Channel.*Provider\|channels.*Provider" megav_iptv/lib/`, не вводить новый async fetch.
  - Наблюдаемое: `flutter analyze` чисто; `flutter test` — все existing тесты green (новые providers не regress существующее поведение т.к. lazy).
  - _Requirements: 6.6, 7.7, 8.6_
  - _Boundary: detail/providers/detail_data_provider.dart_

---

## Phase 2. Widget composites (один файл = один widget)

> Implementation order: 2.1 → 2.2 → 2.3 → 2.4 → 2.5 — ни один widget этой фазы не зависит от другого, кроме типов из atoms barrel и perf-safe primitives. Можно делать в любом порядке.

- [ ] 2.1 (P) Widget `DetailBreadcrumb`
  - Создать `megav_iptv/lib/features/detail/widgets/detail_breadcrumb.dart` per design.md §7.
  - `Row(children: [MvIconButton(icon: Icons.arrow_back_ios_new, onPressed: () => context.pop()), SizedBox(width: 14.w), Text(trail, style: Theme.of(context).megavText.metaMono)])`.
  - Импорт atoms через barrel `package:megav_iptv/core/ui/atoms/atoms.dart`.
  - Наблюдаемое: pump в isolation pumps без exception; back-icon виден; trail string рендерится.
  - _Requirements: 8.3_
  - _Boundary: detail/widgets/detail_breadcrumb.dart_

- [ ] 2.2 (P) Widget `HeroMeta`
  - Создать `megav_iptv/lib/features/detail/widgets/hero_meta.dart` per design.md §3.
  - Public API: `title`, `metaItems: List<HeroMetaItem>`, `synopsis: String?`, `chips: List<Widget>` (default `const []`).
  - `HeroMetaItem` — local data class в этом же файле: `(String label, bool isAccent, bool isGold)` (или эквивалент named ctor).
  - Layout: `Column(crossAxisAlignment: start, children: [chips Wrap if any, title Text italic 96.sp с Shadow blur=8, meta Wrap, optional synopsis Text с maxWidth: 720.w])`.
  - **Perf rule**: title `Shadow(blurRadius: 8, ...)` ≤ `kSafeShadowBlurMax`. НЕТ `BoxShadow blurRadius > 12`.
  - Наблюдаемое: pump renders title + omits synopsis при null; meta row пустые items пропускаются.
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 9.2_
  - _Boundary: detail/widgets/hero_meta.dart_

- [ ] 2.3 (P) Widget `ActionRow`
  - Создать `megav_iptv/lib/features/detail/widgets/action_row.dart` per design.md §4.
  - Public API: `playFocusNode: FocusNode`, `onPlay: VoidCallback`, optional callbacks `onFavorite/onTrailer/onShare/onEpg`.
  - `Row(spacing: 12.w, ...)`:
    - `MvButton.primary(focusNode: playFocusNode, leadingIcon: Icons.play_arrow, label: 'Смотреть', onPressed: onPlay)`.
    - For each non-null optional callback: `MvButton.ghost(label: ..., onPressed: cb)`.
  - **Important**: action row НЕ зовёт `context.push` напрямую — только callbacks (Req 4.7). Screen передаёт `_handlePlay` который и делает navigation.
  - Наблюдаемое: pump renders Play first, ghost buttons follow в порядке; null callbacks → buttons омитнуты (не disabled).
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.6, 4.7_
  - _Boundary: detail/widgets/action_row.dart_

- [ ] 2.4 (P) Widget `CastAvatars`
  - Создать `megav_iptv/lib/features/detail/widgets/cast_avatars.dart` per design.md §5.
  - Public API: `cast: List<String>`. Если `cast.isEmpty` → return `SizedBox.shrink()` (Req 6.4).
  - Иначе: `Column(children: [SectionTitle(title: 'В ролях'), SizedBox(height: 12.h), Wrap(spacing: 18.w, runSpacing: 12.h, children: [...])])`.
  - Каждый item: `Row(children: [_GradientAvatar(index: i, size: 36), SizedBox(width: 10.w), Text(name)])`.
  - `_GradientAvatar` — private widget в этом же файле. Static `const List<List<Color>> _avatarPalettes` (5-6 пар цветов в файле).
  - Обернуть весь widget (root) в `ExcludeFocus` для non-focusability (Req 6.5).
  - Наблюдаемое: pump с `cast: []` → renders nothing; pump с 3 names → 3 avatars + 3 names + 1 SectionTitle.
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 11.2_
  - _Boundary: detail/widgets/cast_avatars.dart_

- [ ] 2.5 (P) Widget `RelatedRail`
  - Создать `megav_iptv/lib/features/detail/widgets/related_rail.dart` per design.md §6.
  - Public API: `currentChannelId: String`. Это `ConsumerWidget`, читает `relatedChannelsProvider(currentChannelId)`.
  - Если list empty → return `SizedBox.shrink()` (Req 7.6).
  - Иначе: `Column(children: [SectionTitle('Похожие', italic: 'по настроению', count: list.length), SizedBox(height: 290.h, child: ListView.builder(scrollDirection: Axis.horizontal, cacheExtent: 1500, addAutomaticKeepAlives: true, addRepaintBoundaries: true, clipBehavior: Clip.none, itemBuilder: ...))]`.
  - Каждый item — `Focus + Builder` → `Transform.scale(scale: hasFocus ? 1.08 : 1.0, child: SizedBox(width: 200.w, child: Poster(orientation: PosterOrientation.portrait, ...)))`.
  - На activate (`onFocusChange` не подходит — нужен intent; для прототипа использовать `GestureDetector` + `Actions/Shortcuts(SelectIntent => CallbackAction)`): `context.pushReplacement('/channel/${other.id}', extra: DetailArgs(channelId: other.id))` (Req 7.5).
  - **Perf rules**: НЕ `AnimatedContainer.width`; `Transform.scale` only. ListView config matches `flutter-tv-perf.md`.
  - Наблюдаемое: pump со stub provider возвращающим 5 каналов → 5 Poster items + SectionTitle с count: 5; pump с empty → SizedBox.shrink.
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 9.3, 9.5, 11.3_
  - _Boundary: detail/widgets/related_rail.dart_

---

## Phase 3. Screen + Route wiring

- [ ] 3.1 Создать `DetailScreen` root widget
  - Создать `megav_iptv/lib/features/detail/detail_screen.dart` per design.md §2.
  - `class DetailScreen extends ConsumerStatefulWidget` с params `channelId`, optional `args`. State: `late FocusNode _playFocusNode`.
  - `initState`: `_playFocusNode = FocusNode()`; `WidgetsBinding.instance.addPostFrameCallback((_) => _playFocusNode.requestFocus())`.
  - `dispose`: `_playFocusNode.dispose()`.
  - `build`: `Stack` per design.md §2 (3 layers: SafeBackdrop, gradient overlay, scrollable content).
  - Hero обёртка над portrait poster: `Hero(tag: 'channel-poster-${channelId}', child: Poster(orientation: portrait, ..., width: 460.w, height: 680.h))`.
  - `_handlePlay()`: `ref.read(currentChannelProvider.notifier).state = ...`; `context.push('/player')`.
  - **Perf rules**: HeroBackdrop layer wrapped в `RepaintBoundary` (Req 2.5, 9.4); single `combinedHeroGradient` overlay (Req 2.3, 9.3); no BackdropFilter (Req 2.6, 9.1); no blurRadius > 12 (Req 9.2).
  - Graceful degradation: если `args == null` → resolve channel via `ref.watch(playlistChannelsProvider)` + `pathParameters['id']` (Req 1.3, 11.6). Если канал не найден → render minimal screen.
  - **Important**: НЕТ `BackdropFilter`, `ImageFilter.blur`, `ShaderMask` нигде в этом файле. Только `SafeBackdrop` для hero artwork.
  - Наблюдаемое: `flutter analyze` чисто; `_playFocusNode.hasFocus == true` после `pumpAndSettle()` в test.
  - _Requirements: 1.5, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 5.2, 8.1, 8.2, 8.6, 9.1, 9.2, 9.3, 9.4, 9.7, 11.5, 11.6_
  - _Depends: 1.1, 1.2, 2.1, 2.2, 2.3, 2.4, 2.5_
  - _Boundary: detail/detail_screen.dart_

- [ ] 3.2 Регистрация route в `lib/app.dart`
  - Открыть `megav_iptv/lib/app.dart`, найти `routes:` array (line ~52), добавить **новый** `GoRoute` между `/home` и `/player`:
    ```dart
    GoRoute(
      path: '/channel/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final args = state.extra is DetailArgs ? state.extra as DetailArgs : null;
        return DetailScreen(channelId: id, args: args);
      },
    ),
    ```
  - Импорт: `import 'features/detail/detail_screen.dart';` и `import 'features/detail/providers/detail_arguments.dart';`.
  - **No other modifications в app.dart** — `_router`, `ShellRoute`, `_onRootBackPressed` не трогать.
  - Наблюдаемое: `flutter analyze` чисто; `context.push('/channel/test-id')` в test pumps без route-not-found exception.
  - _Requirements: 1.1_
  - _Depends: 3.1_
  - _Boundary: app.dart route entry_

---

## Phase 4. Home patch + Hero wrap

- [ ] 4.1 Patch `home_screen.dart` call-sites
  - Открыть `megav_iptv/lib/features/home/home_screen.dart`. Найти 2 occurrences `context.push('/player')` (lines 237, 249 в текущей версии).
  - Перед каждым `context.push('/player')` сохранить current channel в provider (это уже делается выше) — оставить как есть.
  - **Заменить** `context.push('/player')` → `context.push('/channel/${item.channelId}', extra: DetailArgs(channelId: item.channelId, preloadedNowPlaying: item))` для случая `_playNowPlaying`. Для второго call-site (если контекст другой — обычная channel-tile tap) — заменить на `context.push('/channel/${channel.id}', extra: DetailArgs(channelId: channel.id))`.
  - Импорт: `import '../detail/providers/detail_arguments.dart';`.
  - **Important**: state-mutation `currentChannelProvider.state = ...` остаётся — detail screen может зависеть от него (`_handlePlay` будет читать). Не удаляем mutation.
  - Наблюдаемое: тап на канал в home теперь открывает `/channel/:id` (можно проверить логом или test). Existing 65+ тестов не сломаны.
  - _Requirements: 1.4_
  - _Depends: 3.2_
  - _Boundary: home/home_screen.dart call-sites_

- [ ] 4.2 Hero wrap в `_card_poster.dart`
  - Открыть `megav_iptv/lib/features/home/widgets/_card_poster.dart` (или эквивалент — implementer проверяет точное имя через `grep -l "_CardPoster\|class.*Poster.*ext.*Stateless" megav_iptv/lib/features/home/widgets/`).
  - Найти inner `Image` / `Poster` widget (тот, который рендерит постер канала).
  - Обернуть его в `Hero(tag: 'channel-poster-${channel.id}', child: <existing widget>)`.
  - **Important**: НЕ менять никаких других частей файла. НЕ менять aspect ratio, padding, decoration. Если `channel.id` не доступен напрямую в widget params — implementer берёт его из ближайшего props (e.g. `widget.channel.id`).
  - Наблюдаемое: визуально home grid выглядит идентично; `flutter test` все 65+ existing pass; новый `find.byWidgetPredicate((w) => w is Hero && (w.tag as String).startsWith('channel-poster-'))` находит нужное Hero.
  - _Requirements: 5.1, 5.5_
  - _Depends: 4.1_
  - _Boundary: home/widgets/_card_poster.dart Hero wrap (additive)_

---

## Phase 5. Tests

> Каждый sub-task создаёт один test file. Все используют `flutter_test` + `ProviderScope` (для Riverpod) + `MaterialApp.router` или `MaterialApp` со стабом router'а.

- [ ] 5.1 Test: `detail_screen_test.dart` — initial focus + smoke
  - Создать `megav_iptv/test/features/detail/detail_screen_test.dart`.
  - Test 1: pump `DetailScreen(channelId: 'test')` обернутый в `ProviderScope(overrides: [...stub providers...])` + `MaterialApp(home: ...)`.
  - Assert: `find.text('Смотреть')` returns one widget (Play button). Assert после `pumpAndSettle()`: focus is on Play (через `tester.binding.focusManager.primaryFocus?.context`).
  - Test 2: pump с null `args` → no crash; minimal screen rendered.
  - Наблюдаемое: 2 тест-кейса pass; всё остальное existing pass.
  - _Requirements: 8.1, 11.6, 12.1_
  - _Depends: 3.1_
  - _Boundary: test/features/detail/detail_screen_test.dart_

- [ ] 5.2 (P) Test: `hero_tag_test.dart` — Hero tag contract
  - Создать `megav_iptv/test/features/detail/hero_tag_test.dart`.
  - Pump `DetailScreen(channelId: 'test-channel-42')` обернутый в `MaterialApp` (хватит обычного, без router) + `ProviderScope`.
  - Assert: `find.byWidgetPredicate((w) => w is Hero && w.tag == 'channel-poster-test-channel-42')` returns одно Hero widget.
  - Наблюдаемое: 1 test pass.
  - _Requirements: 5.2, 12.2_
  - _Depends: 3.1_
  - _Boundary: test/features/detail/hero_tag_test.dart_

- [ ] 5.3 (P) Test: `graceful_degradation_test.dart` — empty cast/related
  - Создать `megav_iptv/test/features/detail/graceful_degradation_test.dart`.
  - Pump с `ProviderScope(overrides: [castListProvider.overrideWith(...) → []; relatedChannelsProvider.overrideWith(...) → []])`.
  - Assert: `find.byType(SectionTitle)` returns `findsNothing` (нет cast section, нет related section).
  - **Note**: если detail имеет другие SectionTitle (e.g. EPG strip) — adapter assert `findsNWidgets(0)` для cast/related title text specifically через `find.text('В ролях')` и `find.text('Похожие')`.
  - Наблюдаемое: 1 test pass.
  - _Requirements: 6.4, 7.6, 11.2, 11.3, 12.3_
  - _Depends: 3.1, 2.4, 2.5_
  - _Boundary: test/features/detail/graceful_degradation_test.dart_

- [ ] 5.4 (P) Test: `play_action_test.dart` — Play → /player navigation
  - Создать `megav_iptv/test/features/detail/play_action_test.dart`.
  - Setup: `GoRouter` с двумя routes — `/channel/:id` и mock `/player`. Track `routerDelegate.currentConfiguration.uri` или counter call-back.
  - Pump app со start at `/channel/test`, найти Play button через `find.text('Смотреть')`, `tester.tap(...)`, `pumpAndSettle()`.
  - Assert: route changed to `/player` (counter == 1, или uri.path == '/player').
  - Наблюдаемое: 1 test pass.
  - _Requirements: 1.5, 4.7, 12.4_
  - _Depends: 3.1, 3.2_
  - _Boundary: test/features/detail/play_action_test.dart_

- [ ] 5.5 Test: `static_audit_test.dart` — perf-rules grep
  - Создать `megav_iptv/test/features/detail/static_audit_test.dart`.
  - Test читает все `.dart` файлы под `megav_iptv/lib/features/detail/` через `Directory(path).listSync(recursive: true)` + `File.readAsStringSync`.
  - Assert per file: regex `BackdropFilter|ShaderMask|ImageFilter\.blur` returns 0 matches (excluding comments).
  - Assert per file: regex `blurRadius:\s*([2-9][0-9]+|1[3-9])` returns 0 matches (blurRadius ≥ 13 forbidden).
  - **Note**: исключить comments — implementer может pre-strip `//.*` из contents перед regex.
  - Наблюдаемое: 1 test pass; если разработчик случайно введёт BackdropFilter — test упадёт.
  - _Requirements: 9.1, 9.2, 12.5_
  - _Depends: 3.1, 2.1, 2.2, 2.3, 2.4, 2.5_
  - _Boundary: test/features/detail/static_audit_test.dart_

---

## Phase 6. Regression check + sign-off

- [ ] 6.1 Запустить полный test suite + analyze
  - `cd megav_iptv && flutter analyze` — 0 errors / 0 warnings.
  - `cd megav_iptv && flutter test` — все existing 65+ тестов + 5 новых тестов из phase 5 = ≥70 tests, все green.
  - Если найдёт regression в existing — НЕ латать тестом, искать root cause (вероятно — Hero wrapper в `_card_poster.dart` или route entry в `app.dart` затронули что-то).
  - **Optional manual check on rtd2851a** (не gating): запустить `flutter run --profile`, открыть detail, скроллить related rail, замерить `getVMTimeline` 5 sec. Avg `GPURasterizer::Draw` ≤ 16.7 ms. Если jank — добавить `RepaintBoundary` perimeter в `detail_screen.dart`.
  - Наблюдаемое: все тесты green; analyze clean; no regression.
  - _Requirements: 9.6 (recommended), 10.5, 12.6_
  - _Depends: 5.1, 5.2, 5.3, 5.4, 5.5_
  - _Boundary: full regression_

---

## Implementation order summary

```
1.1 (scaffold + DetailArgs)
  ↓
1.2 (providers)
  ↓
2.1, 2.2, 2.3, 2.4, 2.5 (parallel — 5 widgets, no cross-deps)
  ↓
3.1 (DetailScreen root) ← needs 1.1, 1.2, 2.x
  ↓
3.2 (route entry) ← needs 3.1
  ↓
4.1 (home call-site patch) ← needs 3.2
  ↓
4.2 (Hero wrap in _card_poster) ← needs 4.1
  ↓
5.1, 5.2, 5.3, 5.4, 5.5 (parallel — 5 tests)
  ↓
6.1 (regression + sign-off)
```

Total: **6 phases, 14 tasks** (1 + 1 + 5 + 2 + 2 + 5 + 1 = 14, but main work-tasks are 14 numbered above — Phase 6 is one verification task).
