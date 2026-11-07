# MegaV IPTV

IPTV-часть MegaV: Go-бэкенд `iptv-parser` и Flutter-приложение для ТВ `megav_iptv`.
Как она связана с остальными компонентами MegaV — карта системы у агентов (`~/.megav-agent/claude/topics/megav-system.md`).

## Где что лежит
- `backend/` — Go: `cmd/api-server` (API за `iptv.megav.app`), `cmd/thumbnail-worker`, `internal/`, `migrations/`.
- `megav_iptv/` — Flutter-приложение (Android TV, macOS, web).
- `charts/iptv-parser/` — Helm-чарт, namespace `megav-iptv`.

## Сборка и выкатка
- Только тегом, без ручных `helm`/`kubectl`:
  - тег `backend-*` → `.github/workflows/backend.yml` (сборка образа и деплой бэкенда);
  - тег `frontend-*` → `.github/workflows/frontend.yml` (APK и AAB, GitHub Release).
- Оба workflow идут на self-hosted раннере `[self-hosted, iptv]`.
- Мерж в `master` ничего не выкатывает.

## Процесс
Kiro и cc-sdd (Spec-Driven Development, `/kiro-*`) владелец отключил для всех агентов. По ним не работать, новых `.kiro/specs` не заводить. План задачи — коротко в самой issue.

В `.kiro/` остались закрытые спеки и заметки — это архив, не инструкция. Полезный источник фактов: `.kiro/steering/flutter-tv-perf.md`, проверенные правила производительности Flutter на ТВ-боксе Realtek `rtd2851a`. Его стоит прочитать перед работой над UI приложения.

## GitHub Issues — backlog and follow-ups

**Repo**: `Romaxa55/MegaV-IPTV` (https://github.com/Romaxa55/MegaV-IPTV)
**Authentication**: `gh` CLI is installed and authenticated (`gh auth status` shows `Romaxa55` logged in via SSH). All `gh` commands work without setup.

**Use GitHub Issues, not in-repo markdown files, for**:
- Future ideas surfaced mid-session («давай потом сделаем X»).
- Bug reports the user mentions in passing but doesn't want to fix right now.
- Operator observations from runtime logs that need follow-up (e.g. "PlayerManager retries only 3 times on DNS failure" → file as issue, do NOT add a `backlog.md`).
- Concerns outside the current task that should not be lost.
- Anything the user says should be «в задачку / в issue / в гитхаб».

**Do NOT use** in-repo files like `backlog.md`, `TODO.md`, `IDEAS.md` for the same purpose — they get stale and clutter the repo. Issues are the source of truth.

### When the user asks for an issue

Use `gh issue create` via Bash. Default labels available: `bug`, `enhancement`, `documentation`, `question`, `good first issue`, `help wanted`, `wontfix`, `dependencies`. Pick the most fitting one. If none fits — create a new label first via `gh label create <name> --color <hex> --description <text>`.

Issue body should follow this template (Russian content; English title acceptable when more searchable):

```markdown
## Симптом
What the user / operator observes. Concrete reproduction (log excerpt, screenshot, sequence of actions).

## Текущее поведение
Where in the code this lives. File:line references where useful.

## Желаемое поведение
What should happen instead. Bullet points, not prose.

## Что затронет
Which files/modules would be touched.
```

Always include relevant log excerpts verbatim when the user pastes them. Always link to the affected file:line. A new issue lands on the MegaV board (GitHub Project 5) by itself within 30 minutes; if it belongs to an epic, name it in the first line of the body (`Эпик Romaxa55/<repo>#N.`).

### When the user asks about issues

For questions like «какие issues есть» / «покажи список» / «что в issue #N»:
- `gh issue list --state open` — open issues.
- `gh issue list --state all --limit 20` — recent activity.
- `gh issue view <number>` — full body of one issue.
- `gh issue view <number> --comments` — with discussion.

Show counts and titles concisely. Don't dump full bodies unless asked.

### When the work is done

The PR that completes an issue says `Closes Romaxa55/MegaV-IPTV#N` in its body; a partial one — `Refs Romaxa55/MegaV-IPTV#N`.

### Do NOT proactively create issues

Only create issues when the user **explicitly** asks («заведи issue», «в гитхаб», «в задачку», etc.) OR when the user describes something out of the current task's scope and wants it remembered. Do NOT auto-file issues for every minor observation — that floods the tracker.
