# Implementation Plan

> Спек: `design-system-atoms`. См. `requirements.md` (18 requirements) и `design.md` (13 atoms + 3 refactor targets + barrel).
>
> Принципы: **scaffold + 13 atoms** → **refactor 3 existing** → **tests** → **regression**. Все коммиты атомарные, все 65 существующих тестов остаются зелёными (Req 15.5, 17.6).
>
> Последовательность чтобы избежать boundary collision: каждый atom в собственном файле, можно делать (P) parallel-friendly (хотя impl-loop всё равно sequentializes). Refactor existing widgets — после atoms готовы (нужны как imports).

---

## 1. Foundation: directory + barrel

- [x] 1.1 Создать `lib/core/ui/atoms/` directory с pre-populated barrel
  - Создать `megav_iptv/lib/core/ui/atoms/atoms.dart` с заголовочным doc-комментом + 13 pre-written **alphabetically sorted** export lines, каждая закомментирована:
    ```dart
    // export 'brand.dart';
    // export 'chip.dart';
    // export 'genre_tabs.dart';
    // export 'mm_logo.dart';
    // export 'mv_button.dart';
    // export 'mv_icon_button.dart';
    // export 'mv_key.dart';
    // export 'mv_strip.dart';
    // export 'mv_track.dart';
    // export 'poster.dart';
    // export 'remote_hint.dart';
    // export 'section_title.dart';
    // export 'status_bar.dart';
    ```
  - **Convention**: tasks 2.x ОБЯЗАТЕЛЬНО только раскомментируют свою assigned line — никогда не вставляют новую, не переупорядочивают, не удаляют. Это исключает merge-conflicts на barrel.
  - Наблюдаемое: `flutter analyze megav_iptv/lib/core/ui/atoms/atoms.dart` чисто (комментарии не влияют); `flutter test` 65/65 не сломан.
  - _Requirements: 1.1, 1.2, 1.3_
  - _Boundary: atoms barrel scaffold_

---

## 2. Core: 13 atoms (один файл = один atom)

Каждый sub-task 2.x создаёт один atom file и раскомментирует соответствующий `export` в `atoms.dart`. Tests добавляются в task 4.x — здесь только реализация.

> **⚠ Implementation order ≠ numerical order.** Из-за cross-atom dependencies (Poster→MvTrack, SectionTitle→Chip+MvButton, RemoteHint→MvKey) impl-loop ОБЯЗАН следовать порядку из «Implementation order» note в конце §2, не 2.1→2.13 sequentially. В частности 2.10 ДОЛЖЕН быть выполнен раньше 2.9; 2.6 раньше 2.7; 2.10/2.11/2.13 раньше 2.7/2.8/2.9/2.12. Sub-task numbers сохранены для traceability к design.md, но ordering определяется `_Depends:_` annotations.

> **⚠ Perf rules per atom**: каждый atom-файл ОБЯЗАН пройти `grep "BackdropFilter\|ShaderMask"` — 0 hits, и `grep -E "blurRadius:\s*([2-9][0-9]+|1[3-9])"` — 0 hits. Это enforced в task 4.6 grep, но implementer должен проверять локально перед report.

- [x] 2.1 Atom `MvKey` (single keycap — нужен раньше т.к. `RemoteHint` композирует его)
  - Создать `megav_iptv/lib/core/ui/atoms/mv_key.dart` с `class MvKey extends StatelessWidget` (required `glyph`, optional `size`).
  - Background `AppPalette.surface2`, rounding `AppRadius.brXs`, height ≈ 26px, text via `Theme.of(context).megavText.metaMono`.
  - Раскомментировать `export 'mv_key.dart';` в `atoms.dart`.
  - Наблюдаемое: `flutter analyze` чисто; widget импортируется через barrel.
  - _Requirements: 14.1, 14.2, 14.3_
  - _Boundary: MvKey_

