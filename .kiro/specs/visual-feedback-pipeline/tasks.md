# Implementation Plan — visual-feedback-pipeline

> Spec: `.kiro/specs/visual-feedback-pipeline/`
> Boundary: pipeline инфраструктура. UI-код (`megav_iptv/lib/**`), существующие skills (`.claude/skills/kiro-*`) — read-only.
>
> **Phase 1 (JSX-only)** — задачи, требующие compile-able Flutter web,
> заблокированы Req 9 / upstream issue по `media_kit_engine.dart`. Реализуем
> JSX baseline + diff + skill в `MANUAL_VERIFY_REQUIRED` режиме для Flutter
> snapshot. После landing upstream fix — снимаем `_Blocked:_` маркеры.

## Tasks

- [ ] 1. Foundation: Flutter web target
- [x] 1.1 Инициализация Flutter web platform в `megav_iptv/`
  - Выполнить `flutter create --platforms=web .` в `megav_iptv/` (создаёт `web/` директорию)
  - Зафиксировать сгенерированные файлы `web/index.html`, `web/manifest.json`, `web/favicon.png`, `web/flutter_bootstrap.js`, `web/icons/*` в git
  - Сконфигурировать `web/index.html` на принудительное использование CanvasKit-рендерера (через `flutterConfiguration` в bootstrap либо через CLI-флаг сборки)
  - Observable completion: `ls megav_iptv/web/` показывает `index.html`, `manifest.json`, `favicon.png`, `flutter_bootstrap.js`, `icons/`; в `index.html` или `flutter_bootstrap.js` явно указан `canvaskit`
  - _Requirements: 1.1, 1.2, 6.2, 8.4_
  - _Boundary: FlutterWebTarget_

- [x] 1.2 Верификация целостности нативной сборки после Flutter web init
  - Запустить `flutter test` в `megav_iptv/` — все существующие тесты должны проходить
  - Запустить `flutter build apk --debug` (или `--profile`) — нативная сборка должна оставаться зелёной
  - Запустить `flutter build web --web-renderer canvaskit --release` — артефакт должен оказаться в `megav_iptv/build/web/`
  - Проверить `megav_iptv/.gitignore`: при необходимости убедиться, что `build/web/` исключён из коммита (паттерн `build/` обычно покрывает)
  - Observable completion: три команды (`flutter test`, `flutter build apk`, `flutter build web`) завершаются с exit 0; `megav_iptv/build/web/main.dart.js` и `flutter.js` существуют
  - _Requirements: 1.3, 8.4_
  - _Boundary: FlutterWebTarget_
  - _Depends: 1.1_

- [ ] 2. Foundation: Node.js dependency layer
- [x] 2.1 Скаффолд `.kiro/scripts/visual-feedback/` с `package.json`
  - Создать директорию `.kiro/scripts/visual-feedback/` со вложенными `bin/`, `lib/`, `scenarios/`, `jsx-renderer/`
  - Создать `package.json` с зависимостями: `playwright` (pin major ≥ 1.46), `pixelmatch` (≥ 6.0), `pngjs` (≥ 7), `serve` (≥ 14); engines: `"node": ">=20"`; type: `"module"` или `"commonjs"` (выбрать в зависимости от стиля скриптов)
  - Прописать npm scripts: `snapshot:jsx`, `snapshot:flutter`, `diff`, `run`, `baseline:update`
  - Зафиксировать `package-lock.json` после `npm install` (lockfile в git для воспроизводимости)
  - Создать `README.md` с quickstart: prerequisites (Node 20, Flutter SDK), `npm install`, `npx playwright install chromium`, `npm run …`
  - Observable completion: `cd .kiro/scripts/visual-feedback/ && npm install` завершается успешно; `node -e "require('playwright'); require('pixelmatch'); require('pngjs'); require('serve');"` exit 0
  - _Requirements: 8.1_
  - _Boundary: NodeDependencyLayer_

