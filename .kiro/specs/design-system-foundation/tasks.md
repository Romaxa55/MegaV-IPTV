# Implementation Plan

> Спек: `design-system-foundation`. См. `requirements.md` (8 требований) и `design.md` (`AppPalette` + 6 палитр + `AppRadius` + `themeProvider` + `MegaVTextStyles`).
>
> Принципы: foundation infrastructure → integration с existing AppColors/AppTheme → tests. Все коммиты атомарные, существующие тесты не ломаем.

---

## 1. Foundation: data classes

- [x] 1.1 Создать `AppPalette` instance class
  - Создать `megav_iptv/lib/core/theme/app_palette.dart`.
  - Объявить `class AppPalette` с required `final Color` полями: `background`, `backgroundWarm`, `surface1`, `surface2`, `line`, `lineStrong`, `text`, `textDim`, `textMute`, `accent`, `accentGlow`, `accentSoft`, `gold`, `goldSoft`, `live`, `liveSoft`, `good`.
  - Добавить computed-properties для backward-compat: `primary => accent`, `error => live`, `textPrimary => text`, `textSecondary => textDim`, `textHint => textMute`, `cardBg => surface1`, `surface => surface2`, `chipBg => surface2`, `chipBorder => line`. Все остальные legacy-fields из текущего `app_colors.dart` мапятся аналогично.
  - `const` constructor.
  - Наблюдаемое: `flutter analyze lib/core/theme/app_palette.dart` чисто; класс не используется ещё нигде, warnings об unused class приемлемы.
  - _Requirements: 1.1, 1.2_
  - _Boundary: AppPalette_

- [ ] 1.2 (P) Создать `AppRadius` token class
  - Создать `megav_iptv/lib/core/theme/app_radius.dart`.
  - `abstract class AppRadius` с приватным constructor (utility class).
  - `static const double xs = 6, sm = 10, md = 14, lg = 20, xl = 28`.
  - `static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs))` и аналогично для остальных.
  - Наблюдаемое: `flutter analyze` чисто; конкретные значения проверяются в task 4.2 unit-тесте.
  - _Requirements: 3.1, 3.2, 3.3_
  - _Depends: none (independent of 1.1)_
  - _Boundary: AppRadius_

- [ ] 1.3 Создать `AppPaletteName` enum + 6 palette constants
  - Создать `megav_iptv/lib/core/theme/app_palettes.dart`.
  - `enum AppPaletteName { plum, ivory, noirCobalt, pitch, crimsonReel, modern }`.
  - Объявить 6 `const AppPalette` instances согласно `themes.css` из design bundle (`/Users/romaxa55/MegaV-IPTV/.kiro/design/megav-iptv-handoff/project/themes.css`):
    - `_noirCobalt` (default): `background: #06060A`, `text: #F4F1E9`, `accent: #6E56F7`, `live: #FF3B5C`, `gold: #E8B96A` и т.д. согласно design.md.
    - `_crimsonReel`: тёмно-красный нуар + охра.
    - `_plum`, `_ivory`, `_pitch`, `_modern` — извлечь из themes.css по соответствующим CSS-классам (`theme-plum`, etc.).
  - `extension AppPaletteResolver on AppPaletteName { AppPalette resolve() { switch (this) { ... } } }` — exhaustive switch.
  - Наблюдаемое: `AppPaletteName.values.length == 6`; для каждого `name.resolve()` возвращает non-null `AppPalette` (тест в 4.3).
  - _Requirements: 1.3, 5.3_
  - _Depends: 1.1_
  - _Boundary: AppPalettes_

---

## 2. Integration: provider + theme + extension

- [ ] 2.1 Реализовать `themeProvider` + `ThemeNotifier` + `PaletteStore` interface
  - Создать `megav_iptv/lib/core/theme/theme_provider.dart`.
  - `abstract class PaletteStore { Future<AppPaletteName?> read(); Future<void> write(AppPaletteName name); }` — interface only.
  - `class ThemeNotifier extends Notifier<AppPaletteName>` с `PaletteStore? _store`. `build()` возвращает `noirCobalt`, async-читает из `_store` если есть, обновляет state при success.
  - `Future<void> setPalette(AppPaletteName name)` → `state = name; await _store?.write(name);`.
  - `final themeProvider = NotifierProvider<ThemeNotifier, AppPaletteName>(() => ThemeNotifier());`.
  - `extension ThemeProviderResolve on AppPaletteName { AppPalette get palette => resolve(); }`.
  - Наблюдаемое: `flutter analyze` чисто; widget-тест в task 4.4 проверит switching.
  - _Requirements: 1.4, 1.5, 5.1, 5.2, 5.4, 6.1, 6.2, 6.3, 6.4_
  - _Depends: 1.1, 1.3_
  - _Boundary: ThemeNotifier_

