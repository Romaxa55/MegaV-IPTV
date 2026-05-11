# Visual feedback pipeline — steering

Спецификация: `.kiro/specs/visual-feedback-pipeline/`
Skill-точка вызова: `kiro-validate-visual`
Корень инфраструктуры: `.kiro/scripts/visual-feedback/`
Артефакты: `.kiro/screenshots/`
GitHub issue (Phase 2 blocker): https://github.com/Romaxa55/MegaV-IPTV/issues/16

## Overview

Pipeline автоматизирует визуальную регрессию против JSX-эталонов из
`.kiro/design/megav-iptv-handoff/project/screens/`. Заменяет ручной
цикл «Claude пишет код → пользователь делает скриншот → описывает
расхождения словами»: теперь diff делается попиксельно через
`pixelmatch`, отчёт открывается одним HTML.

Pipeline — это **визуальный gate**, не replacement реального
TV-тестирования. См. секцию «Limitations» ниже.

## Quickstart

```sh
cd .kiro/scripts/visual-feedback/
npm install
npx playwright install chromium

# Полный цикл для одного экрана (Phase 1: closes with MANUAL_VERIFY_REQUIRED):
node bin/run-all.js --screen cinematic-home

# Только обновить baseline (когда JSX-прототип реально изменился):
node bin/run-all.js --screen cinematic-home --baseline-only

# Только diff на готовом run-dir:
node bin/diff.js --run-dir .kiro/screenshots/20260511-061234
```

Скрипты также доступны как npm scripts:
`npm run snapshot:jsx`, `npm run diff`, `npm run run`,
`npm run baseline:update` (см. `package.json`).

## Phase 1: JSX-only operation (CURRENT)

До тех пор пока **GitHub #16** (media_kit web compile) не починен,
pipeline работает в режиме «JSX-only»:

- `bin/snapshot-jsx.js` снимает 8 JSX-эталонов в
  `.kiro/screenshots/baselines/*.png` — **работает полностью**.
- `bin/diff.js` сравнивает любые два набора PNG, генерирует
  `summary.json` и `report.html` — **работает полностью**.
- `bin/snapshot-flutter.js` (snapshot реального Flutter web) —
  **заблокирован**: `flutter build web` падает на
  `lib/core/player/media_kit_engine.dart:82` (`NativePlayer.setProperty`
  не определён на web stub пакета `media_kit 1.2.6`).
- `bin/run-all.js` в Phase 1 возвращает `MANUAL_VERIFY_REQUIRED` и
  записывает stub `summary.json` со ссылкой на issue #16.

**Что Phase 1 ВСЁ ЖЕ даёт пользы**:
- Регулярная регенерация baselines при правках JSX-прототипов
  (`--baseline-only`).
- Диффовать baselines между ветками / коммитами вручную.
- Готовые `bin/diff.js`, `lib/report.js`, `kiro-validate-visual` —
  как только #16 закроется, Flutter snapshot подключается без правок.

## Phase 2: Flutter snapshot (POST-#16)

После landing upstream-фикса:

1. `flutter build web --release` начинает успешно собирать
   `megav_iptv/build/web/`.
2. Снимается `_Blocked:_` маркер с tasks 4.2, 6.1 (partial), 9.2-9.4
   в `.kiro/specs/visual-feedback-pipeline/tasks.md`.
3. `bin/run-all.js` дописывается секцией «phase-2 path»: spawn
   `npx serve` → wait HTTP → Playwright open
   `http://localhost:<port>/#/<route>` → execute D-pad scenario JSON
   → snapshot 5 состояний → diff against baseline.
4. `bin/run-all.js` начинает возвращать настоящий GO/NO-GO вместо
   MANUAL_VERIFY_REQUIRED.

## Configuration

`.kiro/screenshots/config.json`:

```json
{
  "pass_threshold": 2.0,
  "fail_threshold": 5.0
}
```

- `delta_percent < pass_threshold` → `PASS`
- `delta_percent > fail_threshold` → `FAIL`
- между ними → `WARNING`

Если файл удалён — `lib/thresholds.js` использует defaults и пишет
warning в stderr. Безопасно.

## Report format

### `summary.json` (schema: `vfp-summary-v1`)

