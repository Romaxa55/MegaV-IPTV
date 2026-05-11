#!/usr/bin/env node
// diff.js — pixelmatch the current snapshot run against committed baselines,
// produce diff PNGs, summary.json and report.html.
//
// Spec: visual-feedback-pipeline req 4.1, 4.2, 4.5, 4.6.
//
// Usage:
//   node bin/diff.js --run-dir <ts>            # required
//                    [--baseline-dir <path>]   # default .kiro/screenshots/baselines/
//                    [--config <path>]         # default .kiro/screenshots/config.json
//                    [--template <path>]       # default .kiro/screenshots/report-template.html
//
// Reads <run-dir>/manifest.json. For each entry { screen, state, path } looks
// up baseline at <baseline-dir>/<screen>.png. Writes diff-<screen>-<state>.png
// next to the current PNG, writes summary.json and report.html in <run-dir>/.
//
// Phase 1 caveat (Req 9): when the run was produced by snapshot-jsx (i.e.
// states list is just "idle"), the baseline naming is per-screen, no state.
// For Phase 2 snapshot-flutter runs the same baseline is reused for every
// state — that comparison is approximate but is the agreed v1 behaviour
// (per design note in tasks.md 5.2).

'use strict';

const fs = require('fs');
const path = require('path');

// pixelmatch 6.x ships as ESM with a default export; under CommonJS we
// need .default. Be robust to either shape.
const _pxm = require('pixelmatch');
const pixelmatch = typeof _pxm === 'function' ? _pxm : _pxm.default;
const { PNG } = require('pngjs');

const { loadPng, savePng, assertDimensions } = require('../lib/png-utils');
const { loadThresholds, classify } = require('../lib/thresholds');
const { renderReport, aggregateVerdict } = require('../lib/report');

const REPO_ROOT = path.resolve(__dirname, '..', '..', '..', '..');
const VIEWPORT_W = 1920;
const VIEWPORT_H = 1080;
const PIXELMATCH_THRESHOLD = 0.1; // per-pixel match sensitivity (0..1)

function parseArgs(argv) {
  const args = {
    runDir: null,
    baselineDir: path.join(REPO_ROOT, '.kiro', 'screenshots', 'baselines'),
    config: path.join(REPO_ROOT, '.kiro', 'screenshots', 'config.json'),
    template: path.join(REPO_ROOT, '.kiro', 'screenshots', 'report-template.html'),
  };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--run-dir') args.runDir = argv[++i];
    else if (a === '--baseline-dir') args.baselineDir = argv[++i];
    else if (a === '--config') args.config = argv[++i];
    else if (a === '--template') args.template = argv[++i];
    else if (a === '-h' || a === '--help') {
      process.stdout.write(
        'Usage: diff.js --run-dir <path> [--baseline-dir <path>] [--config <path>] [--template <path>]\n',
      );
      process.exit(0);
    }
  }
  if (!args.runDir) {
    process.stderr.write('error: --run-dir is required\n');
    process.exit(2);
  }
  args.runDir = path.resolve(args.runDir);
  if (!fs.existsSync(args.runDir)) {
    process.stderr.write(`error: run-dir not found: ${args.runDir}\n`);
    process.exit(2);
  }
  return args;
}

function diffOnePair({ baselinePath, currentPath, diffPath }) {
  const baseline = loadPng(baselinePath);
  assertDimensions(baseline, VIEWPORT_W, VIEWPORT_H);
  const current = loadPng(currentPath);
  assertDimensions(current, VIEWPORT_W, VIEWPORT_H);

  const diff = new PNG({ width: VIEWPORT_W, height: VIEWPORT_H });
  const count = pixelmatch(
    baseline.data,
    current.data,
    diff.data,
    VIEWPORT_W,
    VIEWPORT_H,
    { threshold: PIXELMATCH_THRESHOLD },
  );
  savePng(diffPath, diff);

  const totalPx = VIEWPORT_W * VIEWPORT_H;
  return {
    delta_count: count,
    delta_percent: (count / totalPx) * 100,
  };
}