- [x] 2.2 Реализация `lib/playwright-config.js`
  - Экспортировать `createBrowserContext()` — возвращает `{ browser, context, page }` с viewport 1920×1080, `deviceScaleFactor: 1`, `headless: true`
  - Передавать Chromium args: `--force-prefers-reduced-motion`, `--disable-renderer-backgrounding`, `--disable-background-timer-throttling`
  - Экспортировать `closeBrowserContext({ browser })` для cleanup
  - Observable completion: `node -e "const c=require('./lib/playwright-config.js');c.createBrowserContext().then(async({browser,page})=>{await page.goto('about:blank');console.log(page.viewportSize());await c.closeBrowserContext({browser})})"` выводит `{ width: 1920, height: 1080 }`
  - _Requirements: 6.1, 6.3_
  - _Boundary: PlaywrightConfig_
  - _Depends: 2.1_

- [x] 2.3 (P) Реализация `lib/png-utils.js`
  - Функция `loadPng(path)` — возвращает декодированный pngjs PNG object
  - Функция `savePng(path, png)` — сохраняет PNG на диск
  - Функция `assertDimensions(png, width, height)` — бросает Error если размеры не совпадают
  - Observable completion: unit smoke `node -e "const u=require('./lib/png-utils.js'); const p=u.loadPng('test-fixture.png'); u.assertDimensions(p,1920,1080); console.log('ok')"` выводит `ok` для валидного fixture
  - _Requirements: 2.2, 3.3_
  - _Boundary: PngUtils_
  - _Depends: 2.1_

- [x] 2.4 (P) Реализация `lib/thresholds.js`
  - Функция `loadThresholds(configPath)` — читает `.kiro/screenshots/config.json` если есть, иначе возвращает defaults `{ pass: 2.0, fail: 5.0 }`
  - При fallback логировать в stderr факт использования defaults
  - Функция `classify(deltaPercent, thresholds)` — возвращает `'PASS' | 'WARNING' | 'FAIL'`
  - Observable completion: `node -e "const t=require('./lib/thresholds.js'); console.log(t.classify(1.0,{pass:2,fail:5}), t.classify(3.0,{pass:2,fail:5}), t.classify(7.0,{pass:2,fail:5}))"` выводит `PASS WARNING FAIL`
  - _Requirements: 4.2, 4.3_
  - _Boundary: Thresholds_
  - _Depends: 2.1_

- [ ] 3. Core: JSX baseline capture
- [x] 3.1 JSX-renderer bootstrap (`jsx-renderer/index.html` + `render-screen.js`)
  - `index.html` подключает React + ReactDOM (через unpkg или встроенный bundle), парсит query-param `?screen=<name>`, динамически импортирует `.kiro/design/megav-iptv-handoff/project/screens/<name>.jsx`
  - Подключает общий `.kiro/design/megav-iptv-handoff/project/styles.css` и `themes.css`
  - Размер canvas/body фиксируется 1920×1080 через CSS (`html, body { width: 1920px; height: 1080px; }`)
  - Observable completion: открыть `jsx-renderer/index.html?screen=home-cinematic` в браузере вручную — рендерится Cinematic Home без ошибок в console
  - _Requirements: 2.1, 6.1_
  - _Boundary: JSXRendererBootstrap_

- [x] 3.2 Реализация `bin/snapshot-jsx.js`
  - CLI с аргументами `--screen <name>` или `--all`
  - Для каждого screen из 9 (`cinematic-home`, `editorial-home`, `detail`, `player`, `epg`, `search`, `settings`, `mobile`) — открыть `jsx-renderer/index.html?screen=<name>` через Playwright, дождаться `document.fonts.ready`, выждать стабилизацию 500 мс, снять PNG
  - Записать в `.kiro/screenshots/baselines/<screen>.png`
  - Если JSX-файл для screen отсутствует — вывести warning в stdout, перейти к следующему
  - Валидировать размер каждого записанного PNG через `lib/png-utils.js` (1920×1080)
  - Observable completion: `node bin/snapshot-jsx.js --all` создаёт 9 PNG в `.kiro/screenshots/baselines/`; exit 0; ручная сверка одного из PNG визуально соответствует JSX
  - _Requirements: 2.1, 2.2, 2.3, 2.4_
  - _Boundary: SnapshotJSX_
  - _Depends: 2.2, 2.3, 3.1_

