---
name: kiro-validate-visual
description: Validate UI feature visual fidelity against JSX baselines via the visual-feedback pipeline (Playwright snapshot + pixelmatch diff). Returns GO/NO-GO/MANUAL_VERIFY_REQUIRED. Optional, opt-in for downstream specs.
allowed-tools: Read, Bash, Grep, Glob
argument-hint: <feature-name>
---

# kiro-validate-visual Skill

## Role
Per-task reviewers check that code matches the spec. Per-feature
`/kiro-validate-impl` checks cross-task integration. This skill adds a
**third, optional layer**: pixel-level visual fidelity of the rendered UI
against the JSX baseline produced by `.kiro/scripts/visual-feedback/`.

It is an opt-in gate. Downstream specs (e.g. `home-grid-stability-pass`,
`hero-collapse-tile-morph`) may invoke it from within `kiro-impl`
reviewers when they need pixel-level evidence; nothing breaks if they
don't.

This skill **does not** modify the existing kiro skills (`kiro-impl`,
`kiro-validate-impl`, etc.). Its only artefacts live under
`.kiro/scripts/visual-feedback/`, `.kiro/screenshots/`, and this
directory.

## Phase 1 caveat (Req 9 / GitHub #16)

Until [issue #16](https://github.com/Romaxa55/MegaV-IPTV/issues/16)
(`media_kit_engine.dart` web compile) lands, this skill **cannot**
produce real Flutter snapshots and will return
`MANUAL_VERIFY_REQUIRED` for any feature that requires Flutter-side
comparison. Baselines for JSX prototypes can still be regenerated via
`--baseline-only`.

## Core Mission

- **Success Criteria**:
  - Run `bin/run-all.js --screen <feature>` end-to-end without crashing
  - Read the resulting `summary.json` (schema `vfp-summary-v1`)
  - Return a structured markdown report that downstream callers can grep
    for `DECISION:` to gate further work

## Execution Steps

### Step 1: Detect target

Parse `$ARGUMENTS`. The first non-flag token is the feature name (same
slug used by `.kiro/specs/<feature>/`). If empty, return:

```
DECISION: MANUAL_VERIFY_REQUIRED
REASON: no feature name provided
```

The feature slug doubles as the screen slug for the visual-feedback
pipeline. If the two diverge in a future spec, this skill can grow a
`--screen <slug>` flag.

### Step 2: Gather context

If `.kiro/specs/<feature>/spec.json` exists, read its `language` field
so output messages can match the spec's language. Otherwise default to
the project's `language` from any root config (Russian for MegaV).

Read `.kiro/steering/visual-feedback.md` for current Phase 1 / Phase 2
status. Skip if absent.

### Step 3: Discover canonical command

The pipeline's canonical entry point is:

```sh
node .kiro/scripts/visual-feedback/bin/run-all.js --screen <feature>
```

This is the only command this skill needs to invoke. It handles
prerequisite checks (Node ≥ 20, Flutter availability), baseline
refresh, snapshot capture, and diff in one call.

Do NOT shell out to lower-level binaries (`bin/snapshot-jsx.js`,
`bin/diff.js`) directly. They are pipeline internals and may change.

### Step 4: Execute the pipeline

Run the canonical command via Bash. Capture:
- stdout / stderr (full)
- exit code

The orchestrator's exit code semantics:
- `0` — pipeline ran cleanly to a definitive verdict (PASS or no flutter step needed)
- `1` — concrete FAIL or hard error (no baseline, dimension mismatch)
- `2` — WARNING (in Phase 1: always returned, means
  MANUAL_VERIFY_REQUIRED because Flutter snapshot is blocked)

If the pipeline cannot even start (`node` missing, broken
`node_modules/`, baseline directory unreadable), return:

```
DECISION: MANUAL_VERIFY_REQUIRED
REASON: pipeline could not start — <stderr excerpt>
REMEDIATION: cd .kiro/scripts/visual-feedback && npm install &&
             npx playwright install chromium
```

### Step 5: Read the structured result

The orchestrator writes its summary to a timestamped run-dir under
`.kiro/screenshots/`. Find the newest one and read `summary.json`:

```sh
ls -td .kiro/screenshots/[0-9]*/ | head -1
cat <that-dir>/summary.json
```

Expected schema (`vfp-summary-v1`):

```json
{
  "schema": "vfp-summary-v1",
  "generated_at": "...ISO 8601...",
  "run_dir": "...absolute path...",
  "aggregate_verdict": "PASS | WARNING | FAIL | MANUAL_VERIFY_REQUIRED",
  "phase": "phase-1-jsx-only" | "phase-2",
  "thresholds": { "pass": 2.0, "fail": 5.0 },
  "pairs": [
    {
      "screen": "...",
      "state": "...",
      "delta_percent": <number|null>,
      "verdict": "PASS | WARNING | FAIL",
      "non_determinism": <boolean>,
      "baseline_path": "...", "current_path": "...", "diff_path": "..."
    }
  ]
}
```

If `summary.json` is missing, malformed, or the schema field is not
`vfp-summary-v1`, return `MANUAL_VERIFY_REQUIRED` with details.

### Step 6: Map verdict and emit structured report

Convert `aggregate_verdict` to the kiro-style DECISION:

| aggregate                    | DECISION                 |
|------------------------------|--------------------------|
| `PASS`                       | GO                       |
| `WARNING`                    | MANUAL_VERIFY_REQUIRED   |
| `FAIL`                       | NO-GO                    |
| `MANUAL_VERIFY_REQUIRED`     | MANUAL_VERIFY_REQUIRED   |

Output exactly this markdown block (the language for prose can be
Russian if spec language is `ru`; the structured fields stay English so
downstream skills can grep):

```
## kiro-validate-visual report

- DECISION: <GO | NO-GO | MANUAL_VERIFY_REQUIRED>
- FEATURE: <feature>
- AGGREGATE_VERDICT: <PASS | WARNING | FAIL | MANUAL_VERIFY_REQUIRED>
- PHASE: <phase-1-jsx-only | phase-2>
- RUN_DIR: <absolute path>
- HTML_REPORT: <absolute path to report.html, if produced>
- THRESHOLDS: pass < <X>% · fail > <Y>%

### PAIRS (<N> total)

| screen | state | delta% | verdict | non-determinism |
|--------|-------|--------|---------|-----------------|
| ...    | ...   | ...    | ...     | ...             |

### REMEDIATION

<only present when DECISION is NO-GO or MANUAL_VERIFY_REQUIRED>
- For each FAIL pair: open <diff_path> and identify the regions that
  drifted; either fix the implementation or, if the JSX prototype was
  the source of truth and is now stale, regenerate the baseline with
  `node .kiro/scripts/visual-feedback/bin/run-all.js --screen <feature>
  --baseline-only` and re-run validation.
- For MANUAL_VERIFY_REQUIRED in Phase 1: known limitation, see
  https://github.com/Romaxa55/MegaV-IPTV/issues/16.
```

## Critical Constraints

- **Read-only on spec files**: never modify `.kiro/specs/<feature>/*`.
  This skill is a gate, not a writer.
- **Do not modify other skills**: never touch `.claude/skills/kiro-impl/`,
  `.claude/skills/kiro-validate-impl/`, etc.
- **Do not commit screenshots**: transient run-dirs under
  `.kiro/screenshots/<timestamp>/` are gitignored. The skill produces
  them but does not stage them.
- **Boundary**: the skill belongs to spec `visual-feedback-pipeline`. Any
  change to the orchestrator command (`bin/run-all.js`) or summary
  schema is a revalidation trigger that requires bumping this skill's
  step 5/6 to match.

## Output Description

The skill's only output is the structured markdown block from Step 6.
No tool result table, no agent invocation summary, no extra prose
after the block. Downstream callers (`kiro-impl` reviewer, manual
operator) read it as a single artefact.

## Safety & Fallback

- **No pipeline available**: if `node`/`playwright` are not installed,
  return `MANUAL_VERIFY_REQUIRED` with the exact `npm install` /
  `playwright install chromium` commands.
- **No baseline yet**: the orchestrator will auto-run `snapshot-jsx`
  to create it; no special handling needed here.
- **Phase 1 default**: every full run currently ends in
  `MANUAL_VERIFY_REQUIRED` per Req 9. This is expected, not a bug.
  Downstream specs should not block on it unless they specifically
  want pixel-level fidelity (in which case they wait for issue #16).