function main() {
  const args = parseArgs(process.argv);
  const manifestPath = path.join(args.runDir, 'manifest.json');
  if (!fs.existsSync(manifestPath)) {
    process.stderr.write(`error: manifest.json not found in ${args.runDir}\n`);
    process.exit(2);
  }
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  if (!Array.isArray(manifest) || manifest.length === 0) {
    process.stderr.write('error: manifest.json is empty or not an array\n');
    process.exit(2);
  }

  const thresholds = loadThresholds(args.config);

  const pairs = [];
  for (const entry of manifest) {
    const { screen, state } = entry;
    if (!screen) {
      process.stderr.write(`[diff] skipping entry with no screen: ${JSON.stringify(entry)}\n`);
      continue;
    }
    const currentPath = entry.path
      ? (path.isAbsolute(entry.path) ? entry.path : path.join(args.runDir, entry.path))
      : path.join(args.runDir, `${screen}-${state || 'idle'}.png`);
    const baselinePath = path.join(args.baselineDir, `${screen}.png`);
    const diffPath = path.join(args.runDir, `diff-${screen}-${state || 'idle'}.png`);

    if (!fs.existsSync(currentPath)) {
      pairs.push({
        screen, state: state || 'idle',
        current_path: currentPath, baseline_path: null, diff_path: null,
        delta_percent: null, verdict: 'WARNING',
        reason: 'missing_current',
      });
      process.stderr.write(`[diff] ${screen}/${state || 'idle'}: WARNING — current PNG missing\n`);
      continue;
    }
    if (!fs.existsSync(baselinePath)) {
      pairs.push({
        screen, state: state || 'idle',
        current_path: currentPath, baseline_path: null, diff_path: null,
        delta_percent: null, verdict: 'WARNING',
        reason: 'missing_baseline',
      });
      process.stderr.write(`[diff] ${screen}/${state || 'idle'}: WARNING — baseline missing\n`);
      continue;
    }

    let result;
    try {
      result = diffOnePair({ baselinePath, currentPath, diffPath });
    } catch (e) {
      pairs.push({
        screen, state: state || 'idle',
        current_path: currentPath, baseline_path: baselinePath, diff_path: null,
        delta_percent: null, verdict: 'FAIL',
        reason: 'diff_error: ' + e.message,
      });
      process.stderr.write(`[diff] ${screen}/${state || 'idle'}: FAIL — ${e.message}\n`);
      continue;
    }
    const verdict = classify(result.delta_percent, thresholds);
    pairs.push({
      screen, state: state || 'idle',
      current_path: currentPath,
      baseline_path: baselinePath,
      diff_path: diffPath,
      delta_percent: result.delta_percent,
      verdict,
    });
    process.stderr.write(
      `[diff] ${screen}/${state || 'idle'}: ${verdict} (${result.delta_percent.toFixed(3)}%)\n`,
    );
  }

  const agg = aggregateVerdict(pairs);

  const summary = {
    schema: 'vfp-summary-v1',
    generated_at: new Date().toISOString(),
    run_dir: args.runDir,
    baseline_dir: args.baselineDir,
    thresholds,
    aggregate_verdict: agg,
    pairs,
  };
  const summaryPath = path.join(args.runDir, 'summary.json');
  fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));
  process.stderr.write(`[diff] wrote ${summaryPath}\n`);

  const reportPath = path.join(args.runDir, 'report.html');
  renderReport(
    {
      title: 'Visual Feedback Report — ' + path.basename(args.runDir),
      run_dir: args.runDir,
      generated_at: summary.generated_at,
      source_label: 'JSX vs JSX (Phase 1)',
      thresholds,
      pairs,
    },
    args.template,
    reportPath,
  );
  process.stderr.write(`[diff] wrote ${reportPath}\n`);

  process.stderr.write(`[diff] aggregate: ${agg}\n`);
  // Exit code: 0 PASS, 1 FAIL, 2 WARNING-only
  if (agg === 'FAIL') process.exit(1);
  if (agg === 'WARNING') process.exit(2);
  process.exit(0);
}

main();