- [x] 2.2 (P) Atom `MMLogo`
  - Создать `megav_iptv/lib/core/ui/atoms/mm_logo.dart` с `class MMLogo extends StatelessWidget` (default `size = 38`, optional `background`).
  - Square `Container` с centered text «M» (display font), default background `AppPalette.accent`.
  - Раскомментировать `export 'mm_logo.dart';` в `atoms.dart`.
  - Наблюдаемое: `flutter analyze` чисто; size 38×38 enforced.
  - _Requirements: 6.1, 6.2, 6.3_
  - _Depends: 1.1_
  - _Boundary: MMLogo_

- [x] 2.3 Atom `Chip` + `ChipVariant` enum
  - Создать `megav_iptv/lib/core/ui/atoms/chip.dart` с:
    - `enum ChipVariant { live, brand, gold, ghost, defaultVariant }`.
    - `class Chip extends StatefulWidget` (required `label`, optional `icon`, default `variant = defaultVariant`).
    - `_ChipState` создаёт `AnimationController(duration: 1.2s, repeat=true)` ТОЛЬКО когда `variant == live`; иначе controller остаётся null.
    - При variant == live: pulse dot 6×6 px с `FadeTransition` driven by controller. Pulse + dot вместе обернуть в `RepaintBoundary` (Req 4.3, 16.5).
    - Background mapping per design.md § 3 Chip atom.
  - Раскомментировать `export 'chip.dart';` в `atoms.dart`.
  - Наблюдаемое: для каждого из 5 variants `decoration.color` различается; live variant имеет `RepaintBoundary` ancestor над dot widget.
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 16.5_
  - _Depends: 1.1_
  - _Boundary: Chip_

- [x] 2.4 (P) Atom `Brand`
  - Создать `megav_iptv/lib/core/ui/atoms/brand.dart` с `class Brand extends StatelessWidget` (default `size = 32`, default `showWordmark = true`).
  - Gradient square mark via `Container(width: size, height: size, decoration: BoxDecoration(gradient: LinearGradient(colors: [palette.accent, palette.accentGlow]), borderRadius: BorderRadius.circular(size * 0.18)))`.
  - **Cutout geometry pinned**: внутри square — горизонтальная bar (имитация «M» logo cut), shape: `Positioned(left: size * 0.20, right: size * 0.20, top: size * 0.55, height: size * 0.12, child: ColoredBox(color: palette.background))`. Если handoff `atoms.jsx` показывает иную geometry — implementer следует JSX как source of truth.
  - Optional wordmark «MegaV» через `Theme.of(context).megavText.displayLarge` справа от square (если `showWordmark`).
  - Раскомментировать `export 'brand.dart';` в `atoms.dart`.
  - Наблюдаемое: при `showWordmark: false` в дереве нет Text widget; gradient использует palette tokens; cutout bar присутствует как ColoredBox child.
  - _Requirements: 2.1, 2.2, 2.3, 2.4_
  - _Depends: 1.1_
  - _Boundary: Brand_

- [x] 2.5 Atom `StatusBar`
  - Создать `megav_iptv/lib/core/ui/atoms/status_bar.dart` с `class StatusBar extends StatelessWidget` (optional `flag`, `city`, `tempC`, `time`).
  - **SafePill API verification**: `SafePill` принимает `tint`/`alpha`/`borderRadius` (см. `lib/core/perf/perf_safe_widgets.dart`). Use `SafePill(tint: AppColors.surface, alpha: 0.85, borderRadius: AppRadius.brSm, child: Row([...]))` — это удовлетворяет Req 3.3 (background `surface2` + radius `brSm`). Если SafePill не принимает override параметров — fallback to `DecoratedBox(decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.brSm), child: Padding(padding: ..., child: Row([...]))`).
  - Row компонует только non-null поля; spacing через `SizedBox(width: 8)` между элементами.
  - Никакой clock-tick логики — `time` приходит снаружи.
  - Раскомментировать `export 'status_bar.dart';` в `atoms.dart`.
  - Наблюдаемое: при всех null-полях рендерит пустой pill (или `SizedBox.shrink` если все null — implementer выбирает); при заполненных — горизонтальный row с иконками/текстом без empty padding.
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 16.4_
  - _Depends: 1.1_
  - _Boundary: StatusBar_

