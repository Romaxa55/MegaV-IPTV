# Brief: visual-feedback-pipeline

## Problem

Текущий цикл UI-полишинга — **слепой и медленный**:
- Я (Claude) пишу код, прошу пользователя запустить `flutter run`, сделать скриншот глазами,
  описать что не так словами.
- Пользователь не успевает кликать всё что нужно — теряется покрытие состояний
  (hero-expanded, hero-collapsed, focused, idle, settle).
- Сравнение с JSX-эталонами из `.kiro/design/megav-iptv-handoff/project/screens/` происходит
  «по памяти» — нет автоматического pixel diff.
- `/kiro-impl` в автономе **не имеет визуальных evidence** — reviewer-subagent не может
  посмотреть на результат, только на код.

User explicit ask: «может тебе собирать веб версию делать снимок и сомтерьб что не так
и чирез киро в аторежеми делать».

## Current State

- Flutter web target в проекте **не настроен** — `flutter create --platforms=web` ещё
  не запускался. `web/` директория отсутствует.
- В `pubspec.yaml` нет `flutter_web` плагинов или web-only dependencies.
- `.kiro/design/megav-iptv-handoff/project/screens/*.jsx` — 9 эталонных JSX прототипов
  (Cinematic Home, Editorial, Detail, Player, EPG, Search, Settings, etc.).
- `.kiro/design/megav-iptv-handoff/project/styles.css` — глобальный CSS с tokens.
- `.kiro/design/megav-iptv-handoff/` имеет также `node_modules` и `package.json` —
  JSX-прототипы можно рендерить через React.
- `kiro-impl` reviewer-subagent читает только `git diff`, нет визуального context.
- `kiro-validate-impl` финальный gate проверяет только тесты + integration, не визуал.

## Desired Outcome

**Полный (Full) pipeline**:

1. **Web build target**:
   - `flutter create --platforms=web` инициализация в `megav_iptv/`.
   - `flutter build web` собирает Cinematic Home + остальные экраны в releasable web bundle.
   - Конфигурация: CanvasKit (для font fidelity), фиксированный viewport 1920×1080.

2. **JSX prototype renderer**:
   - `package.json` для `.kiro/design/megav-iptv-handoff/` уже есть.
   - Скрипт `npm run snapshot:jsx` рендерит 9 эталонных JSX скринов в headless Chromium
     (Playwright), сохраняет PNG в `.kiro/screenshots/baselines/<screen>.png` фиксированного
     viewport.

3. **Flutter web snapshotter**:
   - Скрипт `bash scripts/snapshot-flutter.sh <screen>` запускает Flutter web build,
     поднимает локальный сервер (например, `python3 -m http.server` или `serve`),
     открывает в Playwright, навигирует в нужный route, проводит D-pad сценарий
     (5 ключевых состояний: idle, focused-first-tile, focused-third-row,
     hero-collapsed, hero-expanded), сохраняет PNG в
     `.kiro/screenshots/<timestamp>/<screen>-<state>.png`.

4. **Visual diff engine**:
   - `npm run diff` — pixelmatch (или odiff) сравнивает текущие снимки с baselines,
     генерирует HTML отчёт `.kiro/screenshots/<timestamp>/report.html` с
     side-by-side + diff mask + delta percentage.
   - Threshold: < 2% delta = PASS, > 5% = FAIL, между — WARNING.

5. **kiro integration**:
   - Новый skill `kiro-validate-visual` (отдельный, не модифицирует существующие).
   - Вызывается из `kiro-impl` или вручную через `/kiro-validate-visual <feature>`.
   - Запускает snapshot + diff, возвращает GO/NO-GO/MANUAL с путём к HTML отчёту.
   - При NO-GO — `kiro-impl` получает evidence «вот скриншот, вот diff, вот эталон»
     и может re-dispatch implementer с конкретным визуальным feedback.
   - Baseline screenshots коммитятся в git (small PNG, не LFS — 9 экранов × 5 состояний ≈ 50 файлов
     по ~100KB).

6. **CI hook (optional, follow-up)**:
   - GitHub Actions job на каждый PR прогоняет snapshot suite, прибивает diff отчёт
     как artifact. (Заглушка, реальная имплементация в отдельном спеке если потребуется.)

## Approach

**Layered Full pipeline, реализуем в 4 фазы внутри одного спека**:

- **Phase A — infrastructure**: `flutter create --platforms=web`, базовый build, локальный
  сервер. Verify через `flutter build web && serve build/web` + manual smoke.