- [ ] 4. Core: Flutter snapshot capture
- [x] 4.1 D-pad scenarios JSON для всех экранов
  - Создать `scenarios/cinematic-home.json` с 5 состояниями: `idle`, `focused-first-tile`, `focused-third-row`, `hero-collapsed`, `hero-expanded` (каждое — последовательность key+delayMs)
  - Создать `scenarios/{detail,player,epg,search,settings,editorial-home,mobile}.json` с применимыми состояниями (для экранов без hero опускать соответствующие state)
  - Каждый JSON содержит поля `screen`, `route`, `states[]` с `name` и `actions[]`
  - Observable completion: `ls scenarios/*.json` показывает минимум 8 файлов; `node -e "JSON.parse(require('fs').readFileSync('scenarios/cinematic-home.json'))"` парсится без ошибок и содержит ≥ 5 states
  - _Requirements: 3.1_
  - _Boundary: Scenarios_

- [ ] 4.2 Реализация `bin/snapshot-flutter.js`
  - _Blocked: media_kit web compile (Req 9 / upstream player-cinematic-redesign). Pipeline должен в этом режиме возвращать MANUAL_VERIFY_REQUIRED. Снять блокер после landing upstream fix._
  - CLI: `--screen <name>` (обязательный), `--out-dir <ts>` (если нет — генерировать `YYYYMMDD-HHMMSS`), `--port 8765`
  - Прочитать `scenarios/<screen>.json`; если файла нет — exit 2
  - Открыть `http://localhost:<port>/#<route>` в Playwright (или `/<route>` зависит от Flutter routing config — проверить и выбрать корректную форму)
  - Если route даёт 404 / не рендерит Flutter app — exit 1 с stderr-сообщением
  - Дождаться готовности приложения (`page.waitForFunction(() => window.flutterFirstFrame === true)` или `waitForTimeout(2000)` как fallback)
  - Для каждого state: выполнить actions (keyboard.press + waitForTimeout), снять PNG в `<out-dir>/<screen>-<state>.png`
  - Записать `<out-dir>/manifest.json` со списком `{ screen, state, capturedAt, path }`
  - Валидировать размеры через `lib/png-utils.js`
  - Observable completion: с поднятым `serve` на 8765 — `node bin/snapshot-flutter.js --screen cinematic-home` создаёт 5 PNG + manifest.json в новой `<ts>/`; exit 0
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 6.4_
  - _Boundary: SnapshotFlutter_
  - _Depends: 2.2, 2.3, 4.1_

- [ ] 5. Core: Diff engine
- [x] 5.1 (P) Реализация `lib/report.js`
  - Функция `renderReport(summary, templatePath, outputPath)` — читает `.kiro/screenshots/report-template.html`, подставляет данные пар (baseline path, current path, diff path, delta, verdict) через простой `replace` или mustache-стиль templating
  - Создать `.kiro/screenshots/report-template.html` с HTML-структурой: header, таблица или сетка карточек с triple-image (baseline | current | diff), цветовая индикация verdict (PASS green, WARNING amber, FAIL red)
  - Observable completion: тест-вызов с фиксированным summary создаёт `report.html` валидный HTML (открывается в браузере без ошибок), отображаются 3 изображения для тестовой пары
  - _Requirements: 4.4_
  - _Boundary: ReportRenderer_
  - _Depends: 2.1_

- [x] 5.2 Реализация `bin/diff.js`
  - CLI: `--run-dir <ts>` (обязательный), `--baseline-dir <path>` (default `.kiro/screenshots/baselines/`)
  - Прочитать `<run-dir>/manifest.json`; для каждой пары `(screen, state)` — найти baseline `<baseline-dir>/<screen>.png` (state не учитывается в имени baseline для v1; baseline — это `idle`-эквивалент)
  - Если baseline отсутствует — пометить пару как `non_determinism: false, verdict: 'WARNING'` с reason `missing_baseline` и продолжить
  - Для каждой пары: `pixelmatch(baseline, current, diff, w, h, { threshold: 0.1 })` → count; deltaPercent = `count / (w*h) * 100`
  - Записать `<run-dir>/diff-<screen>-<state>.png` (только если есть baseline)
  - Записать `<run-dir>/summary.json` со схемой из design.md
  - Вызвать `lib/report.js.renderReport(...)` → `<run-dir>/report.html`
  - Вернуть exit code: 0 если все PASS, 1 если хоть один FAIL, 2 если есть WARNING без FAIL
  - Observable completion: на готовых snapshots — `node bin/diff.js --run-dir <ts>` создаёт `summary.json`, `report.html`, `diff-*.png`; exit code соответствует aggregate verdict
  - _Requirements: 4.1, 4.2, 4.5, 4.6_
  - _Boundary: DiffEngine_
  - _Depends: 2.3, 2.4, 5.1_

