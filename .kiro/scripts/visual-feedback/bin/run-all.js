#!/usr/bin/env node
// run-all.js — orchestrator that drives the full visual-feedback pipeline
// for one screen.
//
// Spec: visual-feedback-pipeline req 1.3, 1.4, 1.5, 4.5
//
// Usage:
//   node bin/run-all.js --screen <name>
//                       [--baseline-only]   # only refresh JSX baseline
//                       [--skip-build]      # skip flutter build web (Phase 2)
//                       [--port 8765]
//
// PHASE 1 (CURRENT — Req 9): `flutter build web` is blocked by
// https://github.com/Romaxa55/MegaV-IPTV/issues/16 (media_kit_engine.dart
// `NativePlayer.setProperty()` does not exist on web stub). Until that
// upstream lands, this orchestrator only refreshes JSX baselines and
// returns MANUAL_VERIFY_REQUIRED for Flutter-snapshot paths.
//
// PHASE 2 (post-#16): will additionally spawn `flutter build web`, serve
// the resulting bundle, and call snapshot-flutter.js + diff.js.

'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..', '..', '..', '..');
const VFP_DIR = path.resolve(__dirname, '..');
const ISSUE_URL = 'https://github.com/Romaxa55/MegaV-IPTV/issues/16';

const KNOWN_SCREENS = [
  'cinematic-home', 'detail', 'editorial-home', 'epg',
  'mobile', 'player', 'search', 'settings',
];

function parseArgs(argv) {
  const a = { screen: null, baselineOnly: false, skipBuild: false, port: 8765 };
  for (let i = 2; i < argv.length; i++) {
    const x = argv[i];
    if (x === '--screen') a.screen = argv[++i];
    else if (x === '--baseline-only') a.baselineOnly = true;
    else if (x === '--skip-build') a.skipBuild = true;
    else if (x === '--port') a.port = Number(argv[++i]);
    else if (x === '-h' || x === '--help') {
      process.stdout.write(
        'Usage: run-all.js --screen <name> [--baseline-only] [--skip-build] [--port 8765]\n',
      );
      process.exit(0);
    }
  }
  if (!a.screen) {
    process.stderr.write('error: --screen <name> is required\n');
    process.exit(2);
  }
  if (!KNOWN_SCREENS.includes(a.screen)) {
    process.stderr.write(
      `warning: screen "${a.screen}" not in canonical list — proceeding anyway\n`,
    );
  }
  return a;
}

function log(msg) {
  process.stderr.write(`[run-all] ${msg}\n`);
}

function nowSlug() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return (
    `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}` +
    '-' +
    `${pad(d.getUTCHours())}${pad(d.getUTCMinutes())}${pad(d.getUTCSeconds())}`
  );
}

function checkPrereqs() {
  // Node ≥ 20.
  const v = process.versions.node.split('.').map(Number);
  if (v[0] < 20) {
    log(`FATAL: Node ${process.versions.node} < 20 required`);
    process.exit(1);
  }
  log(`node ${process.versions.node} ok`);

  // Flutter — informational only in Phase 1.
  const f = spawnSync('flutter', ['--version'], { encoding: 'utf8' });
  if (f.status === 0) {
    const firstLine = (f.stdout || '').split('\n')[0];
    log(`flutter ok: ${firstLine}`);
  } else {
    log('flutter NOT available — Phase 2 steps will be skipped');
  }
}

function refreshBaselineIfMissing(screen) {
  const baselinePath = path.join(
    REPO_ROOT, '.kiro', 'screenshots', 'baselines', `${screen}.png`,
  );
  if (fs.existsSync(baselinePath)) {
    log(`baseline exists: ${baselinePath}`);
    return baselinePath;
  }
  log(`baseline missing — invoking snapshot-jsx --screen ${screen}`);
  const r = spawnSync(
    'node',
    [path.join(VFP_DIR, 'bin', 'snapshot-jsx.js'), '--screen', screen],
    { stdio: 'inherit' },
  );
  if (r.status !== 0) {
    log(`snapshot-jsx failed (exit ${r.status})`);
    return null;
  }
  return baselinePath;
}

function refreshBaselineForce(screen) {
  log(`forcing baseline refresh — invoking snapshot-jsx --screen ${screen}`);
  const r = spawnSync(
    'node',
    [path.join(VFP_DIR, 'bin', 'snapshot-jsx.js'), '--screen', screen],
    { stdio: 'inherit' },
  );
  return r.status === 0;
}

function makeRunDir() {
  const dir = path.join(
    REPO_ROOT, '.kiro', 'screenshots', nowSlug(),
  );
  fs.mkdirSync(dir, { recursive: true });
  log(`run-dir: ${dir}`);
  return dir;
}

/**
 * Phase 1 stub: write a summary.json into the run-dir announcing that
 * Flutter snapshot is not available, return MANUAL_VERIFY_REQUIRED.
 */
function emitPhase1Stub(runDir, screen) {
  const summary = {
    schema: 'vfp-summary-v1',
    generated_at: new Date().toISOString(),
    run_dir: runDir,
    aggregate_verdict: 'MANUAL_VERIFY_REQUIRED',
    phase: 'phase-1-jsx-only',
    reason: `Flutter web compile blocked by upstream issue: ${ISSUE_URL}`,
    pairs: [],
    screen,
  };
  fs.writeFileSync(
    path.join(runDir, 'summary.json'),
    JSON.stringify(summary, null, 2),
  );
  log(`wrote Phase 1 stub summary.json (MANUAL_VERIFY_REQUIRED)`);
}

function main() {
  const args = parseArgs(process.argv);
  log(`screen=${args.screen} baselineOnly=${args.baselineOnly} skipBuild=${args.skipBuild}`);

  checkPrereqs();

  // Path 1: --baseline-only. Always re-runs snapshot-jsx, regardless of
  // existing baseline. This is the canonical "refresh baseline after a
  // JSX prototype change" workflow.
  if (args.baselineOnly) {
    const ok = refreshBaselineForce(args.screen);
    if (!ok) {
      log('FAIL: baseline refresh failed');
      process.exit(1);
    }
    log('DONE: baseline refreshed');
    process.exit(0);
  }

  // Path 2: full run. Phase 1 ends with MANUAL_VERIFY_REQUIRED because
  // we cannot produce a Flutter snapshot to diff against the baseline.
  const baseline = refreshBaselineIfMissing(args.screen);
  if (!baseline) {
    log('FAIL: could not obtain baseline');
    process.exit(1);
  }

  const runDir = makeRunDir();

  // Phase 2 placeholder — when issue #16 lands, replace this block with
  // an actual flutter build + serve + snapshot-flutter + diff sequence.
  log('PHASE 1: Flutter snapshot path is BLOCKED');
  log(`  upstream: ${ISSUE_URL}`);
  log(`  Flutter steps (flutter build web, snapshot-flutter, diff) are skipped`);
  emitPhase1Stub(runDir, args.screen);

  log('AGGREGATE: MANUAL_VERIFY_REQUIRED');
  // Exit 2 = WARNING-equivalent; kiro-validate-visual interprets this as
  // MANUAL_VERIFY_REQUIRED rather than NO-GO.
  process.exit(2);
}

main();