- [x] 2.6 Atom `MvTrack` (progress bar)
  - Создать `megav_iptv/lib/core/ui/atoms/mv_track.dart` с `class MvTrack extends StatelessWidget` (required `progress`, optional `showKnob = false`, `height = 4`).
  - В `build`: clamp progress to [0,1]; `Stack(children: [bg ColoredBox(AppColors.surface), AnimatedFractionallySizedBox(duration: 250ms, curve: fastOutSlowIn, alignment: centerLeft, widthFactor: clamped, child: ColoredBox(AppColors.primary)), if(showKnob) knob])`.
  - Anim animates **только** widthFactor (paint property) — никакого relayout siblings (Req 12.4, 16.6).
  - Раскомментировать `export 'mv_track.dart';` в `atoms.dart`.
  - Наблюдаемое: после pump с progress=0.5 + 250ms — `AnimatedFractionallySizedBox.widthFactor == 0.5`.
  - _Requirements: 12.1, 12.2, 12.3, 12.4, 16.6_
  - _Depends: 1.1_
  - _Boundary: MvTrack_

- [ ] 2.7 Atom `Poster` + `PosterOrientation` enum
  - Создать `megav_iptv/lib/core/ui/atoms/poster.dart` с:
    - `enum PosterOrientation { landscape, portrait }`.
    - `class Poster extends StatelessWidget` (required `image`, optional `orientation`, `title`, `subtitle`, `hideText`, `badgeTL`, `badgeTR`, `progress`, `isFocused`).
    - Build wraps content в `SafeFocusRing(isFocused: isFocused, child: AspectRatio(...))`.
    - Aspect ratio: 16/9 для landscape, 2/3 для portrait.
    - `Image(image: image, fit: BoxFit.cover, errorBuilder: ... => ColoredBox(AppColors.cardBg))`.
    - Если !hideText: scrim gradient + title (`bodyDefault`) + optional subtitle (`bodyDim`) у нижнего края.
    - Если progress != null: `MvTrack(progress: progress)` у нижнего края (внутри AspectRatio).
    - badgeTL/TR: `Positioned(top: 8, left/right: 8, child: ...)`.
  - Раскомментировать `export 'poster.dart';` в `atoms.dart`.
  - Наблюдаемое: с `hideText: true` нет Text widget; с `progress: 0.6` присутствует MvTrack в дереве; SafeFocusRing wraps top-level.
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 16.3_
  - _Depends: 1.1, 2.6 (нужен MvTrack)_
  - _Boundary: Poster_

- [ ] 2.8 Atom `GenreTabs`
  - Создать `megav_iptv/lib/core/ui/atoms/genre_tabs.dart` с `class GenreTabs extends StatefulWidget` (required `labels`, `activeIndex`, optional `onTabChanged`).
  - Render `Row` of tab labels; underline — `AnimatedPositioned(duration: 150ms, curve: fastOutSlowIn, ...)` с `Container(height: 2, color: AppColors.primary)` под активным табом.
  - Tap/focus меняет index → `onTabChanged(newIndex)` callback (state управление снаружи).
  - Раскомментировать `export 'genre_tabs.dart';` в `atoms.dart`.
  - Наблюдаемое: при изменении `activeIndex` от 0 до 1 + `tester.pump(200ms)` — позиция `AnimatedPositioned` сместилась.
  - _Requirements: 7.1, 7.2, 7.3, 7.4_
  - _Depends: 1.1_
  - _Boundary: GenreTabs_