- [ ] 2.2 Создать `MegaVTextStyles` ThemeExtension + font-cinema factory
  - Создать `megav_iptv/lib/core/theme/megav_text_styles.dart`.
  - `class MegaVTextStyles extends ThemeExtension<MegaVTextStyles>` с полями `displayItalic`, `displayLarge`, `bodyDefault`, `bodyDim`, `metaMono`. `const` constructor с required fields.
  - Реализовать `copyWith` и `lerp` (требуется ThemeExtension API; lerp может возвращать `this` без интерполяции — valid для discrete styles).
  - `factory MegaVTextStyles.cinema(AppPalette palette)` использует `GoogleFonts.cormorantGaramond(...)` для display, `GoogleFonts.golosText(...)` для body, `GoogleFonts.jetBrainsMono(...)` для metaMono. Размеры/weights согласно design.md (display 96px italic, body 14-16px, mono 10-12px uppercase letter-spacing 0.08em).
  - `extension MegaVThemeAccess on ThemeData { MegaVTextStyles get megavText => extension<MegaVTextStyles>()!; }`.
  - Наблюдаемое: импорт `google_fonts` работает; `MegaVTextStyles.cinema(AppPaletteName.noirCobalt.resolve())` возвращает non-null instance.
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_
  - _Depends: 1.1, 1.3_
  - _Boundary: MegaVTextStyles_

- [ ] 2.3 Refactor `app_colors.dart` в backward-compat proxy
  - Открыть `megav_iptv/lib/core/theme/app_colors.dart`.
  - Удалить все `static const Color` поля.
  - Заменить на static getters, читающие `_resolveActive()`:
    ```dart
    static Color get primary => _resolveActive().accent;
    static Color get background => _resolveActive().background;
    // ... etc.
    ```
  - `static AppPalette? _activePalette;` + `static void setActivePalette(AppPalette p) => _activePalette = p;`.
  - `static AppPalette _resolveActive() => _activePalette ?? AppPaletteName.noirCobalt.resolve();`.
  - **Сохранить ВСЮ публичную поверхность** — все ~30 fields из старого `AppColors`. Если какое-то имя не имеет точного соответствия в новых tokens — добавить computed alias через `AppPalette.computed properties` (task 1.1).
  - Наблюдаемое: `flutter analyze` чисто; `flutter test` 30/30 проходит — closed specs продолжают компилироваться без модификаций.
  - _Requirements: 2.1, 2.2, 2.3_
  - _Depends: 1.1, 1.3_
  - _Boundary: AppColors_

- [ ] 2.4 Refactor `app_theme.dart` использовать активную палитру + extension
  - Открыть `megav_iptv/lib/core/theme/app_theme.dart`.
  - `ThemeData appTheme(AppPalette palette)` — принимает палитру параметром.
  - Использовать `palette.background` для `scaffoldBackgroundColor`, `palette.accent` для `colorScheme.primary` и т.д.
  - Регистрировать `MegaVTextStyles.cinema(palette)` как ThemeExtension.
  - В `MaterialApp.builder` (или `MaterialApp(builder: ...)` в `app.dart`) дёргать `AppColors.setActivePalette(palette)` при каждом ребилде, чтобы static-getter `AppColors.X` всегда возвращал текущую палитру.
  - Backward-compat zero-arg version: `ThemeData appTheme() => appThemeWithPalette(AppPaletteName.noirCobalt.resolve());` — для legacy callers.
  - Наблюдаемое: `flutter analyze` чисто; `flutter test` 30/30; визуально приложение работает с Noir Cobalt по умолчанию (warm cream text вместо чисто-белого — единственное визуальное изменение, разрешённое Req 2.2).
  - _Requirements: 2.1, 2.2, 4.1, 4.2, 4.5, 4.6, 7.2_
  - _Depends: 1.1, 1.3, 2.1, 2.2, 2.3_
  - _Boundary: AppTheme_

---

## 3. App entry: подключить themeProvider к MaterialApp

- [ ] 3.1 Подключить `themeProvider` к `app.dart` / `main.dart`
  - Найти `MaterialApp` (в `app.dart` или `main.dart`).
  - Обернуть в `Consumer` или превратить parent в `ConsumerWidget`.
  - Прочитать `final paletteName = ref.watch(themeProvider);` → `final palette = paletteName.palette;` → передать в `theme: appTheme(palette)`.
  - В `MaterialApp.builder`: `AppColors.setActivePalette(palette);` перед `child!`.
  - Наблюдаемое: cold-start приложения показывает Noir Cobalt; смена палитры через `ref.read(themeProvider.notifier).setPalette(...)` отрабатывает live (проверяется в widget-тесте 4.4).
  - _Requirements: 1.4, 1.5, 5.1, 5.2_
  - _Depends: 2.1, 2.4_
  - _Boundary: App entry point_

---

## 4. Validation: тесты

- [ ] 4.1 (P) Unit-тест `AppPalette` token surface
  - Создать `megav_iptv/test/core/theme/app_palette_test.dart`.
  - Tests: const constructor работает; все поля non-null; backward-compat getters (`primary`, `error`, etc.) возвращают валидные `Color`.
  - Запуск: `flutter test test/core/theme/app_palette_test.dart`.
  - Наблюдаемое: 3+ зелёных тестов.
  - _Requirements: 1.1, 8.1_
  - _Depends: 1.1_
  - _Boundary: AppPalette_