```json
{
  "schema": "vfp-summary-v1",
  "generated_at": "2026-05-11T07:30:00Z",
  "run_dir": "/abs/.kiro/screenshots/20260511-073000",
  "baseline_dir": "/abs/.kiro/screenshots/baselines",
  "thresholds": { "pass": 2.0, "fail": 5.0 },
  "aggregate_verdict": "PASS" | "WARNING" | "FAIL" | "MANUAL_VERIFY_REQUIRED",
  "phase": "phase-1-jsx-only" | "phase-2",
  "pairs": [
    {
      "screen": "cinematic-home",
      "state": "idle",
      "baseline_path": "...", "current_path": "...", "diff_path": "...",
      "delta_percent": 0.123,
      "verdict": "PASS",
      "non_determinism": false
    }
  ]
}
```

Downstream-скрипты парсят `aggregate_verdict` (5 значений) и
`pairs[].verdict` (3 значения).

### `report.html`

Самодостаточная HTML-страница: aggregate summary bar + per-pair
triple-grid (baseline | current | diff). Подключается без сервера
(работает с file://). Шаблон: `.kiro/screenshots/report-template.html`.

## Limitations (web ≠ TV)

Pipeline проверяет **визуальное соответствие** layout / typography /
colors / spacing относительно JSX-эталона. Он **НЕ заменяет**:

- Ручной smoke-тест на референсном Realtek `rtd2851a` TV-боксе.
- Проверку производительности (`flutter-tv-perf.md` правил).
- Проверку D-pad responsiveness и focus visuals под Impeller-рендерером
  Android TV. Web рендерится через CanvasKit, Impeller имеет другие
  text shaping / focus reticle поведение.
- Тесты video playback (`media_kit` нативно работает только на native
  таргетах).

Если pipeline говорит `PASS`, это означает «визуально совпадает с JSX»,
а не «работает на ТВ-боксе». Manual TV smoke остаётся обязательным
для merge в master любых UI правок, затрагивающих focus или performance.

## Baseline regeneration

Когда JSX-прототип в `.kiro/design/megav-iptv-handoff/project/screens/`
изменился умышленно и diff `FAIL` — это **ожидаемо**:

```sh
# Обновить один экран:
node .kiro/scripts/visual-feedback/bin/run-all.js --screen cinematic-home --baseline-only

# Обновить все 8 экранов одним проходом:
node .kiro/scripts/visual-feedback/bin/snapshot-jsx.js --all
```

После регенерации:
1. Открыть обновлённый `.kiro/screenshots/baselines/<screen>.png` —
   убедиться визуально что это намеренное изменение.
2. `git add .kiro/screenshots/baselines/<screen>.png`.
3. Commit с объяснением: «baseline refresh: <screen> — <reason>».

PNG-baselines коммитятся в git без LFS (∼1.7 MB / экран × 8 экранов
= ∼14 MB total — приемлемо).

## Known limitations

- **JSX data dependencies**: некоторые v2-компоненты (`epg-v2.jsx`,
  `player-v2.jsx`) требуют props (`channels`, `pool`, `item`), которые
  bootstrap в `jsx-renderer/index.html` не синтезирует — baseline для
  них пустой чёрный canvas. Это **JSX-handoff issue**, не pipeline.
  Workaround: добавить fake props в bootstrap, либо использовать v1-версии
  (`epg.jsx`, `player.jsx`) — но они уже выходят из текущего design language.

- **`serve` query-string drop**: `serve` v14 в SPA-mode (`-s`) стрипит
  `.html` через 301 redirect chain, теряя query string. Pipeline
  использует `serve` **без** `-s` и адресует URL с trailing slash
  (`/jsx-renderer/?screen=...`).

- **In-browser Babel**: транспиляция JSX в браузере занимает 3-5 секунд
  на холодном кеше. Snapshot-скрипты ждут `window.__rendererReady` (60s
  timeout) + `document.fonts.ready` + 600ms settle.

- **Iteration cap**: pipeline сам не имеет cap, но autopilot-orchestrator
  (`/autopilot`) — да (30 итераций). Если запускается из autopilot,
  одного полного прохода достаточно.

## Adjacent specs

- `home-grid-stability-pass` — может опционально вызывать
  `kiro-validate-visual cinematic-home` для проверки что pinned-slot
  invariant не сдвинул визуал.
- `hero-collapse-tile-morph` — после landing будет точно так же
  использовать pipeline для проверки геометрии в collapsed/expanded
  состояниях.
- `kiro-impl` reviewer-subagent любого спека **может** опционально
  вызывать `kiro-validate-visual` как extra evidence layer.
- Существующие закрытые специй (`home-cinematic-redesign`,
  `player-cinematic-redesign`, etc.) НЕ открываются для использования
  pipeline — это explicit boundary.