- [ ] 2.9 (P) Atom `SectionTitle`
  - Создать `megav_iptv/lib/core/ui/atoms/section_title.dart` с `class SectionTitle extends StatelessWidget` (required `title`, optional `emphasis`, `count`, `onMore`).
  - Title — `Theme.of(context).megavText.displayLarge`. Emphasis (italic) — `displayItalic`. Count — small badge через `Chip(variant: ghost, label: count.toString())`. «more →» — `MvButton.ghost(label: 'more →', onPressed: onMore)` если onMore != null.
  - Раскомментировать `export 'section_title.dart';` в `atoms.dart`.
  - Наблюдаемое: при `emphasis: 'для тебя'` — italic Text присутствует; при `onMore: null` — нет «more →» button.
  - _Requirements: 8.1, 8.2, 8.3, 8.4_
  - _Depends: 1.1, 2.3 (Chip), 2.10 (MvButton — но порядок tasks обеспечивает 2.10 раньше 2.9; см. note)_
  - _Boundary: SectionTitle_

  > **Note**: Поскольку 2.9 зависит от MvButton (2.10), порядок переставлен: 2.10 должна выполниться РАНЬШЕ 2.9. Tasks 2.9 фактически выполняется после 2.10 (см. ниже Implementation order).

- [ ] 2.10 Atom `MvButton` + `MvButtonSize` enum (3 named ctor variants)
  - Создать `megav_iptv/lib/core/ui/atoms/mv_button.dart` с:
    - `enum MvButtonSize { small, medium }` (small=32px height, medium=44px height).
    - Internal `enum _MvButtonVariant { primary, ghost, accent }`.
    - `class MvButton extends StatelessWidget` с тремя named ctors `MvButton.primary`, `MvButton.ghost`, `MvButton.accent` (все принимают `label`, `onPressed`, optional `icon`, `size`, `isFocused`).
    - В `build`: switch по `_variant` определяет fg/bg colors. Hover/pressed colors берутся из `ComputedColors.from(palette)` (pre-computed, не runtime lerp — Req 10.8). При `isFocused` — wrap в `SafeFocusRing`.
  - Раскомментировать `export 'mv_button.dart';` в `atoms.dart`.
  - Наблюдаемое: 3 variants дают разные `decoration.color`; focused state добавляет SafeFocusRing ancestor.
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 16.3_
  - _Depends: 1.1_
  - _Boundary: MvButton_

- [ ] 2.11 Atom `MvIconButton`
  - Создать `megav_iptv/lib/core/ui/atoms/mv_icon_button.dart` с `class MvIconButton extends StatelessWidget` (required `icon`, `onPressed`, optional `size = 38`, `isFocused = false`).
  - Build: `SafeFocusRing(isFocused, child: SizedBox.square(dimension: size, child: Material(borderRadius: AppRadius.brSm, ...)))` или эквивалент с InkWell для tap.
  - Раскомментировать `export 'mv_icon_button.dart';` в `atoms.dart`.
  - Наблюдаемое: 38×38 size; focused → SafeFocusRing ancestor.
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 16.3_
  - _Depends: 1.1_
  - _Boundary: MvIconButton_

- [ ] 2.12 Atom `RemoteHint` + `RemoteHintEntry` value class
  - Создать `megav_iptv/lib/core/ui/atoms/remote_hint.dart` с:
    - `class RemoteHintEntry` (immutable, `glyph` + `label` String fields).
    - `class RemoteHint extends StatelessWidget` (required `hints: List<RemoteHintEntry>`, optional `alignment = MainAxisAlignment.start`).
    - Build: `Row(mainAxisAlignment: alignment, children: hints.map((e) => MvKey(glyph: e.glyph) + Text(e.label)).toList())` + spacing.
  - Раскомментировать `export 'remote_hint.dart';` в `atoms.dart`.
  - Наблюдаемое: для 3 entries в дереве — 3 MvKey instances.
  - _Requirements: 9.1, 9.2, 9.3, 9.4_
  - _Depends: 1.1, 2.1 (MvKey)_
  - _Boundary: RemoteHint_