- [ ] 4.2 (P) Unit-тест `AppRadius` exact values
  - Создать `megav_iptv/test/core/theme/app_radius_test.dart`.
  - Tests: `expect(AppRadius.xs, 6)`, ..., `expect(AppRadius.xl, 28)`. `expect(AppRadius.brSm.topLeft.x, 10)`.
  - Запуск: `flutter test test/core/theme/app_radius_test.dart`.
  - Наблюдаемое: 5+ зелёных тестов.
  - _Requirements: 3.1, 3.2, 3.3, 8.3_
  - _Depends: 1.2_
  - _Boundary: AppRadius_

- [ ] 4.3 Unit-тест 6 palettes complete + unique
  - Создать `megav_iptv/test/core/theme/app_palettes_test.dart`.
  - Test 1: `AppPaletteName.values.length == 6`.
  - Test 2: для каждого `name in AppPaletteName.values` — `name.resolve()` возвращает non-null `AppPalette` со всеми non-null tokens.
  - Test 3: `Set.from(AppPaletteName.values.map((n) => n.resolve())).length == 6` — каждая палитра уникальна по identity (или по `background` value если const-canonicalisation объединяет identical instances; в этом случае assert разные `background` values).
  - Test 4: `AppPaletteName.noirCobalt.resolve().background == Color(0xFF06060A)` — exact value check.
  - Test 5: `AppPaletteName.noirCobalt.resolve().text == Color(0xFFF4F1E9)` — warm cream text.
  - Запуск: `flutter test test/core/theme/app_palettes_test.dart`.
  - Наблюдаемое: 5/5 зелёных.
  - _Requirements: 1.3, 8.1, 8.2_
  - _Depends: 1.3_
  - _Boundary: AppPalettes_

- [ ] 4.4 Widget-тест `themeProvider` live switching
  - Создать `megav_iptv/test/core/theme/theme_provider_test.dart`.
  - Setup: `ProviderScope(child: Consumer(builder: (ctx, ref, _) { final palette = ref.watch(themeProvider).palette; return Container(color: palette.accent); }))`.
  - Test 1: pump → assert default `palette.accent == AppPaletteName.noirCobalt.resolve().accent`.
  - Test 2: вызвать `ref.read(themeProvider.notifier).setPalette(AppPaletteName.crimsonReel)` через `ProviderContainer`. Pump. Assert background виджета теперь `crimsonReel.accent`.
  - Test 3: assert `setPalette` без `PaletteStore` НЕ кидает ошибку (in-memory only).
  - Запуск: `flutter test test/core/theme/theme_provider_test.dart`.
  - Наблюдаемое: 3/3 зелёных.
  - _Requirements: 1.4, 5.1, 5.2, 6.2, 8.4_
  - _Depends: 2.1_
  - _Boundary: ThemeNotifier_

- [ ] 4.5 (P) Compat-тест: legacy `AppColors` aliases работают
  - Создать `megav_iptv/test/core/theme/app_colors_compat_test.dart`.
  - Tests: для каждого legacy-field (примерно ~25): `expect(AppColors.<field>, isA<Color>())`. Список fields брать из текущей head-версии `app_colors.dart` чтобы не пропустить ничего.
  - Запуск: `flutter test test/core/theme/app_colors_compat_test.dart`.
  - Наблюдаемое: 25+ зелёных тестов; ни один alias не возвращает null/throws.
  - _Requirements: 2.1, 2.2, 8.5_
  - _Depends: 2.3_
  - _Boundary: AppColors_

- [ ] 4.6 Полный прогон тестов и убедиться нет регрессий
  - `cd megav_iptv && flutter test test/`.
  - Ожидаемо: 30 (старые) + ~38 (новые из 4.1–4.5) = 68+ тестов.
  - Все зелёные, exit code 0.
  - `flutter analyze` чисто.
  - Наблюдаемое: `+68 -0` (или больше), exit code 0.
  - _Requirements: 2.3, 8.1, 8.2, 8.3, 8.4, 8.5_
  - _Depends: 4.1, 4.2, 4.3, 4.4, 4.5_
  - _Boundary: All test files_

---

## 5. Manual smoke (опционально, без TV)

- [ ] 5.1* Smoke build APK debug + установить на тестовое устройство (или эмулятор)
  - `cd megav_iptv && flutter build apk --debug` (или `flutter run -d <device>`).
  - Запустить приложение; визуально подтвердить:
    - Главный экран показывает все элементы как раньше (закрытые специй home-grid не сломались).
    - Текст имеет лёгкий warm cream tint вместо чисто белого (единственное разрешённое визуальное изменение).
    - Никаких overflow/null/crash.
  - Naблюдаемое: операторское «работает как раньше + текст теплее».
  - _Requirements: 2.2, 7.3_
  - _Depends: 4.6_
  - _Boundary: App smoke_

> Optional task — отмечен `*`. Может быть пропущен если automated tests пройдены и нет TV-доступа.
