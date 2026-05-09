# Implementation Plan

> Спек: `perf-safe-widgets`. См. `requirements.md` (11 требований) и `design.md` (4 widgets + computed_colors + helper factory + steering augmentation).
>
> Принципы: foundation (asset + computed_colors) → core widgets → theme integration → tests → steering doc. Все коммиты атомарные, существующие 53 теста не ломаем (Req 9.2).

---

## 1. Foundation: asset + pre-mixed colors

- [x] 1.1 Добавить baked grain overlay PNG asset
  - Prereq tooling: `brew install imagemagick pngquant` (или эквивалент на CI).
  - Сгенерировать `megav_iptv/assets/grain_overlay.png` через ImageMagick (deterministic recipe):
    ```
    convert -size 1024x1024 xc:'rgb(128,128,128)' \
      +noise Random -channel RGB -separate -average \
      -evaluate Multiply 0.5 -level 40%,60% png24:megav_iptv/assets/grain_overlay.png
    pngquant --quality=70-85 --speed=1 --strip --force \
      --output megav_iptv/assets/grain_overlay.png megav_iptv/assets/grain_overlay.png
    ```
    (Если pngquant отказывается quantize при quality range — снизить до `--quality=50-80`.)
  - Acceptance check визуально: серый шум без цветовых артефактов, средняя яркость ≈ 50%, размер ≤ 50kb (типично 30-40kb).
  - Зарегистрировать asset в `megav_iptv/pubspec.yaml` под `flutter.assets:` ровно одной строкой.
  - Запустить `cd megav_iptv && flutter pub get && flutter analyze` — analyze чисто.
  - Наблюдаемое: `flutter test` на одной static-loading проверке (через `rootBundle.load('assets/grain_overlay.png')`) возвращает non-empty `ByteData` без exception; размер `assets/grain_overlay.png` ≤ 50kb.
  - _Requirements: 4.2, 4.5_
  - _Boundary: assets + pubspec_

- [x] 1.2 (P) Создать `ComputedColors` class + factory `from(AppPalette)`
  - Создать `megav_iptv/lib/core/theme/computed_colors.dart`.
  - `class ComputedColors` с тремя `final Color` полями: `textTintAccent`, `accentTintText`, `surfaceTintAccent` (private named ctor).
  - `factory ComputedColors.from(AppPalette p)` использует `Color.lerp(text, accent, 0.08)!` и т.д. для всех трёх tints.
  - Публичные имена и signature точно совпадают с design.md § Components > ComputedColors.
  - Наблюдаемое: `flutter analyze lib/core/theme/computed_colors.dart` чисто; для одной палитры все три поля non-null `Color`.
  - _Requirements: 6.1, 6.2, 6.3, 6.5_
  - _Depends: none (independent of 1.1)_
  - _Boundary: ComputedColors_

---

## 2. Core: 4 safe widgets + 1 helper

- [x] 2.1 Создать `SafePill` widget + scaffold `perf_safe_widgets.dart`
  - Создать `megav_iptv/lib/core/perf/perf_safe_widgets.dart` (новый file — этот task его создаёт).
  - В файле: `class SafePill extends StatelessWidget` с required `child`, optional `tint` / `alpha` / `borderRadius` / `padding`. Default `tint = AppColors.surface`, `alpha = 0.85`, `borderRadius = AppRadius.brSm`.
  - Build возвращает `Container(decoration: BoxDecoration(color: Color.fromRGBO(...alpha), borderRadius: ...), padding: ..., child: child)`.
  - В файле также объявить top-level `const double kSafeShadowBlurMax = 12.0;` — это намеренно cross-cutting константа, used by Task 3.1 audit и Req 7.3; добавляется здесь чтобы избежать второго commit в тот же file.
  - **Никаких** `BackdropFilter`, `BlendMode` отличного от default, `blurRadius > 0` в этом widget.
  - Наблюдаемое: `flutter analyze lib/core/perf/perf_safe_widgets.dart` чисто; widget компилируется и не имеет import цикла с theme.
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 7.3_
  - _Depends: 1.1 (нужны foundation-палитры через AppColors)_
  - _Boundary: SafePill + perf_safe_widgets file scaffold + kSafeShadowBlurMax constant (cross-cutting, intentional one-shot scaffolding)_

