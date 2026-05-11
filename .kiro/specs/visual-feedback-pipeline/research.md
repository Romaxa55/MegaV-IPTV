# Research & Design Decisions — visual-feedback-pipeline

## Summary
- **Feature**: `visual-feedback-pipeline`
- **Discovery Scope**: New Feature (greenfield infrastructure) с light-touch интеграцией в существующий kiro tooling
- **Key Findings**:
  - Все необходимые зависимости (Playwright Apache 2.0, pixelmatch MIT, serve MIT) совместимы между собой и не конфликтуют по лицензиям проекта.
  - Flutter web target в `megav_iptv/` отсутствует — потребуется `flutter create --platforms=web`, что добавляет директорию `web/` и обновляет `pubspec.yaml` (web-секция assets).
  - В `.kiro/design/megav-iptv-handoff/` нет `package.json` и `node_modules` — это просто HTML+JSX без bundler-конфигурации. Соответственно, pipeline-зависимости лучше держать в собственной директории `.kiro/scripts/visual-feedback/`, чтобы не привязывать handoff к node-runtime.

## Research Log

### Playwright vs Puppeteer vs Cypress для headless-снимков

- **Context**: Нужен headless-браузер с D-pad keyboard emulation, фиксированным viewport и стабильным API. Pipeline инициируется из Node-скрипта, а не из тестового раннера.
- **Sources Consulted**: Playwright docs (playwright.dev), Puppeteer docs (pptr.dev), Cypress docs.
- **Findings**:
  - Playwright: явный `chromium.launch({ args: [...] })`, `page.keyboard.press('ArrowRight')`, нативная поддержка `deviceScaleFactor` через `browser.newContext`, отличный `page.screenshot({ fullPage: false })`. Apache 2.0.
  - Puppeteer: схожий API, но `BrowserContext.viewport` чуть менее гибкий; экосистема медленнее обновляется. Apache 2.0.
  - Cypress: предполагает test-runner с UI; неудобен для batch-снимков и CLI-интеграции в kiro-skill.
- **Implications**: Выбран Playwright. Один `browser.newContext({ viewport: {width:1920,height:1080}, deviceScaleFactor:1 })` покрывает оба сценария (JSX и Flutter).

### pixelmatch vs odiff vs resemble.js для diff

- **Context**: Нужен надёжный pixel-by-pixel diff с возможностью генерировать diff-маску для HTML-отчёта. Желательно: чистый Node.js, MIT-совместимая лицензия, маленький bundle.
- **Sources Consulted**: pixelmatch (github.com/mapbox/pixelmatch), odiff (github.com/dmtrKovalenko/odiff), resemble.js (github.com/rsmbl/Resemble.js).
- **Findings**:
  - pixelmatch: чистый Node, MIT, использует `pngjs` для I/O, возвращает count изменённых пикселей и пишет diff PNG. Threshold per-pixel `0.1` по умолчанию.
  - odiff: написан на OCaml, требует native бинарь, быстрее на больших картинках, но усложняет packaging для kiro-pipeline.
  - resemble.js: больше API для perceptual diff (цветовые spaces), но завязан на canvas/jsdom; усложняет stack.
- **Implications**: Выбран pixelmatch — простой, чистый Node, MIT. Достаточен для 1920×1080 диффа за <500 ms.

### Где разместить node_modules

