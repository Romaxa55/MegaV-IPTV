# Implementation Plan — settings-redesign

> Спек: `settings-redesign`. См. `requirements.md` (15 requirements) и `design.md` (7 components + перф-стратегия).
>
> Принципы: **provider + tokens первыми** (perfMetrics + palette wiring) → **shared widgets** (MvToggle/MvPicker/StatTile/PerfHero) → **section files** → **shell rewrite** → **tests** → **regression sweep**. Все коммиты атомарные. Все ранее зелёные тесты остаются зелёными (Req 13.4). Никаких новых пакетов в `pubspec.yaml` (Req 15.5).
>
> **Boundary discipline**: каждая sub-task имеет один файл-владельца. Никакой sub-task не модифицирует closed-foundation файлы (#4 / #13 / #14). Caveats: `decoder_config.dart` получает 2 nullable Boolean fields через `copyWith` (Open Question 1, design.md) — эта модификация явно объявлена в task 4.1.
>
> **Perf rules per file**: каждый created/modified файл ОБЯЗАН пройти локальный grep `BackdropFilter|ShaderMask` → 0 hits, и `blurRadius:\s*([2-9][0-9]+|1[3-9])` → 0 hits (Req 12.1, 12.2, 12.3). Финальный sweep — task 9.2.

---

## 1. Foundation: perfMetricsProvider

- [x] 1.1 Создать `PerfMetrics` модель + `perfMetricsProvider`
  - Создать файл `megav_iptv/lib/core/perf/perf_metrics_provider.dart`.
  - `class PerfMetrics` с полями `final double fps; final int skippedFrames; final int? memoryBytes; final double? bufferSeconds;` + `const` constructor + `==` / `hashCode`.
  - `final perfMetricsProvider = StreamProvider.autoDispose<PerfMetrics>((ref) { ... })`:
    - Использует `WidgetsBinding.instance.addTimingsCallback`.
    - Rolling-window 60 frames, FPS = `1e6 / avgFrameMicros`.
    - Skipped frames = count of `total > 16700µs`.
    - Memory = `ProcessInfo.maxRss` под `try/catch` (платформо-guard).
    - Buffer = `null` (TODO: override через `ProviderScope` когда player layer экспортирует source).
    - `ref.onDispose` снимает `removeTimingsCallback` и закрывает `StreamController`.
  - Наблюдаемое: `flutter analyze megav_iptv/lib/core/perf/perf_metrics_provider.dart` чисто; импорт компилируется.
  - _Requirements: 7.2, 7.3, 7.4, 7.5, 7.6, 7.8_
  - _Boundary: lib/core/perf/perf_metrics_provider.dart (NEW)_

- [x] 1.2 Unit-тест `perf_metrics_provider_test.dart`
  - Создать `megav_iptv/test/core/perf/perf_metrics_provider_test.dart`.
  - Тест 1: первый listener регистрирует callback (через мок `WidgetsBinding`/`SchedulerBinding` или integration-style spy через `addTimingsCallback` тогда verify через `WidgetsBinding.instance.scheduleFrame()` flush).
  - Тест 2: после dispose всех listeners callback removed (auto-dispose контракт).
  - Тест 3: `PerfMetrics` равенство и `hashCode` симметричны.
  - Наблюдаемое: `flutter test test/core/perf/perf_metrics_provider_test.dart` зелёный.
  - _Requirements: 14.3, 7.8_
  - _Depends: 1.1_

---

## 2. Shared widgets (используются в 2+ секциях)

- [x] 2.1 `MvToggle` — кастомный 44×24 pill toggle
  - Создать `megav_iptv/lib/features/settings/widgets/mv_toggle.dart`.
  - `class MvToggle extends StatefulWidget` с `bool value`, `ValueChanged<bool> onChanged`, optional `String? label`, `String? subText`.
  - Внутри: `Focus` + `GestureDetector(onTap: () => onChanged(!value))`.
  - Pill: `Container(width: 44, height: 24, decoration: BoxDecoration(color: value ? palette.accent : palette.surface2, borderRadius: BorderRadius.circular(12), boxShadow: value ? [BoxShadow(color: palette.accentGlow, blurRadius: kSafeShadowBlurMax)] : null))`.
  - Thumb: `AnimatedAlign(alignment: value ? Alignment.centerRight : Alignment.centerLeft, duration: const Duration(milliseconds: 200), curve: Curves.easeInOut, child: Container(18×18 white circle с margin 3))`.
  - Focus visual через `SafeFocusRing(isFocused: _node.hasFocus, child: ...)` из `lib/core/perf/perf_safe_widgets.dart`.
  - Если `label != null` — отрисовать `Row([toggle, SizedBox, Text(label)])`.
  - Наблюдаемое: `flutter analyze` чисто; grep `BackdropFilter|ShaderMask` → 0 hits.
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 12.6_
  - _Boundary: lib/features/settings/widgets/mv_toggle.dart (NEW)_
  - _Depends: 1.1 (none structural; just for reasoning order)_

- [x] 2.2 `MvPicker<T>` — generic option pills row
  - Создать `megav_iptv/lib/features/settings/widgets/mv_picker.dart`.
  - `class MvPicker<T> extends StatelessWidget` с `List<T> options`, `T value`, `ValueChanged<T> onChanged`, `String Function(T) labelOf`, optional `bool enabled = true`, optional `String? disabledHint`.
  - Body: `Wrap(spacing: 8.w, runSpacing: 8.h, children: options.map((opt) => MvButton(...)))`.
  - Active button: `MvButton.accent(label: labelOf(opt), onPressed: enabled ? () => onChanged(opt) : null)`.
  - Inactive: `MvButton.ghost(...)` (или эквивалент API из atoms #14).
  - Если `!enabled && disabledHint != null` — рисовать sub-text под picker через `Theme.of(context).megavText.bodySmall`.
  - Импорты атомов **только** через `package:megav_iptv/core/ui/atoms/atoms.dart` (Req 15.2).
  - Наблюдаемое: `flutter analyze` чисто; widget композирован, нет дублирования chip-renderера.
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 15.2_
  - _Boundary: lib/features/settings/widgets/mv_picker.dart (NEW)_

- [x] 2.3 `StatTile` — pure presentation tile
  - Создать `megav_iptv/lib/features/settings/widgets/stat_tile.dart`.
  - `class StatTile extends StatelessWidget` с `final String label, value, sub; final TrendDirection? trend;` + `const` constructor.
  - `enum TrendDirection { up, down, flat }` в том же файле.
  - Layout: `Container(decoration: BoxDecoration(color: palette.surface1, borderRadius: AppRadius.brMd))` → `Column(crossAxisAlignment: start, children: [Text(label, style: bodySmall), Text(value, style: displayMedium / 44sp), Row([Text(sub), if (trend != null) _TrendArrow(trend)])])`.
  - Никаких stream-подписок — pure presentation.
  - Наблюдаемое: `flutter analyze` чисто; widget testable без provider scope.
  - _Requirements: 7.1 (used by PerfHero), 14.1_
  - _Boundary: lib/features/settings/widgets/stat_tile.dart (NEW)_

- [x] 2.4 `PerfHero` — 4-tile grid wrapping `StatTile`s
  - Создать `megav_iptv/lib/features/settings/widgets/perf_hero.dart`.
  - `class PerfHero extends StatelessWidget` (`const` constructor).
  - Body: `GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: NeverScrollableScrollPhysics(), mainAxisSpacing: 16.h, crossAxisSpacing: 16.w, children: const [_StatTileFps(), _StatTileSkipped(), _StatTileMemory(), _StatTileBuffer()])`.
  - Каждая private tile: `class _StatTileFps extends ConsumerWidget` (const ctor), читает `perfMetricsProvider.select((async) => async.valueOrNull?.fps)`, оборачивает `StatTile` в `RepaintBoundary`. Аналогично для skipped / memory / buffer.
  - Memory tile форматирует `bytes / 1024 / 1024` → `'XXX MB'`, `null` → `'—'`.
  - Buffer tile: `null` → `'—'`, иначе `'${value.toStringAsFixed(1)}s'`.
  - Наблюдаемое: каждая tile обёрнута в `RepaintBoundary`; `select` возвращает только конкретное поле; ребилд одной tile не вызывает ребилд `PerfHero`.
  - _Requirements: 7.1, 7.7, 12.5_
  - _Boundary: lib/features/settings/widgets/perf_hero.dart (NEW)_
  - _Depends: 1.1, 2.3_

---

## 3. Section: Appearance (palette switcher — owns #4 wiring)

- [x] 3.1 `PaletteSwatches` — 6-swatch grid + writer `themeProvider`
  - Создать `megav_iptv/lib/features/settings/widgets/palette_swatches.dart`.
  - `class PaletteSwatches extends ConsumerWidget` (const ctor). Читает `final active = ref.watch(themeProvider);`.
  - Body: `GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: NeverScrollableScrollPhysics(), childAspectRatio: 1.4, mainAxisSpacing: 16.h, crossAxisSpacing: 16.w, children: AppPaletteName.values.map((name) => RepaintBoundary(child: _Swatch(name: name, isActive: name == active, onTap: () => ref.read(themeProvider.notifier).setPalette(name)))).toList(growable: false))`.
  - `_Swatch` — `Focus` + `GestureDetector` → `Container` с 3-bar palette preview (`background`, `accent`, `accentGlow` через `name.palette` extension), label = palette displayName (русский: «Сливовый», «Айвори», «Нуар Кобальт», «Глубокая ночь», «Кримсон», «Современный») + accent left-bar если `isActive`. Focus visual через `SafeFocusRing`.
  - **CRITICAL**: `setPalette` вызывается ТОЛЬКО в `onTap` (Req 3.4, 3.5). Никаких побочных эффектов в build.
  - Наблюдаемое: `flutter analyze` чисто; widget rendered c 6 swatches; tap на swatch вызывает provider mutation один раз.
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 15.1_
  - _Boundary: lib/features/settings/widgets/palette_swatches.dart (NEW)_

- [x] 3.2 `FontPairPicker` — extension-ready заглушка
  - Создать `megav_iptv/lib/features/settings/widgets/font_pair_picker.dart`.
  - `class FontPairPicker extends ConsumerWidget` (const ctor).
  - Перечень pairs: hard-coded `const ['font-cinema']` (Open Question 3 design.md).
  - Body: `MvPicker<String>(options: pairs, value: pairs.first, labelOf: (s) => s == 'font-cinema' ? 'Cinematic' : s, onChanged: (_) {}, enabled: pairs.length > 1, disabledHint: 'Доступна только Cinematic')`.
  - Наблюдаемое: рендерится disabled picker; никаких mutations.
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
  - _Boundary: lib/features/settings/widgets/font_pair_picker.dart (NEW)_
  - _Depends: 2.2_

- [x] 3.3 `SectionAppearance` — composer
  - Создать `megav_iptv/lib/features/settings/widgets/section_appearance.dart`.
  - `class SectionAppearance extends ConsumerWidget` (const ctor).
  - Body: `SingleChildScrollView(padding: ..., child: Column([SectionTitle('Тема и палитра'), SizedBox, PaletteSwatches(), SizedBox(48.h), SectionTitle('Шрифтовая пара'), FontPairPicker()]))`.
  - Импорт `SectionTitle` через `package:megav_iptv/core/ui/atoms/atoms.dart`.
  - Наблюдаемое: `flutter analyze` чисто; widget композирует 2 child widgets.
  - _Requirements: 3.x, 4.x_
  - _Boundary: lib/features/settings/widgets/section_appearance.dart (NEW)_
  - _Depends: 3.1, 3.2_

---

## 4. Section: Player

- [ ] 4.1 Расширить `DecoderConfig` nullable полями `abrEnabled`/`audioPassthrough`
  - Модифицировать `megav_iptv/lib/core/player/decoder_config.dart`:
    - Добавить `final bool? abrEnabled; final bool? audioPassthrough;` в `class DecoderConfig`.
    - Обновить `const` constructor: `this.abrEnabled, this.audioPassthrough` (без default — nullable).
    - Обновить `copyWith` чтобы принимать обе.
    - **DO NOT** менять enum `DecoderMode`/`BufferMode` или `mpvProperties` — pure data extension.
  - **Boundary note**: это модификация ОДНОГО файла за пределами `lib/features/settings/`. Явно разрешено в Req 5.5 + Open Question 1 design.md (in-class change, не cross-cutting).
  - Наблюдаемое: existing tests для `DecoderConfig` (если есть) проходят — nullable поля не ломают существующие callsites.
  - _Requirements: 5.5, 5.6_
  - _Boundary: lib/core/player/decoder_config.dart (MODIFY — in-class data fields only)_

- [ ] 4.2 `SectionPlayer` — pickers + toggles
  - Создать `megav_iptv/lib/features/settings/widgets/section_player.dart`.
  - `class SectionPlayer extends ConsumerWidget` (const ctor).
  - Read once: `final config = ref.watch(decoderConfigProvider);`.
  - Body: `SingleChildScrollView(child: Column([
      SectionTitle('Режим декодера'),
      MvPicker<DecoderMode>(options: DecoderMode.values, value: config.decoderMode, labelOf: (m) => m.label, onChanged: (m) => ref.read(decoderConfigProvider.notifier).state = config.copyWith(decoderMode: m)),
      SectionTitle('Размер буфера'),
      MvPicker<BufferMode>(...),
      MvToggle(label: 'Adaptive Bitrate', value: config.abrEnabled ?? true, onChanged: (v) => ref.read(...).state = config.copyWith(abrEnabled: v)),
      MvToggle(label: 'Audio Passthrough', value: config.audioPassthrough ?? false, onChanged: ...),
    ]))`.
  - Никаких импортов из `lib/core/player/*` кроме `decoder_config.dart` (Req 5.7).
  - Наблюдаемое: `flutter analyze` чисто; widget работает с реальным `decoderConfigProvider`.
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_
  - _Boundary: lib/features/settings/widgets/section_player.dart (NEW)_
  - _Depends: 2.1, 2.2, 4.1_

---

## 5. Section: Network

- [ ] 5.1 `SectionNetwork` — base URL row + cache reset
  - Создать `megav_iptv/lib/features/settings/widgets/section_network.dart`.
  - `class SectionNetwork extends ConsumerWidget` (const ctor).
  - Read: `final url = ref.watch(baseUrlProvider);`.
  - Body: `SingleChildScrollView(child: Column([
      SectionTitle('Бэкенд'),
      Row([Expanded(Text(url, style: bodyMono)), MvIconButton(icon: Icons.edit, onPressed: () => _editUrl(context, ref))]),
      SizedBox(32.h),
      SectionTitle('Кэш плейлистов'),
      MvButton.ghost(label: 'Сброс кэша', onPressed: () => ref.invalidate(categoriesProvider)),
    ]))`.
  - `_editUrl(BuildContext ctx, WidgetRef ref)` показывает `AlertDialog` (opaque `palette.surface1` background — Req 12.1) с `TextField` + Save/Cancel; на Save: `ref.read(baseUrlProvider.notifier).state = controller.text.trim(); ref.invalidate(categoriesProvider);`.
  - **Никаких изменений** в `lib/core/api/*` или `lib/core/playlist/*` (Req 6.5).
  - Наблюдаемое: `flutter analyze` чисто; диалог open/close работает; cache reset вызывает invalidate.
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_
  - _Boundary: lib/features/settings/widgets/section_network.dart (NEW)_
  - _Depends: 2.2_

---

## 6. Section: Performance

- [ ] 6.1 Local providers `impellerEnabledProvider` + `parallaxEnabledProvider`
  - Внутри `megav_iptv/lib/features/settings/widgets/section_performance.dart` (создаётся в 6.2) или в shared file `lib/features/settings/widgets/_perf_local_providers.dart` объявить:
    - `final impellerEnabledProvider = StateProvider<bool>((ref) => true);`
    - `final parallaxEnabledProvider = StateProvider<bool>((ref) => false);`
  - **UI-only** — не подключаются к real Impeller toggle (это отдельный спек).
  - Наблюдаемое: providers compile; default values документированы доком-комментом.
  - _Requirements: 7.9_
  - _Boundary: lib/features/settings/widgets/section_performance.dart or _perf_local_providers.dart (NEW)_

- [ ] 6.2 `SectionPerformance` — PerfHero + 3 toggles
  - Создать `megav_iptv/lib/features/settings/widgets/section_performance.dart`.
  - `class SectionPerformance extends ConsumerWidget` (const ctor).
  - Body: `SingleChildScrollView(child: Column([
      SectionTitle('Метрики'),
      const PerfHero(),
      SizedBox(48.h),
      SectionTitle('Тумблеры'),
      MvToggle(label: 'Impeller engine', value: ref.watch(impellerEnabledProvider), onChanged: (v) => ref.read(impellerEnabledProvider.notifier).state = v),
      MvToggle(label: 'Эффекты parallax', value: ref.watch(parallaxEnabledProvider), onChanged: ...),
      MvToggle(label: 'Adaptive Bitrate', value: ref.watch(decoderConfigProvider).abrEnabled ?? true, onChanged: (v) => ref.read(decoderConfigProvider.notifier).state = ref.read(decoderConfigProvider).copyWith(abrEnabled: v)),
    ]))`.
  - ABR toggle — single-source-of-truth `decoderConfigProvider` (Req 7.9: «re-export Player section toggle for visibility»).
  - Наблюдаемое: `flutter analyze` чисто; PerfHero рендерит 4 tile.
  - _Requirements: 7.1, 7.7, 7.9_
  - _Boundary: lib/features/settings/widgets/section_performance.dart (NEW)_
  - _Depends: 2.1, 2.4, 4.1, 6.1_

---

## 7. Sections: About + Reset

- [ ] 7.1 `SectionAbout` — version/device info + legal stubs
  - Создать `megav_iptv/lib/features/settings/widgets/section_about.dart`.
  - `class SectionAbout extends StatelessWidget` (const ctor — нет provider reads).
  - Read app version: попытка через статический const (если нет — placeholder `'1.0.0'`); device — `Platform.localHostname` + `Platform.operatingSystemVersion` под `try/catch`.
  - Body: `SingleChildScrollView(child: Column([
      SectionTitle('О приложении'),
      _InfoRow('Версия', '$version+$buildNum'),
      _InfoRow('Устройство', deviceName),
      _InfoRow('ОС', osVersion),
      SizedBox(32.h),
      SectionTitle('Аккаунт'),
      _InfoRow('Статус', 'Не выполнен вход'),
      SizedBox(32.h),
      SectionTitle('Юридическая информация'),
      MvButton.ghost(label: 'Политика конфиденциальности', onPressed: () { /* stub */ }),
      MvButton.ghost(label: 'Условия использования', onPressed: () { /* stub */ }),
    ]))`.
  - Никакой auth/HTTP infrastructure (Req 8.5).
  - Наблюдаемое: `flutter analyze` чисто; widget рендерится без crash на пустом package_info.
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_
  - _Boundary: lib/features/settings/widgets/section_about.dart (NEW)_

- [ ] 7.2 `SectionReset` — confirm dialog + reset action
  - Создать `megav_iptv/lib/features/settings/widgets/section_reset.dart`.
  - `class SectionReset extends ConsumerWidget` (const ctor).
  - Body: `SingleChildScrollView(child: Column([
      SectionTitle('Сброс'),
      Text('Вернёт палитру и настройки декодера к значениям по умолчанию. URL бэкенда не сбрасывается.', style: bodyMedium),
      SizedBox(24.h),
      MvButton.accent(label: 'Сбросить настройки', onPressed: () => _confirm(context, ref)),
    ]))`.
  - `_confirm(ctx, ref)`: `showDialog` с `AlertDialog(backgroundColor: palette.surface1, title: 'Подтвердить сброс', content: ..., actions: [TextButton('Отмена'), ElevatedButton('Сбросить', onPressed: () { ref.read(themeProvider.notifier).setPalette(AppPaletteName.noirCobalt); ref.read(decoderConfigProvider.notifier).state = const DecoderConfig(); Navigator.pop(ctx); })])`.
  - **Не трогает** `baseUrlProvider` (Req 9.3 (c)).
  - Наблюдаемое: dialog open/close без crash; reset вызывает 2 provider mutations.
  - _Requirements: 9.1, 9.2, 9.3, 9.4_
  - _Boundary: lib/features/settings/widgets/section_reset.dart (NEW)_

---

## 8. Sidebar nav + screen rewrite

- [ ] 8.1 `SidebarNav` — 6 items, FocusTraversalGroup, D-pad right traverse
  - Создать `megav_iptv/lib/features/settings/widgets/sidebar_nav.dart`.
  - `class SidebarNav extends StatefulWidget` (state = 6 `FocusNode`s).
  - Constructor: `int selectedIndex, ValueChanged<int> onSelected, VoidCallback onTraverseRight`.
  - Body: `Container(width: 300.w, padding: ..., decoration: BoxDecoration(border: Border(right: BorderSide(color: palette.line)))) → Column([
      SizedBox(top padding),
      const Brand(size: 28, showWordmark: true),
      SizedBox(32.h),
      FocusTraversalGroup(child: Column(children: [for i in 0..5 → _SidebarItem(...)])),
    ])`.
  - `_SidebarItem`: `Focus(focusNode: _nodes[i], child: Shortcuts(shortcuts: { LogicalKeySet(LogicalKeyboardKey.arrowRight): const _TraverseRightIntent() }, child: Actions(actions: { _TraverseRightIntent: CallbackAction(onInvoke: (_) => widget.onTraverseRight()) }, child: GestureDetector(onTap: () => widget.onSelected(i), child: Container(padding: ..., decoration: BoxDecoration(borderRadius: AppRadius.brSm, color: i == widget.selectedIndex ? palette.accentSoft : Colors.transparent), child: Row([if (i == selectedIndex) Container(width: 3.w, color: palette.accent), Expanded(Text(sectionLabels[i], style: i == selectedIndex ? bodyLargeAccent : bodyLarge))]))))))`.
  - Wrap каждый item в `SafeFocusRing(isFocused: _nodes[i].hasFocus)`.
  - sectionLabels: `['Тема', 'Плеер', 'Сеть', 'Производительность', 'О приложении', 'Сброс']`.
  - Наблюдаемое: `flutter analyze` чисто; D-pad up/down обходят 6 items; D-pad right вызывает `onTraverseRight`.
  - _Requirements: 1.2, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_
  - _Boundary: lib/features/settings/widgets/sidebar_nav.dart (NEW)_
  - _Depends: 15.x atoms (Brand)_

- [ ] 8.2 `SettingsScreen` REWRITE — sidebar shell + body switcher
  - Заменить содержимое `megav_iptv/lib/features/settings/settings_screen.dart`.
  - Сохранить public widget: `class SettingsScreen extends ConsumerStatefulWidget { const SettingsScreen({super.key}); @override ConsumerState<SettingsScreen> createState() => _SettingsScreenState(); }` (Req 13.2).
  - State: `int _selectedIndex = 0; final FocusNode _bodyFocus = FocusNode(); @override void dispose() { _bodyFocus.dispose(); super.dispose(); }`.
  - Build: `Scaffold(backgroundColor: palette.background, body: Stack(children: [const SafeFilmGrain(), Row([SidebarNav(selectedIndex: _selectedIndex, onSelected: (i) => setState(() => _selectedIndex = i), onTraverseRight: () => _bodyFocus.requestFocus()), Expanded(child: Focus(focusNode: _bodyFocus, child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey(_selectedIndex), child: _bodyForIndex(_selectedIndex)))))])]))`.
  - `Widget _bodyForIndex(int i)`: switch i → `const SectionAppearance()` / `const SectionPlayer()` / `const SectionNetwork()` / `const SectionPerformance()` / `const SectionAbout()` / `const SectionReset()`.
  - **NO** `BackdropFilter`, **NO** `ShaderMask`, **NO** `BoxShadow.blurRadius > 12` (Req 12.1, 12.2, 12.3).
  - Удалить старый `_buildSectionTitle`, `_buildApiServerSetting`, `_buildPlayerEngineSetting`, `_editApiUrl` — функционал переехал в `SectionNetwork` и `SectionPlayer`.
  - Наблюдаемое: `flutter analyze` чисто; route `/settings` рендерит новый shell; D-pad навигация работает; перформанс sweep (task 9.2) проходит.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 12.1, 12.2, 12.3, 12.4, 13.1, 13.2, 13.3_
  - _Boundary: lib/features/settings/settings_screen.dart (REWRITE)_
  - _Depends: 3.3, 4.2, 5.1, 6.2, 7.1, 7.2, 8.1_

---

## 9. Tests + regression

- [ ] 9.1 Widget + golden тесты для секций и shared widgets
  - Создать тестовые файлы:
    - `megav_iptv/test/features/settings/settings_screen_test.dart` — sidebar renders 6 items; activating item switches body; D-pad right transfers focus; никаких `BackdropFilter`/`ShaderMask` в widget tree (`find.byType(BackdropFilter).evaluate().isEmpty`).
    - `megav_iptv/test/features/settings/section_appearance_test.dart` — overriding `themeProvider` с fake `ThemeNotifier` (track `setPalette` calls); tap на swatch[1] → `setPalette(AppPaletteName.values[1])` вызван **ровно 1 раз** (Req 14.2). Active marker обновляется после `ref.watch` tick.
    - `megav_iptv/test/features/settings/section_player_test.dart` — тестируем pickers и toggles: tap на decoder option → `decoderConfigProvider.state.decoderMode` == выбранный; ABR toggle переключает `abrEnabled`.
    - `megav_iptv/test/features/settings/mv_toggle_test.dart` — `pumpWidget(MvToggle(value: false, onChanged: ...))`. Через 50ms thumb на левой стороне; через 250ms на правой (после `onChanged(true)` reciver). Focus ring появляется при `requestFocus`.
    - `megav_iptv/test/features/settings/palette_swatches_golden_test.dart` — `expectLater(find.byType(PaletteSwatches), matchesGoldenFile('palette_swatches_noir_cobalt.png'))`.
  - Запустить `flutter test` — все новые тесты зелёные; все ранее зелёные тесты остаются зелёными (Req 13.4, 14.1–14.5).
  - Наблюдаемое: `flutter test test/features/settings/` — N passed, 0 failed.
  - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 13.4_
  - _Boundary: test/features/settings/* (NEW)_
  - _Depends: 1.2, 2.1, 2.2, 3.1, 3.3, 4.2, 8.2_

- [ ] 9.2 Perf sweep — grep enforcement и `flutter analyze`
  - Запустить `cd megav_iptv && flutter analyze`. Ожидание: `No issues found!` (Req 13.5).
  - Запустить `grep -RnE "BackdropFilter|ShaderMask" megav_iptv/lib/features/settings/ megav_iptv/lib/core/perf/perf_metrics_provider.dart`. Ожидание: 0 hits (Req 12.1, 12.2).
  - Запустить `grep -RnE "blurRadius:\s*([2-9][0-9]+|1[3-9])" megav_iptv/lib/features/settings/ megav_iptv/lib/core/perf/perf_metrics_provider.dart`. Ожидание: 0 hits (Req 12.3).
  - Запустить `flutter test` (полный suite). Ожидание: 100% green; total ≥ предыдущий count + новые из 1.2 и 9.1.
  - Зафиксировать счётчик passing tests до/после в commit message: `tests: NN/NN green (was MM/MM)`.
  - Наблюдаемое: 4 проверки выше — все зелёные.
  - _Requirements: 12.1, 12.2, 12.3, 13.4, 13.5, 15.4_
  - _Boundary: tooling-only (no source changes)_
  - _Depends: 9.1_

- [ ] 9.3 (Optional, manual) Profile-build measurement on rtd2851a
  - Собрать `flutter build apk --profile`, установить на rtd2851a.
  - Открыть Settings, переключиться на Performance section.
  - Снять `getVMTimeline` (см. `flutter-tv-perf.md` § «Как замерять»):
    - `clearVMTimeline` → idle 5 sec → grab trace → парсить `GPURasterizer::Draw`.
    - Прокрутить sidebar D-pad up/down 10 раз → grab trace → парсить.
  - Записать avg / p95 / max в `.kiro/specs/settings-redesign/perf_measurement.md` (создать).
  - Цель (Req 12.7): avg `GPURasterizer::Draw` ≤ 16.7 ms в обоих сценариях.
  - **Этот task — manual gate**: можно пропустить если нет физического устройства. Спек считается имплементированным без него; этот task служит regression-guard для будущих изменений.
  - Наблюдаемое: `perf_measurement.md` создан с числами; OR явно помечен `SKIPPED — no device available`.
  - _Requirements: 12.7_
  - _Boundary: .kiro/specs/settings-redesign/perf_measurement.md (NEW, optional)_
  - _Depends: 9.2_

---

## Summary

- **Total sub-tasks**: 18 (17 mandatory + 1 optional manual measurement).
- **NEW files**: 14 in `lib/features/settings/widgets/` + 1 in `lib/core/perf/` + 1 settings_screen rewrite + 6 test files.
- **MODIFIED files**: `lib/core/player/decoder_config.dart` (in-class data extension only).
- **Foundation specs**: read-only consumers (#4 themeProvider write API, #13 perf widgets, #14 atoms barrel).
- **Perf budget**: enforced via Req 12 + grep sweep in 9.2.
- **Testability**: ≥ 6 new test files, ≥ 8 new test cases.
- **Backward compat**: route + public widget signature preserved (Req 13).