- [x] 2.2 Создать `SafeFocusRing` widget
  - В уже существующем `lib/core/perf/perf_safe_widgets.dart` добавить `class SafeFocusRing extends StatelessWidget`.
  - Required: `child`, `isFocused`. Optional: `ringColor` (default `AppColors.primary`), `gap = 3.0`, `thickness = 3.0`, `duration = Duration(milliseconds: 150)`.
  - Build возвращает `AnimatedContainer` с `BoxDecoration.boxShadow` из двух stacked solid `BoxShadow` (inner для gap = `AppColors.background`, outer для ring = `ringColor`); оба с `blurRadius: 0`. При `!isFocused` — пустой `boxShadow: const []`.
  - **Никаких** `blurRadius > 0`. Транзишн на 150ms через `AnimatedContainer` (GPU-only, no relayout).
  - Наблюдаемое: после `tester.pump()` от `isFocused: false` до `true` декорация контейнера получает 2 BoxShadow с `blurRadius == 0`; transition завершается ≤ 150ms (проверяется в task 4.1).
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_
  - _Depends: 2.1 (file already exists)_
  - _Boundary: SafeFocusRing_

- [x] 2.3 Создать `SafeFilmGrain` widget
  - В `lib/core/perf/perf_safe_widgets.dart` добавить `class SafeFilmGrain extends StatelessWidget`.
  - Required: `child`. Optional: `opacity = 0.08` (clamped to `[0, 0.20]` on construction), `assetPath = 'assets/grain_overlay.png'`.
  - Build: `Stack(fit: passthrough, children: [child, Positioned.fill(child: IgnorePointer(child: Opacity(opacity: clamped, child: Image.asset(assetPath, fit: cover, repeat: ImageRepeat.repeat, errorBuilder: ... => SizedBox.shrink()))))])`.
  - **Никаких** `BlendMode` отличного от default `srcOver`. Только `Opacity`.
  - Doc-comment: «Apply ONLY to static layers (boot overlay, hero backdrop). NEVER on scrolling content.».
  - Наблюдаемое: при отсутствии asset — child рендерится без crash (errorBuilder возвращает SizedBox.shrink); при наличии — поверх child видим grain texture.
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_
  - _Depends: 1.1 (asset должен быть зарегистрирован), 2.1 (file scaffold)_
  - _Boundary: SafeFilmGrain_

- [x] 2.4 Создать `SafeBackdrop` widget
  - В `lib/core/perf/perf_safe_widgets.dart` добавить `class SafeBackdrop extends StatefulWidget` + private `_SafeBackdropState`.
  - Required: `imageProvider` (`ImageProvider?`), `fallbackBackground` (`Color`). Optional: `blurSigma = 40`, `semanticLabel`.
  - Состояние: `ui.Image? _blurredImage`, `Object? _activeKey`, `bool _renderInFlight = false`.
  - В `didChangeDependencies` и `didUpdateWidget` (когда `imageProvider` или `blurSigma` изменился): вызвать `_maybeRebuildBlur()`.
  - `_maybeRebuildBlur` (async): получить ImageStream, дождаться декодирования, нарисовать Image в offscreen `PictureRecorder` через `Canvas.saveLayer + Paint(imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma))`, конвертировать через `Picture.toImage()` в `ui.Image`. Сохранить в `_blurredImage`, `setState`. Использовать `_renderInFlight` re-entry guard.
  - Build: `RepaintBoundary(child: ColoredBox(color: fallbackBackground, child: _blurredImage == null ? SizedBox.expand() : RawImage(image: _blurredImage, fit: BoxFit.cover)))`.
  - **Никаких** `BackdropFilter`, никакого `ImageFilter.blur` в `build`. Pre-render only.
  - Наблюдаемое: при null `imageProvider` — рендер solid `fallbackBackground`. При смене `imageProvider` URL — `_blurredImage` пересчитывается один раз и кешируется. `flutter analyze` чисто.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_
  - _Depends: 2.1 (file scaffold)_
  - _Boundary: SafeBackdrop_