- **Context**: Бриф упоминает «`package.json` для `.kiro/design/megav-iptv-handoff/` уже есть». Проверка показала, что это неверно: в handoff-директории нет `package.json` и нет `node_modules`. Это просто статичный JSX/HTML.
- **Sources Consulted**: `ls /Users/romaxa55/MegaV-IPTV/.kiro/design/megav-iptv-handoff/`.
- **Findings**: Директория содержит `chats/`, `project/` (с JSX-экранами и стилями), `README.md`. Нет `package.json`, `node_modules`, `package-lock.json`.
- **Implications**: Создаём отдельный `package.json` в `.kiro/scripts/visual-feedback/`. Это:
  - Изолирует dependencies (Playwright + pixelmatch + serve + pngjs) от design-handoff bundle.
  - Позволяет одной командой `npm install` поднять весь pipeline.
  - Упрощает rollback и обновление зависимостей.
  - Не требует трогать `.kiro/design/megav-iptv-handoff/` (он остаётся read-only артефактом дизайн-handoff'а).

### Flutter web — что добавляет `flutter create --platforms=web`

- **Context**: В `megav_iptv/` отсутствует директория `web/`. Нужно понять минимальные изменения, которые `flutter create --platforms=web .` внесёт.
- **Sources Consulted**: Flutter docs (docs.flutter.dev/platform-integration/web), `flutter create --help`.
- **Findings**:
  - Создаётся директория `web/` с файлами `index.html`, `manifest.json`, `favicon.png`, `flutter_bootstrap.js`, иконками в `web/icons/`.
  - В `pubspec.yaml` Flutter может добавить `flutter:` web-секцию (обычно не требуется явных правок, web просто становится доступной платформой).
  - Никакие изменения в `lib/` не вносятся.
- **Implications**: Изменения в `pubspec.yaml` минимальные и автогенерируемые. Pipeline их не редактирует вручную — только запускает `flutter create`.

### CanvasKit vs HTML renderer для Flutter web

- **Context**: Нужен renderer, дающий максимальное визуальное соответствие Android TV (где UI рисуется через Impeller/Skia). HTML-renderer использует DOM+SVG и часто иначе рисует градиенты, шрифты, кривые.
- **Sources Consulted**: Flutter web rendering docs.
- **Findings**:
  - CanvasKit: использует Skia скомпилированный в WASM, идентичный pipeline рендеринга как на нативной платформе. Стоимость — ~2 MB WASM bundle и чуть худшая производительность в idle. Но для статичного скриншота — оптимален.
  - HTML renderer: легче, быстрее, но шрифты/градиенты будут отличаться от нативного.
- **Implications**: Используем CanvasKit (`--web-renderer canvaskit`). Это часть детерминизма (Req 6.2).

### D-pad эмуляция в Flutter web через Playwright

- **Context**: Нужно эмулировать ArrowRight/Down/Up/Left/Enter для достижения состояний `focused-first-tile`, `focused-third-row` и пр.
- **Sources Consulted**: Playwright keyboard API, Flutter web focus traversal docs.
- **Findings**: `page.keyboard.press('ArrowRight')` посылает реальный KeyboardEvent, который Flutter web обрабатывает через FocusManager так же, как нажатие D-pad на TV-боксе. Между нажатиями полезен `waitForTimeout(150ms)` (≈ Leanback card-focus duration), чтобы дать анимации завершиться.
- **Implications**: D-pad сценарии — это просто массив `{ key: 'ArrowRight', delayMs: 150 }`. Описание сценариев живёт в `.kiro/scripts/visual-feedback/scenarios/<screen>.json`. Изменения сценариев не требуют модификации Flutter-кода.

### Отключение анимаций в Flutter web без модификации UI-кода

- **Context**: Anti-flake требование. Бриф говорит «выключены анимации через `--disable-animations` Chromium flag», но этот флаг работает только для CSS-анимаций браузера. Flutter web использует свой animation loop (`SchedulerBinding`), который этим флагом не отключается.
- **Sources Consulted**: Flutter SchedulerBinding docs, Chromium command-line switches.
- **Findings**:
  - Глобальный `timeDilation = 0` потребовал бы правку UI-кода (out of boundary).
  - Альтернатива: ожидать естественного завершения анимаций (waitForTimeout + waitForLoadState). Leanback-таймин 150ms focus + 250ms scroll → suffice 500ms padding.
  - Дополнительно: Chromium-аргумент `--disable-renderer-backgrounding` и `--force-prefers-reduced-motion` стабилизируют GIF/CSS-анимации в JSX-snapshot.
- **Implications**: Pipeline принимает «wait strategy» (детерминированная пауза 500ms после ввода) как способ дождаться settle-state, без модификации Flutter UI-кода. Это согласовано с Req 6.3, 6.4.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Monolithic Node script | Один большой `pipeline.js` делает всё | Простой запуск | Сложен в тестировании, плохая повторная использование | Отклонено |
| Layered scripts + shared lib | Отдельные `snapshot-jsx.js`, `snapshot-flutter.js`, `diff.js`, разделяемый `lib/playwright-config.js` и `lib/png-utils.js` | Каждый шаг тестируется отдельно, чёткие границы | Чуть больше boilerplate | **Выбрано** |
| Test-runner-based (Jest/Vitest) | Завернуть в test framework | Готовая отчётность | Лишний слой, runner ≠ цель pipeline | Отклонено |
| Plugin architecture | Renderer-plugin abstraction | Гибкость для будущих рендереров | Speculative abstraction, нарушает synthesis-принцип | Отклонено |

## Design Decisions

### Decision: Отдельный `package.json` в `.kiro/scripts/visual-feedback/`
- **Context**: Бриф предполагал переиспользование `package.json` из handoff-директории, но такого файла там нет.
- **Alternatives Considered**:
  1. Создать `package.json` внутри `.kiro/design/megav-iptv-handoff/` — связывает дизайн-артефакт с node-runtime.
  2. Создать отдельный `package.json` в `.kiro/scripts/visual-feedback/` — изолирует pipeline-deps.
- **Selected Approach**: Отдельный `package.json` в `.kiro/scripts/visual-feedback/`.
- **Rationale**: Чистая граница между «design handoff bundle» (read-only артефакт) и «visual feedback infrastructure» (активный tooling).
- **Trade-offs**: Чуть больше дублирования если когда-нибудь handoff тоже захочет node-tooling; пока не нужен.
- **Follow-up**: `npm install` в этой директории — единая точка инициализации pipeline.

### Decision: pixelmatch вместо odiff
- **Context**: Diff-engine выбор.
- **Alternatives Considered**:
  1. pixelmatch — Node, MIT, чистый JS.
  2. odiff — OCaml binary, быстрее, но native dependency.
- **Selected Approach**: pixelmatch.
- **Rationale**: Простота packaging, нет native-зависимостей, MIT-лицензия совместима со всем стеком.
- **Trade-offs**: Чуть медленнее на больших картинках. Для 1920×1080 — приемлемо (~300-500 ms на пару).
- **Follow-up**: При scaling (если экранов станет 50+) рассмотреть odiff в follow-up спеке.

### Decision: CanvasKit renderer для Flutter web
- **Context**: Visual fidelity к Android TV.
- **Alternatives Considered**:
  1. CanvasKit (Skia WASM).
  2. HTML renderer.
- **Selected Approach**: CanvasKit, явно указанный через `--web-renderer canvaskit` (или конфиг `flutter_bootstrap.js`).
- **Rationale**: Идентичный pipeline рендеринга (Skia) как у нативной TV-сборки. HTML-renderer заметно расходится в градиентах и шрифтах.
- **Trade-offs**: Bigger bundle (~2 MB WASM), медленнее cold start; для статичных снимков несущественно.
- **Follow-up**: Документировать в `visual-feedback.md` (Req 7).

### Decision: Layered scripts с общей библиотекой
- **Context**: Структура pipeline-кода.
- **Selected Approach**:
  - `bin/snapshot-jsx.js`, `bin/snapshot-flutter.js`, `bin/diff.js`, `bin/run-all.js` — точки входа.
  - `lib/playwright-config.js` — общий browser context (viewport, deviceScaleFactor, флаги).
  - `lib/png-utils.js` — load/save PNG через pngjs.
  - `lib/report.js` — рендер `report.html` из шаблона.
- **Rationale**: Каждый файл одна ответственность; следует synthesis-принципу simplification.
- **Trade-offs**: Минимальный — мало кода в каждом файле, легко читать.
- **Follow-up**: Если ктo-то добавит новый renderer (например, для Android native), он расширяет шаблон без переписывания existing.

### Decision: D-pad сценарии как декларативный JSON
- **Context**: Захват пяти состояний (`idle`, `focused-first-tile`, `focused-third-row`, `hero-collapsed`, `hero-expanded`).
- **Alternatives Considered**:
  1. Жёстко закодированный массив в `snapshot-flutter.js`.
  2. Декларативный JSON `scenarios/<screen>.json` со списком key-events.
- **Selected Approach**: JSON-сценарии.
- **Rationale**: Изменение сценариев не требует правок JS-кода; легко расширять; читаемо для review.
- **Trade-offs**: Нужен JSON parser (но это `JSON.parse`).
- **Follow-up**: Стартовый набор для `cinematic-home` экрана — обязательный (5 состояний); для остальных 8 экранов сценарии добавляются downstream.

### Decision: Threshold defaults 2% / 5%
- **Context**: Бриф указывает PASS < 2%, FAIL > 5%, WARNING между.
- **Selected Approach**: Hard-coded defaults в `diff.js` + override через `config.json`.
- **Rationale**: Сохраняем тестируемость; пороги конфигурируются без правки кода.
- **Trade-offs**: Если default окажутся неподходящими — нужно править defaults в коде. Приемлемо для v1.
- **Follow-up**: После прогона на нескольких реальных diff-ах — откалибровать.

## Risks & Mitigations

- **Risk 1**: Non-determinism шрифтов (`google_fonts` сетевая загрузка) → дельты вне нуля на неизменном коде.
  **Mitigation**: В Playwright config — `page.evaluate` для проверки `document.fonts.ready`; в Flutter — wait until `flutter` first-frame через polling `flutter-status` глобального флага если доступен, иначе `waitForTimeout(2000ms)`. Зафиксировано в Req 6.4 + Req 6.5 (warning при обнаружении).

- **Risk 2**: Различие cinematic Flutter UI и JSX-прототипа на уровне реальной верстки → постоянные `WARNING` без `FAIL`.
  **Mitigation**: Документировать в `visual-feedback.md`, что цель — обнаружить дрейф, а не достичь 0% дельты; baselines обновляются осознанно (Req 7.4).

- **Risk 3**: D-pad сценарий «hero-expanded» зависит от наличия hero на конкретном экране → ошибки на экранах без hero.
  **Mitigation**: Сценарии per-screen; если состояние неприменимо, опускаем его в JSON. Pipeline пропускает отсутствующие пары без ошибки (Req 2.4-стиль).

- **Risk 4**: `flutter create --platforms=web` мог поменять что-то ещё (CI workflows, dependencies); риск регрессии для нативных билдов.
  **Mitigation**: Запуск pilot’а pipeline с verification — `flutter test` и `flutter build apk` должны проходить как до создания web. Часть verification — task 1.2.

- **Risk 5**: 50 baseline PNG × ~100 KB = 5 MB в репо; репо тяжелеет.
  **Mitigation**: Baselines только для 9 экранов в одном `idle`-состоянии (= 9 файлов). D-pad состояния не имеют baseline — diff только current-vs-current через manifest. Уточнено в Req 2.

- **Risk 6**: При запуске на CI/чужой машине Playwright тащит ~300 MB браузеров.
  **Mitigation**: Out-of-boundary для текущего спека (CI integration в follow-up). Документируем в README pipeline.

## References

- [Playwright API](https://playwright.dev/docs/api/class-playwright) — Apache 2.0
- [pixelmatch](https://github.com/mapbox/pixelmatch) — MIT
- [serve](https://github.com/vercel/serve) — MIT
- [pngjs](https://github.com/lukeapage/pngjs) — MIT
- [Flutter web docs](https://docs.flutter.dev/platform-integration/web)
- [`.kiro/steering/flutter-tv-perf.md`](../../steering/flutter-tv-perf.md) — почему CanvasKit и почему web ≠ TV
- [`.kiro/specs/visual-feedback-pipeline/brief.md`](./brief.md) — исходный бриф
