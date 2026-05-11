# Requirements Document

## Project Description (Input)

Спецификация описывает инфраструктурный pipeline визуального feedback loop для MegaV IPTV. Сейчас итерации UI-полишинга «слепые»: Claude пишет код → пользователь вручную запускает `flutter run` → описывает несоответствия словами; покрытие состояний теряется, сравнение с JSX-эталонами идёт «по памяти», `kiro-impl` reviewer-агент не видит визуального результата. Pipeline должен автоматизировать снятие скриншотов Flutter web-сборки и JSX-прототипов, сравнивать их попиксельно через pixelmatch, генерировать HTML-отчёт side-by-side, а также предоставить новый skill `kiro-validate-visual`, который возвращает GO/NO-GO/MANUAL для использования в `kiro-impl` или вручную. Pipeline создаётся как изолированная инфраструктура: НЕ модифицирует UI-код (`lib/features/**`), НЕ модифицирует существующие skills (`kiro-impl`, `kiro-validate-impl`), НЕ заменяет ручной TV smoke test. Цель — детерминированный визуальный gate против дрейфа от Cinematic + Noir Cobalt дизайна, а не имитация поведения реального Realtek TV-бокса.

## Boundary Context

- **В рамках спеки**:
  - Конфигурация Flutter web target в `megav_iptv/` (директория `web/`, CanvasKit renderer, фиксированный viewport).
  - Скрипты захвата JSX-эталонов и Flutter-снимков через headless Chromium (Playwright).
  - Pixel-сравнение и HTML-отчёт с настраиваемыми порогами.
  - Новый skill `kiro-validate-visual` в `.claude/skills/`.
  - Документация о применимости пайплайна (`.kiro/steering/visual-feedback.md`) с явной оговоркой «web ≠ TV».
  - Игнор временных артефактов в `.kiro/screenshots/.gitignore`.
- **Вне рамок спеки**:
  - Любые модификации UI-кода в `megav_iptv/lib/features/**`, `lib/core/**`, `lib/widgets/**`.
  - Модификации существующих skills (`kiro-impl`, `kiro-validate-impl`, прочих `kiro-*`).
  - GitHub Actions / CI-интеграция (отложено в будущий follow-up spec).
  - Snapshot iOS/Android native билдов (платформа сравнения — только web).
  - Видео-запись интеракций.
  - A/B-сравнение разных палитр.
  - Замена ручного TV-теста на референсном Realtek `rtd2851a` боксе.
- **Ожидания от соседних систем**:
  - Pipeline опирается на наличие JSX-прототипов в `.kiro/design/megav-iptv-handoff/project/screens/` (источник эталонов). При отсутствии прототипа для какого-либо экрана baseline для него не существует, и pipeline это явно сигнализирует.
  - Pipeline опирается на способность Flutter SDK собрать web-сборку проекта. Проверка реального исполнения на TV-боксе остаётся вне ответственности pipeline.
  - Downstream-спеки (`home-grid-stability-pass`, `hero-collapse-tile-morph`) могут опционально использовать `kiro-validate-visual` как валидатор, но pipeline не диктует им этого требования.

## Requirements

### Requirement 1: Конфигурация Flutter web target
**Objective:** Как разработчик MegaV, я хочу собирать актуальный web-бандл Flutter-приложения, чтобы pipeline мог рендерить и снимать те же UI-состояния, что и нативная сборка.

#### Acceptance Criteria
1. The Visual Feedback Pipeline shall обеспечивать наличие директории `megav_iptv/web/` с `index.html`, `manifest.json`, `flutter_bootstrap.js` и сопутствующими файлами, сгенерированными командой `flutter create --platforms=web`.
2. The Visual Feedback Pipeline shall конфигурировать web-сборку на использование CanvasKit-рендерера, чтобы визуальное соответствие шрифтам и градиентам совпадало с TV-сборкой.
3. When разработчик запускает скрипт сборки pipeline, the Visual Feedback Pipeline shall выполнять `flutter build web` и помещать собранный артефакт в `megav_iptv/build/web/`.
4. The Visual Feedback Pipeline shall обеспечивать локальный HTTP-сервер, отдающий собранный web-бандл по фиксированному localhost-порту для последующего headless-доступа.
5. If `flutter build web` завершается ошибкой, the Visual Feedback Pipeline shall возвращать ненулевой exit code и не пытаться запустить дальнейшие шаги снимков.

### Requirement 2: Захват JSX baseline-снимков
**Objective:** Как Claude в режиме `kiro-impl`, я хочу иметь набор детерминированных эталонных PNG для каждого экрана JSX-прототипа, чтобы сравнивать их с текущим состоянием Flutter-приложения.

