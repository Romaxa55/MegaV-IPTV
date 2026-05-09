# Agentic SDLC and Spec-Driven Development

Kiro-style Spec-Driven Development on an agentic SDLC

## Project Context

### Paths
- Steering: `.kiro/steering/`
- Specs: `.kiro/specs/`

### Steering vs Specification

**Steering** (`.kiro/steering/`) - Guide AI with project-wide rules and context
**Specs** (`.kiro/specs/`) - Formalize development process for individual features

### Active Specifications
- Check `.kiro/specs/` for active specifications
- Use `/kiro-spec-status [feature-name]` to check progress

## Development Guidelines
- Think in English, generate responses in Russian. All Markdown content written to project files (e.g., requirements.md, design.md, tasks.md, research.md, validation reports) MUST be written in the target language configured for this specification (see spec.json.language).

## Minimal Workflow
- Phase 0 (optional): `/kiro-steering`, `/kiro-steering-custom`
- Discovery: `/kiro-discovery "idea"` — determines action path, writes brief.md + roadmap.md for multi-spec projects
- Phase 1 (Specification):
  - Single spec: `/kiro-spec-quick {feature} [--auto]` or step by step:
    - `/kiro-spec-init "description"`
    - `/kiro-spec-requirements {feature}`
    - `/kiro-validate-gap {feature}` (optional: for existing codebase)
    - `/kiro-spec-design {feature} [-y]`
    - `/kiro-validate-design {feature}` (optional: design review)
    - `/kiro-spec-tasks {feature} [-y]`
  - Multi-spec: `/kiro-spec-batch` — creates all specs from roadmap.md in parallel by dependency wave
- Phase 2 (Implementation): `/kiro-impl {feature} [tasks]`
  - Without task numbers: autonomous mode (subagent per task + independent review + final validation)
  - With task numbers: manual mode (selected tasks in main context, still reviewer-gated before completion)
  - `/kiro-validate-impl {feature}` (standalone re-validation)
- Progress check: `/kiro-spec-status {feature}` (use anytime)

## Skills Structure
Skills are located in `.claude/skills/kiro-*/SKILL.md`
- Each skill is a directory with a `SKILL.md` file
- Skills run inline with access to conversation context
- Skills may delegate parallel research to subagents for efficiency
- Additional files (templates, examples) can be added to skill directories
- `kiro-review` — task-local adversarial review protocol used by reviewer subagents
- `kiro-debug` — root-cause-first debug protocol used by debugger subagents
- `kiro-verify-completion` — fresh-evidence gate before success or completion claims
- **If there is even a 1% chance a skill applies to the current task, invoke it.** Do not skip skills because the task seems simple.

## Development Rules
- 3-phase approval workflow: Requirements → Design → Tasks → Implementation
- Human review required each phase; use `-y` only for intentional fast-track
- Keep steering current and verify alignment with `/kiro-spec-status`
- Follow the user's instructions precisely, and within that scope act autonomously: gather the necessary context and complete the requested work end-to-end in this run, asking questions only when essential information is missing or the instructions are critically ambiguous.

## GitHub Issues — backlog and follow-ups

**Repo**: `Romaxa55/MegaV-IPTV` (https://github.com/Romaxa55/MegaV-IPTV)
**Authentication**: `gh` CLI is installed and authenticated (`gh auth status` shows `Romaxa55` logged in via SSH). All `gh` commands work without setup.

**Use GitHub Issues, not in-repo markdown files, for**:
- Future spec ideas surfaced mid-session («давай потом сделаем X»).
- Bug reports the user mentions in passing but doesn't want to fix right now.
- Operator observations from runtime logs that need follow-up (e.g. "PlayerManager retries only 3 times on DNS failure" → file as issue, do NOT add a `.kiro/backlog.md`).
- Cross-spec concerns that are out-of-boundary for the current spec but should not be lost.
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

## Boundary candidates
Which files/modules would be touched if/when this becomes a spec.

## Action
The kiro entry point to use when the time comes — e.g. `/kiro-discovery <feature-name>` or `/kiro-spec-quick <feature>` if the boundary is already clear.

## Related specs
Link to closed/in-progress kiro specs in `.kiro/specs/` that touch the same domain.
```

Always include relevant log excerpts verbatim when the user pastes them. Always link to the affected file:line. Always end with the kiro entry point so the issue is actionable.

### When the user asks about issues

For questions like «какие issues есть» / «покажи список» / «что в issue #N»:
- `gh issue list --state open` — open issues.
- `gh issue list --state all --limit 20` — recent activity.
- `gh issue view <number>` — full body of one issue.
- `gh issue view <number> --comments` — with discussion.

Show counts and titles concisely. Don't dump full bodies unless asked.

### When closing a kiro spec

If a kiro spec resolves an existing issue, mention the issue number in the closing commit message and run `gh issue close <number> --comment "Resolved in <spec-name> (commit <sha>)"` after the merge commit lands.

### Do NOT proactively create issues

Only create issues when the user **explicitly** asks («заведи issue», «в гитхаб», «в задачку», etc.) OR when the user describes something out of the current spec's scope and wants it remembered. Do NOT auto-file issues for every minor observation — that floods the tracker.

## Steering Configuration
- Load entire `.kiro/steering/` as project memory
- Default files: `product.md`, `tech.md`, `structure.md`
- Custom files are supported (managed via `/kiro-steering-custom`)