- [x] 2.5 Добавить `combinedHeroGradient(palette)` factory
  - В `lib/core/perf/perf_safe_widgets.dart` добавить top-level `RadialGradient combinedHeroGradient(AppPalette palette)`.
  - Геометрия согласно design.md § Components > combinedHeroGradient: `center: Alignment.bottomCenter`, `radius: 1.4`, 4 `stops: [0.0, 0.45, 0.85, 1.0]`, 4 `colors: [palette.background, palette.background.withValues(alpha: 0.85), palette.background.withValues(alpha: 0.40), palette.background.withValues(alpha: 0.0)]`.
  - Pure function — никакого state, никакого Riverpod.
  - Наблюдаемое: `combinedHeroGradient(noirCobalt.resolve())` возвращает `RadialGradient` с 4 stops + 4 colors; для двух разных палитр первый цвет различается.
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  - _Depends: 2.1 (file scaffold)_
  - _Boundary: combinedHeroGradient_

---

## 3. Theme integration: shadow audit

- [x] 3.1 Audit `MegaVTextStyles` для `Shadow.blurRadius > 12`
  - Открыть `megav_iptv/lib/core/theme/megav_text_styles.dart`.
  - Прогнать `grep -nE "blurRadius:\s*([2-9][0-9]+|1[3-9])" megav_iptv/lib/core/theme/megav_text_styles.dart` — должно быть **пусто** после правок.
  - Если в существующих display-styles есть Shadow с `blurRadius > 12` — заменить на `Shadow(blurRadius: 8, ...)` (Req 7.2 default).
  - Если в файле нет ни одного `Shadow` с blur — task деградирует до verify-only (commit пустой).
  - Наблюдаемое: grep пусто; `flutter test` 53/53 продолжает проходить.
  - _Requirements: 7.1, 7.2_
  - _Boundary: MegaVTextStyles_

---

## 4. Validation: widget tests + regression

- [x] 4.1 Создать widget tests для 4 safe widgets + helper
  - Создать `megav_iptv/test/core/perf/perf_safe_widgets_test.dart`.
  - Тесты согласно design.md § Testing Strategy:
    - T-1: source-introspection — файл `lib/core/perf/perf_safe_widgets.dart` не содержит `BackdropFilter`. Реализация: `final src = File('lib/core/perf/perf_safe_widgets.dart').readAsStringSync(); expect(src, isNot(contains('BackdropFilter')));`. `flutter test` запускается из `megav_iptv/`, путь относителен к этому корню.
    - T-2: `SafeBackdrop` с null `imageProvider` рендерит `fallbackBackground` solid fill (нет crash).
    - T-3: `SafePill` рендерит ровно один `Container` с заполненным `BoxDecoration.color` без `BackdropFilter` в parent chain.
    - T-4: `SafeFocusRing` toggle от false → true → false показывает / убирает ring (через `find.byType(BoxShadow)` count).
    - T-5: `SafeFocusRing` все BoxShadow имеют `blurRadius == 0`.
    - T-6: `SafeFilmGrain` использует только `BlendMode.srcOver` (через layer-tree introspection).
    - T-7: `SafeFilmGrain` opacity > 0.20 clamps to 0.20.
    - T-8: `combinedHeroGradient(palette)` возвращает `RadialGradient` с 4 stops; для NoirCobalt vs CrimsonReel первый stop-color различается.
    - T-9: `kSafeShadowBlurMax == 12.0`.
  - Запуск: `cd megav_iptv && flutter test test/core/perf/perf_safe_widgets_test.dart` — 9/9 зелёных.
  - Наблюдаемое: 9/9 тестов проходят, exit 0. `flutter test` total = 53 + 9 = 62.
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 1.5, 1.6, 2.2, 3.3, 3.7, 4.3, 5.1, 5.4, 7.3_
  - _Depends: 2.1, 2.2, 2.3, 2.4, 2.5, 1.1_
  - _Boundary: perf_safe_widgets_test_