- [x] 5.3 Конфигурация `screenshots/config.json` и интеграция с DiffEngine
  - Создать `.kiro/screenshots/config.json` с `{ "pass_threshold": 2.0, "fail_threshold": 5.0 }` (commited в git)
  - Убедиться что `bin/diff.js` использует `lib/thresholds.js.loadThresholds()`, читающий этот файл
  - Если файл отсутствует — diff.js использует defaults и логирует это в stderr
  - Observable completion: `cat .kiro/screenshots/config.json` показывает пороги; удаление файла и повторный запуск diff.js выводит warning в stderr и использует defaults 2/5
  - _Requirements: 4.3_
  - _Boundary: Thresholds, DiffEngine_
  - _Depends: 2.4, 5.2_

- [x] 5.4 Non-determinism detection в DiffEngine
  - В `bin/diff.js`: если pair имеет `delta_percent > 0` и в предыдущем `summary.json` (находится в самом свежем sibling `<ts>/`-директории) та же пара имела `delta_percent == 0` — пометить `non_determinism: true` в текущем summary
  - Если предыдущий summary не найден — пропустить проверку (это первый запуск)
  - Observable completion: после двух последовательных одинаковых run-ов на неизменном коде, второй summary.json содержит только пары с `non_determinism: false`; если намеренно поменять content между run-ами и delta вырастет с 0 до >0 — `non_determinism: true` появляется в соответствующей паре
  - _Requirements: 6.5_
  - _Boundary: DiffEngine_
  - _Depends: 5.2_

- [ ] 6. Core: Orchestrator
- [x] 6.1 Реализация `bin/run-all.js`
  - _Blocked-partial: шаги 2-6 (flutter build web + Flutter snapshot) — Req 9. Phase 1: реализовать только JSX-only ветку и MANUAL_VERIFY_REQUIRED для Flutter. Полная реализация — после upstream fix._
  - CLI: `--screen <name>` (обязательный), `--skip-build`, `--baseline-only`
  - Шаг 1: проверить prerequisites (`flutter --version`, `node --version >= 20`); при ошибке — exit с понятным сообщением
  - Шаг 2 (если не `--skip-build`): `flutter build web --web-renderer canvaskit --release` в `megav_iptv/`; exit 1 при failure
  - Шаг 3: поднять `npx serve megav_iptv/build/web -p 8765` как detached child process; дождаться `localhost:8765` через ping
  - Шаг 4: сгенерировать `<ts>` директорию `.kiro/screenshots/<YYYYMMDD-HHMMSS>/`
  - Шаг 5: если baseline для screen отсутствует — вызвать `bin/snapshot-jsx.js --screen <name>`
  - Шаг 6 (если `--baseline-only` — пропустить остальное и завершить): вызвать `bin/snapshot-flutter.js --screen <name> --out-dir <ts>`
  - Шаг 7: вызвать `bin/diff.js --run-dir <ts>`
  - В `finally`: убить serve-child-process
  - Aggregate exit code: max из exit codes step 2, 5, 6, 7 (с приоритетом 1 > 2 > 0)
  - Observable completion: `node bin/run-all.js --screen cinematic-home` cold-run от чистого checkout завершается ≤ 3 минут, создаёт `<ts>/report.html` + `summary.json`; serve процесс не остался висеть после завершения
  - _Requirements: 1.3, 1.4, 1.5, 4.5_
  - _Boundary: RunAllOrchestrator_
  - _Depends: 1.2, 3.2, 4.2, 5.2_