- [ ] 2.13 Atom `MvStrip` (filmstrip frames, decorative)
  - Создать `megav_iptv/lib/core/ui/atoms/mv_strip.dart` с `class MvStrip extends StatelessWidget` (default `frameCount = 7`, `tileWidth = 80`, `tileHeight = 56`).
  - Decorative `Row` of N tiles; каждый — `Container(width: tileWidth, height: tileHeight, decoration: BoxDecoration(border: Border.all(color: AppColors.lineStrong, width: 1), borderRadius: BorderRadius.circular(2)))`.
  - **Notch geometry pinned**: 4 notches per tile — 2 сверху + 2 снизу. Каждая notch: `Container(width: tileWidth * 0.10, height: 4, color: AppColors.background)` positioned at `top: -2` (overhang) + `left: tileWidth * 0.20` and `tileWidth * 0.70` для верхних (mirror для нижних: `bottom: -2`). Стилизация под sprocket-holes киноплёнки.
  - Spacing между tiles: `SizedBox(width: 4)`.
  - Чисто декоративный — без interaction, focus, animation.
  - Раскомментировать `export 'mv_strip.dart';` в `atoms.dart`.
  - Наблюдаемое: 7 child Containers + 28 notch overlays; нет GestureDetector / FocusableActionDetector.
  - _Requirements: 13.1, 13.2, 13.3_
  - _Depends: 1.1_
  - _Boundary: MvStrip_

> **Implementation order для импл-loop'а**: т.к. dependencies — 2.7 нужен 2.6, 2.9 нужен 2.3 + 2.10, 2.12 нужен 2.1 — implementer должен выполнить в порядке: 1.1, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.10, 2.11, 2.13, 2.7, 2.8, 2.9, 2.12. Главные dependencies: MvKey раньше RemoteHint; MvButton раньше SectionTitle; MvTrack раньше Poster; Chip раньше SectionTitle. Sub-task numbers сохраняем как есть для traceability к design.md.

---

## 3. Refactor existing widgets (backward-compat)

- [ ] 3.1 Refactor `glass_button.dart` → use `MvIconButton` internally
  - Открыть `megav_iptv/lib/features/home/widgets/glass_button.dart`.
  - **Public API contract — ОБЯЗАТЕЛЬНО preserved verbatim** (verified actual signature): `GlassButton({Key? key, required IconData icon, required VoidCallback onTap})`. NO renames, NO nullability changes, NO new required params. `GlassButton` — **icon-only** widget (НЕ `MvButton.ghost`!).
  - Заменить internal build на:
    ```dart
    @override
    Widget build(BuildContext context) {
      return MvIconButton(
        icon: Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.50)),
        onPressed: onTap,
        size: 48,
      );
    }
    ```
  - Импорт `import '../../../core/ui/atoms/atoms.dart';` (relative path).
  - **Verification step ОБЯЗАТЕЛЬНЫЙ**: до commit'а прогнать `grep -rn "GlassButton(" megav_iptv/lib/` — каждое использование должно остаться compile-valid после refactor (params signature unchanged).
  - Наблюдаемое: `flutter test` 65/65 проходит без касания тестов; `flutter analyze` 0 errors; все existing call-sites (`GlassButton(icon: Icons.X, onTap: () => ...)`) продолжают работать.
  - _Requirements: 15.1, 15.5_
  - _Depends: 2.11 (MvIconButton готов)_
  - _Boundary: glass_button proxy_