#### Acceptance Criteria
1. The Visual Feedback Pipeline shall предоставлять команду `npm run snapshot:jsx`, которая запускает headless Chromium через Playwright и поочерёдно рендерит девять JSX-экранов из `.kiro/design/megav-iptv-handoff/project/screens/`.
2. The Visual Feedback Pipeline shall сохранять каждый baseline в `.kiro/screenshots/baselines/<screen>.png` с разрешением 1920×1080 и `deviceScaleFactor` равным 1.
3. While рендеринг JSX-эталона выполняется, the Visual Feedback Pipeline shall отключать анимации CSS и `prefers-reduced-motion`, обеспечивая byte-identical результат между запусками для одного и того же исходного JSX.
4. If JSX-прототип для экрана отсутствует в `.kiro/design/megav-iptv-handoff/project/screens/`, the Visual Feedback Pipeline shall пропускать этот экран и сообщать о пропуске в stdout-логе команды.
5. The Visual Feedback Pipeline shall фиксировать baseline-набор в git как набор PNG-файлов в `.kiro/screenshots/baselines/` без использования Git LFS.

### Requirement 3: Захват Flutter web снимков D-pad сценария
**Objective:** Как Claude, я хочу получать набор скриншотов Flutter-приложения для ключевых состояний фокуса и hero-режима, чтобы сравнивать визуал с JSX-эталоном.

#### Acceptance Criteria
1. The Visual Feedback Pipeline shall предоставлять команду захвата снимков Flutter-приложения, которая принимает имя экрана и снимает пять состояний: `idle`, `focused-first-tile`, `focused-third-row`, `hero-collapsed`, `hero-expanded`.
2. When команда захвата запускается, the Visual Feedback Pipeline shall открывать локальный web-бандл в headless Chromium, навигировать на маршрут указанного экрана и эмулировать D-pad нажатия, необходимые для достижения каждого из пяти состояний.
3. The Visual Feedback Pipeline shall сохранять снимки в `.kiro/screenshots/<timestamp>/<screen>-<state>.png` с разрешением 1920×1080 и `deviceScaleFactor` равным 1.
4. While Flutter-приложение рендерится в headless-сессии, the Visual Feedback Pipeline shall отключать анимации (через runtime-флаг или Chromium-аргумент), исключая дрожание из-за in-flight tween-анимаций.
5. If запрошенный экран недоступен в текущей сборке (404, route not found), the Visual Feedback Pipeline shall возвращать ненулевой exit code и сообщение, указывающее на отсутствующий маршрут.
6. The Visual Feedback Pipeline shall записывать структурированный manifest `.kiro/screenshots/<timestamp>/manifest.json` со списком успешно снятых пар `<screen, state>` и временами захвата.

### Requirement 4: Pixel-diff и HTML-отчёт
**Objective:** Как Claude или разработчик, я хочу видеть автоматическое попиксельное сравнение текущих снимков с эталоном и иметь визуальный артефакт, который можно открыть в браузере для ручной верификации.

#### Acceptance Criteria
1. The Visual Feedback Pipeline shall предоставлять команду diff-сравнения, которая для каждой пары `(baseline, current)` вычисляет процент изменённых пикселей через pixelmatch или эквивалентную утилиту.
2. The Visual Feedback Pipeline shall классифицировать результат каждой пары по конфигурируемым порогам: дельта строго меньше `pass_threshold` (по умолчанию 2%) — `PASS`; дельта строго больше `fail_threshold` (по умолчанию 5%) — `FAIL`; иначе — `WARNING`.
3. The Visual Feedback Pipeline shall читать пороги из `.kiro/screenshots/config.json`; if файл отсутствует, the Visual Feedback Pipeline shall использовать значения по умолчанию (2% / 5%) и логировать факт fallback.
4. The Visual Feedback Pipeline shall генерировать HTML-отчёт `.kiro/screenshots/<timestamp>/report.html`, в котором для каждой пары отображены baseline, current, diff mask и числовая дельта в процентах.
5. The Visual Feedback Pipeline shall возвращать агрегированный exit code: `0` если все пары `PASS`, `1` если хоть одна `FAIL`, `2` если есть `WARNING` без `FAIL`.
6. The Visual Feedback Pipeline shall помещать машиночитаемое summary в `.kiro/screenshots/<timestamp>/summary.json` со списком `(screen, state, delta_percent, verdict)`.

### Requirement 5: Skill `kiro-validate-visual`
**Objective:** Как Claude в `kiro-impl` или пользователь в интерактивном режиме, я хочу единую точку вызова, которая запускает весь pipeline и возвращает структурированный отчёт GO/NO-GO/MANUAL.