- [x] 4.2 (P) Создать unit tests для `ComputedColors`
  - Создать `megav_iptv/test/core/theme/computed_colors_test.dart`.
  - Тесты:
    - T-10: `ComputedColors.from(noirCobalt.resolve())` returns instance с тремя non-null `Color` fields, three of them distinct.
    - T-11: `ComputedColors.from(noirCobalt.resolve()).textTintAccent != ComputedColors.from(crimsonReel.resolve()).textTintAccent` (палитра-зависимость).
    - T-12: вызов с одним и тем же palette дважды возвращает identical Color values (детерминированность).
  - Запуск: `cd megav_iptv && flutter test test/core/theme/computed_colors_test.dart` — 3/3 зелёных.
  - Наблюдаемое: 3/3 тестов; full suite = 65/65.
  - _Requirements: 6.1, 6.3, 6.4, 6.5, 11.6_
  - _Depends: 1.2_
  - _Boundary: computed_colors_test_

- [x] 4.3 Полный прогон тестов и regression check
  - `cd megav_iptv && flutter test` — ожидаемо 65/65 (53 baseline + 9 perf-widget + 3 ComputedColors).
  - `cd megav_iptv && flutter analyze` — 0 errors, 1 pre-existing baseline info acceptable.
  - `grep -rn "BackdropFilter\|ShaderMask" megav_iptv/lib/core/perf/` — пусто (Req 10.1).
  - `grep -rnE "blurRadius:\s*([2-9][0-9]+|1[3-9])" megav_iptv/lib/core/perf/ megav_iptv/lib/core/theme/` — пусто (Req 7.1, 10.1).
  - Наблюдаемое: 65/65 зелёных, exit code 0; analyze 0 errors; perf rules grep clean.
  - _Requirements: 9.2, 9.3, 10.1_
  - _Depends: 4.1, 4.2_
  - _Boundary: full project regression_

---

## 5. Steering doc augmentation

- [ ] 5.1 Дополнить `flutter-tv-perf.md` секцией «Design handoff conflicts → safe replacements»
  - Открыть `.kiro/steering/flutter-tv-perf.md`.
  - В конец (или перед Pre-PR checklist если есть) добавить section согласно design.md § Components > Steering doc augmentation: 7-row table (CSS source → Safe Flutter API → Cost) с ссылкой на issue #13.
  - Section должен ссылаться на конкретные имена API: `SafeFilmGrain`, `SafeBackdrop`, `SafePill`, `combinedHeroGradient`, `SafeFocusRing`, `ComputedColors`, `kSafeShadowBlurMax`.
  - Markdown lint check: `grep -c "SafeBackdrop\|SafePill\|SafeFocusRing\|SafeFilmGrain" .kiro/steering/flutter-tv-perf.md` — ≥ 4.
  - Наблюдаемое: section появляется в конце файла; все 7 conflicts помечены; downstream dev'ы могут найти таблицу без перехода в код.
  - _Requirements: 8.1, 8.2, 8.3, 8.4_
  - _Depends: 2.1, 2.2, 2.3, 2.4, 2.5, 1.2 (всё API уже существует чтобы ссылаться)_
  - _Boundary: steering doc_

---

## Implementation Notes

(пусто на момент генерации; импл-цикл может добавить cross-cutting findings)