- [ ] 3.2 Refactor `hero_badges.dart` → use `Chip` atom (NOT MMLogo)
  - Открыть `megav_iptv/lib/features/home/widgets/hero_badges.dart`.
  - **Public API contract — ОБЯЗАТЕЛЬНО preserved verbatim** (verified actual signature): `HeroBadge({Key? key, required String text, required Color color, Color? textColor, Color? borderColor, bool showPulse = false, IconData? icon})` — это **single configurable badge** widget с optional pulse и optional leading icon, НЕ row, НЕ MMLogo.
  - Заменить internal build на:
    ```dart
    @override
    Widget build(BuildContext context) {
      final variant = showPulse ? ChipVariant.live : ChipVariant.brand;
      return Chip(
        label: text,
        variant: variant,
        icon: icon != null ? Icon(icon, size: 14) : null,
      );
    }
    ```
  - Legacy `color`/`textColor`/`borderColor` параметры становятся **decorative no-ops** — `Chip` derives all colors from active palette per variant. Это намеренный visual drift в рамках Req 2.2 carry-over from foundation #4 («negligible color drift»). Если call-sites зависят от exact colors — отдельный follow-up issue.
  - Импорт `import '../../../core/ui/atoms/atoms.dart';`.
  - **MMLogo НЕ involved** в HeroBadge refactor (sanity reviewer note).
  - Наблюдаемое: `flutter test` 65/65; existing widget tests касающиеся hero_badges проходят (визуальный drift в рамках allowed range).
  - _Requirements: 15.2, 15.5_
  - _Depends: 2.3 (Chip)_
  - _Boundary: hero_badges proxy_

- [ ] 3.3 Refactor `channel_quality_badge.dart` → use `Chip(variant: brand)`
  - Открыть `megav_iptv/lib/core/ui/channel_quality_badge.dart` (NOT в `lib/features/home/widgets/` — verified actual location).
  - **Public API contract — ОБЯЗАТЕЛЬНО preserved verbatim** (verified): `ChannelQualityBadge({Key? key, required ChannelStreamQuality quality, bool compact = false})`.
  - Текущая реализация резолвит `quality` enum в bg/fg/border colors через switch и рисует `Container(padding: EdgeInsets.symmetric(...), decoration: BoxDecoration(color: bg, ...), child: Text(quality.label, ...))`.
  - Заменить internal build на:
    ```dart
    @override
    Widget build(BuildContext context) {
      // Map quality -> chip variant (brand for all qualities; visual differentiation
      // can come from icon or label, не color drift).
      return Chip(
        label: quality.label, // or 'UHD'/'HD'/'SD' depending on enum API
        variant: ChipVariant.brand,
      );
    }
    ```
  - **Compact mode**: текущая `compact: true` уменьшает padding и font-size. Если `Chip` не принимает `compact` параметр — fallback to wrapping in `Transform.scale(scale: compact ? 0.85 : 1.0, child: Chip(...))`. Альтернативно — оставить compact branch с inline Container и только non-compact branch делать через Chip; documented trade-off.
  - Импорт `import 'atoms/atoms.dart';` (channel_quality_badge.dart лежит в `lib/core/ui/`, atoms barrel — в `lib/core/ui/atoms/atoms.dart`, relative import).
  - Наблюдаемое: `flutter test` 65/65; visually badge looks similar (allowed drift per Req 2.2).
  - _Requirements: 15.4, 15.5_
  - _Depends: 2.3 (Chip)_
  - _Boundary: channel_quality_badge proxy_

> _Card_poster.dart НЕ рефакторится (Req 15.3 + design.md decision — closed spec ownership)._

---

## 4. Tests

- [ ] 4.1 Smoke tests для всех 13 atoms (1 test per atom — render + no exception)
  - Создать `megav_iptv/test/core/ui/atoms/atoms_smoke_test.dart`.
  - Для каждого из 13 atoms: pump с минимально-required параметрами, expect `find.byType(<Atom>)` finds 1, `tester.takeException()` is null.
  - Запуск: `flutter test test/core/ui/atoms/atoms_smoke_test.dart` — 13/13 зелёных.
  - Наблюдаемое: 13 тестов проходят на первом run.
  - _Requirements: 17.1_
  - _Depends: 2.1-2.13 (все atoms готовы)_
  - _Boundary: atoms_smoke_test_