- [ ] 7. Integration: kiro-validate-visual skill
- [x] 7.1 Создание `.claude/skills/kiro-validate-visual/SKILL.md`
  - Создать каталог `.claude/skills/kiro-validate-visual/`
  - Создать `SKILL.md` с frontmatter: `name: kiro-validate-visual`, `description: Validate UI feature visual fidelity against JSX baselines via Flutter web snapshot + pixelmatch diff.`, `allowed-tools: Read, Bash`, `argument-hint: <feature-name>`
  - Тело: execution steps по образцу `kiro-validate-impl/SKILL.md`:
    1. Detect target — `feature-name` из аргумента
    2. Gather context — `.kiro/specs/<feature>/spec.json` (language)
    3. Discover canonical command — `node .kiro/scripts/visual-feedback/bin/run-all.js --screen <feature-name>`
    4. Execute через Bash, capture stdout/stderr и exit code
    5. Прочитать `.kiro/screenshots/<latest-ts>/summary.json`
    6. Возврат структурированного markdown отчёта (DECISION, HTML_REPORT, PAIRS, AGGREGATE_VERDICT, REMEDIATION)
  - Documentation: явно отметить, что skill не модифицирует `kiro-impl` / `kiro-validate-impl` и опционален для downstream-спеков
  - Observable completion: `ls .claude/skills/kiro-validate-visual/` показывает `SKILL.md`; чтение SKILL.md показывает корректный frontmatter; `/kiro-validate-visual cinematic-home` (вручную из Claude) запускает pipeline и возвращает structured report
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_
  - _Boundary: ValidateVisualSkill_
  - _Depends: 6.1_

- [ ] 8. Integration: Steering doc + gitignore
- [x] 8.1 (P) Документация `.kiro/steering/visual-feedback.md`
  - Файл на русском с секциями: Overview, Quickstart (`npm install`, `npx playwright install chromium`, `npm run …`), Configuration (`config.json` пороги), Limitations (явная фраза «pipeline проверяет визуальное соответствие layout/typography/colors относительно JSX-эталона и НЕ заменяет ручной smoke-тест на референсном Realtek `rtd2851a`»), Report format (описание `summary.json` и `report.html`), Baseline regeneration (`node bin/snapshot-jsx.js --all` плюс commit обновлённых PNG)
  - Описать выбор v2 версий JSX-прототипов где они есть (`cinematic-v2.jsx`, `mobile-v2.jsx`, `epg-v2.jsx`, `search-v2.jsx`, `player-v2.jsx`, `settings-v2.jsx`)
  - Observable completion: файл существует, содержит все 6 секций, фраза «web ≠ TV» / эквивалент присутствует
  - _Requirements: 7.1, 7.2, 7.3, 7.4_
  - _Boundary: SteeringDoc_

- [x] 8.2 (P) `.kiro/screenshots/.gitignore`
  - Создать `.kiro/screenshots/.gitignore` с содержимым: игнорировать любые директории вида `<timestamp>/` (`[0-9]*`); явно НЕ игнорировать `baselines/`, `config.json`, `report-template.html`, сам `.gitignore`
  - Observable completion: `cat .kiro/screenshots/.gitignore` показывает корректные правила; `git status` после dummy `mkdir .kiro/screenshots/20260511-120000` не показывает эту директорию как untracked
  - _Requirements: 8.5_
  - _Boundary: FileStructurePlan_

- [ ] 9. Validation: golden run end-to-end
- [x] 9.1 Initial baseline capture
  - Запустить `node bin/snapshot-jsx.js --all` — получить 8-9 PNG в `.kiro/screenshots/baselines/`
  - Закоммитить baselines в git (не LFS)
  - Observable completion: `git log --stat` показывает добавленные PNG в `.kiro/screenshots/baselines/`; общий размер коммита ≤ 10 MB
  - _Requirements: 2.5_
  - _Boundary: SnapshotJSX_
  - _Depends: 3.2_