#### Acceptance Criteria
1. The kiro-validate-visual skill shall существовать как новый каталог `.claude/skills/kiro-validate-visual/` с файлом `SKILL.md`, оформленным по образцу `kiro-validate-impl` (frontmatter с `name`, `description`, `allowed-tools`, `argument-hint`).
2. When skill вызван с аргументом `<feature-name>`, the kiro-validate-visual skill shall запускать сборку web, снимок Flutter-состояний, снимок JSX-эталонов (при необходимости) и diff-сравнение в указанной последовательности.
3. The kiro-validate-visual skill shall возвращать структурированный отчёт с обязательными полями: `DECISION` (`GO` / `NO-GO` / `MANUAL_VERIFY_REQUIRED`), путь к HTML-отчёту, список пар с вердиктами, и причина решения.
4. If хоть одна пара `(screen, state)` помечена `FAIL`, the kiro-validate-visual skill shall возвращать `DECISION: NO-GO` и включать в отчёт remediation-указание со ссылкой на конкретные изменённые регионы (через дельту в процентах и путь к diff-маске).
5. If pipeline не может выполнить обязательный шаг из-за отсутствия web-бандла, baseline или Playwright-окружения, the kiro-validate-visual skill shall возвращать `DECISION: MANUAL_VERIFY_REQUIRED` с указанием конкретной отсутствующей предпосылки.
6. The kiro-validate-visual skill shall НЕ модифицировать существующие skills (`kiro-impl`, `kiro-validate-impl` и пр.); его вызов остаётся опциональным для downstream-спеков.

### Requirement 6: Детерминизм окружения захвата
**Objective:** Как Claude, я хочу, чтобы повторный запуск pipeline на неизменном коде давал byte-identical снимки, иначе diff-вердикты будут шумными и непригодными для GO-решений.

#### Acceptance Criteria
1. The Visual Feedback Pipeline shall фиксировать viewport на 1920×1080 как для JSX-, так и для Flutter-снимков; `deviceScaleFactor` всегда равен 1.
2. The Visual Feedback Pipeline shall использовать CanvasKit-рендерер Flutter web для всех Flutter-снимков, чтобы исключить расхождения с HTML/CanvasRenderer.
3. The Visual Feedback Pipeline shall отключать анимации (CSS, Flutter), `prefers-reduced-motion`, и эмулировать стабильный фонт-fallback при недоступности сетевого шрифта.
4. While snapshot выполняется, the Visual Feedback Pipeline shall дожидаться завершения известных async-инициализаций (загрузка шрифтов, первичный layout) до триггера PNG-записи.
5. If запуск pipeline на неизменном коде даёт дельту строго больше 0% для пары, ранее давшей 0%, the Visual Feedback Pipeline shall сообщать это как `WARNING` с пометкой «non-determinism detected» в summary.json.

### Requirement 7: Документация и оговорка «web ≠ TV»
**Objective:** Как читатель проектной документации, я хочу явно понимать, какие проверки pipeline предоставляет и какие НЕ предоставляет, чтобы не путать визуальный gate с реальной TV-валидацией.

#### Acceptance Criteria
1. The Visual Feedback Pipeline shall сопровождаться документацией `.kiro/steering/visual-feedback.md`, описывающей: цель pipeline, команды запуска, конфигурацию порогов, ограничения web vs Android TV (Impeller, GPU-rasterizer-cost), и явный список того, что pipeline НЕ проверяет.
2. The Visual Feedback Pipeline documentation shall явно фиксировать: pipeline проверяет визуальное соответствие layout/typography/colors относительно JSX-эталона и НЕ заменяет ручной smoke-тест на референсном Realtek `rtd2851a`.
3. The Visual Feedback Pipeline documentation shall описывать формат HTML-отчёта и summary.json, чтобы downstream-спеки могли парсить результат программно.
4. The Visual Feedback Pipeline documentation shall включать инструкцию по обновлению baseline (когда дизайн умышленно изменился и diff `FAIL` — ожидаемый).

### Requirement 8: Ограничения границ и изоляция от UI
**Objective:** Как владелец проекта, я хочу, чтобы pipeline жил исключительно в инфраструктурных директориях и не вмешивался в продакшен UI-код или в существующие kiro-skills.

#### Acceptance Criteria
1. The Visual Feedback Pipeline shall размещать все свои скрипты, зависимости и конфиги в `.kiro/scripts/visual-feedback/`, `.kiro/screenshots/`, `.kiro/steering/visual-feedback.md` и `.claude/skills/kiro-validate-visual/`.
2. The Visual Feedback Pipeline shall НЕ изменять файлы в `megav_iptv/lib/features/**`, `megav_iptv/lib/core/**`, `megav_iptv/test/**`.
3. The Visual Feedback Pipeline shall НЕ изменять существующие skills в `.claude/skills/kiro-impl/`, `.claude/skills/kiro-validate-impl/` и других директориях `kiro-*` (кроме создания нового каталога `kiro-validate-visual/`).
4. The Visual Feedback Pipeline shall разрешать модификации в `megav_iptv/pubspec.yaml` и `megav_iptv/web/` только в той части, которую генерирует `flutter create --platforms=web`; ручные правки UI-логики в этих файлах не допускаются.
5. The Visual Feedback Pipeline shall обеспечивать `.gitignore` в `.kiro/screenshots/`, который исключает временные директории `<timestamp>/` из коммита и оставляет в git только `baselines/`, `config.json`, `report-template.html` и сам `.gitignore`.