- [ ] 4.2 (P) Widget tests для `Chip` 5 variants
  - Создать `megav_iptv/test/core/ui/atoms/chip_test.dart`.
  - 5 тестов: для каждого `ChipVariant` pump + assert `decoration.color` отличается между variants.
  - Дополнительный тест: `live` variant имеет `RepaintBoundary` ancestor над animated dot.
  - Запуск: 6+ зелёных.
  - _Requirements: 17.2, 4.3, 16.5_
  - _Depends: 2.3_
  - _Boundary: chip_test_

- [ ] 4.3 (P) Widget tests для `MvButton` 3 variants
  - Создать `megav_iptv/test/core/ui/atoms/mv_button_test.dart`.
  - 3 теста: для каждого MvButton variant pump + assert fg/bg colors различаются.
  - Дополнительный: `isFocused: true` → SafeFocusRing ancestor найдён.
  - _Requirements: 17.3, 16.3_
  - _Depends: 2.10_
  - _Boundary: mv_button_test_

- [ ] 4.4 Widget tests для `Poster` (hideText, progress)
  - Создать `megav_iptv/test/core/ui/atoms/poster_test.dart`.
  - 3 теста: hideText:true → no Text in tree; progress:0.6 → MvTrack present in tree; orientation flip → AspectRatio.aspectRatio differs.
  - _Requirements: 17.4_
  - _Depends: 2.7_
  - _Boundary: poster_test_

- [ ] 4.5 (P) Widget tests для `MvTrack` (progress = 0.5)
  - Создать `megav_iptv/test/core/ui/atoms/mv_track_test.dart`.
  - Тесты: progress:0.5 + tester.pump(300ms) → AnimatedFractionallySizedBox.widthFactor == 0.5; progress:1.5 → clamped to 1.0; progress:-0.3 → clamped to 0.0.
  - _Requirements: 17.5, 12.4_
  - _Depends: 2.6_
  - _Boundary: mv_track_test_

- [ ] 4.6 Полный прогон тестов и regression check
  - `cd megav_iptv && flutter test` — ожидаемо ≥ 80 (65 baseline + 13 smoke + 6 chip + 4 mv_button + 3 poster + 3 mv_track).
  - `flutter analyze` — 0 errors.
  - `grep -rn "BackdropFilter\|ShaderMask" megav_iptv/lib/core/ui/atoms/` — пусто (только doc-comments если есть).
  - `grep -rnE "blurRadius:\s*([2-9][0-9]+|1[3-9])" megav_iptv/lib/core/ui/atoms/` — пусто (Req 16.1, 16.2).
  - **Pubspec gate (Req 18.1)**: `git diff --exit-code megav_iptv/pubspec.yaml megav_iptv/pubspec.lock` — exit 0 означает «никаких новых пакетов не добавлено». Если diff есть — fail.
  - Refactored existing widgets compile; closed специй home-grid-* не сломаны (через визуальные тесты `cinema_row_fade_edge_test.dart` etc.).
  - Наблюдаемое: ≥ 80/80 зелёных, exit code 0; analyze 0 errors; perf-grep чистый; pubspec diff пусто.
  - _Requirements: 15.5, 16.1, 16.2, 16.3, 16.4, 16.5, 16.6, 17.6, 18.1, 18.2_
  - _Depends: 4.1, 4.2, 4.3, 4.4, 4.5, 3.1, 3.2, 3.3_
  - _Boundary: full project regression_

---

## 5. Optional / out-of-scope в этом спеке

- Golden tests per atom (Req 17.7) — recommended но не обязательно. Может быть отдельным follow-up issue если Wave 3 потребует.
- TV-bench performance verification (Req 16.x) — operator-time, не gating этот спек.

---

## Implementation Notes

(пусто на момент генерации; импл-цикл может добавить cross-cutting findings)