- **Phase B — Playwright snapshot scripts**: 2 скрипта (JSX baseline + Flutter snapshot),
  оба используют один общий Playwright config.
- **Phase C — diff engine + HTML report**: pixelmatch + HTML template,
  baseline-vs-current side-by-side.
- **Phase D — kiro skill integration**: `kiro-validate-visual` skill в `.claude/skills/`,
  читает feature name → знает какие экраны проверить → запускает Playwright →
  возвращает структурированный отчёт. Не модифицирует существующие skills, чисто новый.

## Scope

- **In**:
  - Flutter web target setup в `megav_iptv/` (web/ дир + index.html + flutter_bootstrap.js).
  - Playwright + pixelmatch dependency в `.kiro/design/megav-iptv-handoff/package.json`
    или в новом `.kiro/scripts/visual-feedback/package.json`.
  - Shell скрипты `scripts/snapshot-flutter.sh`, `scripts/snapshot-jsx.sh`, `scripts/diff.sh`.
  - Baseline directory `.kiro/screenshots/baselines/` с initial PNG для 9 экранов.
  - HTML report template (`.kiro/screenshots/report-template.html`).
  - Новый skill `.claude/skills/kiro-validate-visual/SKILL.md` (по образцу
    `kiro-validate-impl`).
  - Документация в `.kiro/steering/` (новый файл `visual-feedback.md`).
- **Out**:
  - Модификация существующих skills (`kiro-impl`, `kiro-validate-impl`).
  - GitHub Actions CI integration (отложено в follow-up).
  - Native iOS/Android snapshot (не наша платформа сравнения).
  - Video recording интеракций (только статичные PNG).
  - A/B сравнение разных палитр (только current vs baseline).

## Boundary Candidates

- `megav_iptv/web/` — Flutter web target (новая директория).
- `megav_iptv/pubspec.yaml` — добавить `web` platform (через `flutter create`, не вручную).
- `.kiro/scripts/visual-feedback/` — Playwright + pixelmatch scripts (новая директория).
- `.kiro/screenshots/baselines/` — эталонные PNG (новая директория, коммитятся в git).
- `.kiro/screenshots/.gitignore` — игнор для transient `<timestamp>/` директорий.
- `.claude/skills/kiro-validate-visual/SKILL.md` — новый skill (новый файл).
- `.kiro/steering/visual-feedback.md` — документация (новый файл).

## Out of Boundary

- Любые модификации UI кода (`lib/features/**`) — только инфраструктура.
- Модификация существующих kiro skills.
- Существующие тесты (`test/**`) — не трогать.

## Upstream / Downstream

- **Upstream**:
  - Все существующие UI спеки (источники того, что снимаем).
  - `.kiro/design/megav-iptv-handoff/` (JSX-эталоны).
- **Downstream**:
  - `home-grid-stability-pass` и `hero-collapse-tile-morph` — первые потребители
    visual validation.
  - Любой будущий UI спек может опционально подключить `kiro-validate-visual`.

## Existing Spec Touchpoints

- **Extends**: ничего не открываем.
- **Adjacent**: все UI спеки (использует их output как input для снимков).

## Constraints

- **Web ≠ TV**: Flutter web рендерит через CanvasKit, а Android TV — через Impeller.
  Скриншоты web показывают **визуальное соответствие JSX** (layout, typography, colors),
  но **не показывают** реальное TV-поведение (focus rendering, D-pad responsiveness,
  performance под 512MB RAM). Эта оговорка — часть документации спека.
- **Viewport fixed**: 1920×1080, CanvasKit, `deviceScaleFactor: 1`. Никаких responsive
  тестов в этом пайплайне (адаптивность проверяется отдельно через `mobile-adaptive-layout`).
- **Determinism**: фиксированный seed для всех Playwright `wait`, фиксированный фонт
  fallback, отключён `prefers-reduced-motion`, выключены анимации через
  `--disable-animations` Chromium flag. Скриншоты должны быть byte-identical между
  запусками для одного и того же кода.
- **No CI initially**: всё локально, через npm scripts + Playwright. CI integration —
  отдельный follow-up.
- **Diff threshold tunable**: `< 2%` PASS, `> 5%` FAIL, `2–5%` WARNING — конфигурируется
  через `.kiro/screenshots/config.json`.
- **No GPL contamination**: pixelmatch (MIT), Playwright (Apache 2.0), serve (MIT) — всё OK.
- **Baseline storage**: PNG в git (не LFS) — 50 файлов × ~100KB = ~5MB acceptable.