- [ ] 9.2 Golden run end-to-end (GR-1)
  - _Blocked: требует flutter build web. Phase 1: skip. Снять после upstream fix._
  - Запустить `node bin/run-all.js --screen cinematic-home` от чистого checkout
  - Проверить: `flutter build web` exit 0; `<ts>/cinematic-home-idle.png` существует с размером 1920×1080; `<ts>/summary.json` валиден и содержит `aggregate_verdict`; `<ts>/report.html` открывается в браузере без JS-ошибок
  - Observable completion: все 4 проверки пройдены; aggregate_verdict определён (PASS/WARNING/FAIL — любой из трёх в зависимости от текущего расхождения Flutter UI vs JSX baseline)
  - _Requirements: 1.3, 1.4, 3.3, 4.4, 4.6_
  - _Boundary: RunAllOrchestrator_
  - _Depends: 6.1, 9.1_

- [ ] 9.3 Determinism check (GR-2)
  - _Blocked: depends on 9.2 (flutter build web)._
  - Запустить `node bin/run-all.js --screen cinematic-home` дважды подряд на неизменном коде
  - Проверить: `summary.json` второго запуска показывает все пары с `delta_percent` совпадающей с первым запуском с допуском ±0.05%; `non_determinism: false` для всех пар
  - Если шум превышает 0.05% — задокументировать в `.kiro/steering/visual-feedback.md` как известное ограничение (например, font cache cold start)
  - Observable completion: два sibling `<ts>/summary.json` имеют идентичные verdicts; non_determinism flag нигде не true
  - _Requirements: 6.5_
  - _Boundary: DiffEngine_
  - _Depends: 9.2_

- [ ] 9.4 Skill integration test (GR-5)
  - _Blocked-partial: full GR-5 требует Flutter snapshot. Phase 1: тестируем только JSX-only ветку и MANUAL_VERIFY_REQUIRED handling._
  - Из текущего Claude-сессии или через `/kiro-validate-visual cinematic-home` запустить skill
  - Проверить: skill возвращает структурированный markdown с DECISION, HTML_REPORT-path, PAIRS, AGGREGATE_VERDICT
  - При aggregate FAIL — skill возвращает DECISION: NO-GO + REMEDIATION (Req 5.4)
  - При отсутствии Playwright browsers — skill возвращает DECISION: MANUAL_VERIFY_REQUIRED (Req 5.5)
  - Observable completion: skill output содержит все обязательные поля; при artificial FAIL (намеренное искажение JSX) — выход NO-GO; при удалении `node_modules/playwright` — выход MANUAL_VERIFY_REQUIRED с указанием отсутствующей зависимости
  - _Requirements: 5.3, 5.4, 5.5_
  - _Boundary: ValidateVisualSkill_
  - _Depends: 7.1, 9.2_

- [x] 9.5 Boundary verification (BT-1, BT-2)
  - После выполнения 1.1-9.4: `git status megav_iptv/lib/ megav_iptv/test/ .claude/skills/kiro-impl/ .claude/skills/kiro-validate-impl/` показывает чистое состояние (нет diff)
  - `git status megav_iptv/` показывает только: `web/` (autogenerated), `pubspec.yaml` (web platform), `.gitignore` (если потребовался update)
  - Observable completion: команды `git status` подтверждают, что pipeline не нарушил границы; `git diff megav_iptv/lib/` пуст
  - _Requirements: 8.2, 8.3_
  - _Boundary: BoundaryEnforcement_
  - _Depends: 9.2_

## Implementation Notes

- Все задачи в Wave 4a roadmap'а; pipeline можно использовать как валидатор для `home-grid-stability-pass` и `hero-collapse-tile-morph` после готовности.
- (P) marker применён к `2.3`, `2.4`, `5.1`, `8.1`, `8.2` — независимы от других задач в их волне.
- Critical path: `1.1 → 1.2 → 2.1 → 2.2 → 3.1 → 3.2 → 4.1 → 4.2 → 5.2 → 6.1 → 7.1 → 9.2 → 9.4`.
- Foundation phase (1.x, 2.x) — обязательно последовательно по логике зависимостей.
- Core phase (3.x, 4.x, 5.x) — частичная параллельность через (P), но три bin-скрипта (`snapshot-jsx`, `snapshot-flutter`, `diff`) общаются через FS-контракты (PNG + JSON), без shared mutable state.
- Validation phase (9.x) — последовательно, требует завершения всех Core + Integration.
- Baseline coммит (9.1) делается ДО golden run (9.2), иначе diff не имеет с чем сравнивать.
