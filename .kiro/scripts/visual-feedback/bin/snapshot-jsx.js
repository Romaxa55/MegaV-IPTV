#!/usr/bin/env node
// snapshot-jsx.js — capture a JSX prototype baseline PNG for one or all
// screens defined by the renderer's SCREEN_MAP.
//
// Spec: visual-feedback-pipeline req 2.1, 2.2, 2.3, 2.4
//
// Usage:
//   node bin/snapshot-jsx.js --screen cinematic-home
//   node bin/snapshot-jsx.js --all
//   node bin/snapshot-jsx.js --all --port 8765 --out .kiro/screenshots/baselines/
//
// On success a PNG file lands at <out>/<screen>.png at exactly 1920x1080,
// deviceScaleFactor=1, animations disabled. Re-runs are designed to be
// byte-identical for the same source JSX.

'use strict';

const fs = require('fs');
const path = require('path');

const { createBrowserContext, closeBrowserContext, VIEWPORT } = require('../lib/playwright-config');
const { loadPng, savePng, assertDimensions } = require('../lib/png-utils');
const { startServe } = require('../lib/serve-helper');

// Resolve project root by walking up from this file: bin/snapshot-jsx.js →
// visual-feedback/ → scripts/ → .kiro/ → repo root.
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..', '..');

const DEFAULT_PORT = 8765;
const DEFAULT_OUT = path.join(REPO_ROOT, '.kiro', 'screenshots', 'baselines');
const SETTLE_MS = 600;
const READY_TIMEOUT_MS = 60000;

// Screen slugs we know the renderer can produce (mirrors SCREEN_MAP in
// jsx-renderer/index.html). Kept in alphabetical order for stable iteration.
const ALL_SCREENS = [
  'cinematic-home',
  'detail',
  'editorial-home',
  'epg',
  'mobile',
  'player',
  'search',
  'settings',
];

function parseArgs(argv) {
  const args = { screen: null, all: false, port: DEFAULT_PORT, out: DEFAULT_OUT };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--screen') args.screen = argv[++i];
    else if (a === '--all') args.all = true;
    else if (a === '--port') args.port = Number(argv[++i]);
    else if (a === '--out') args.out = argv[++i];
    else if (a === '-h' || a === '--help') {
      process.stdout.write(
        'Usage: snapshot-jsx.js [--screen <slug>] [--all] [--port 8765] [--out <dir>]\n',
      );
      process.exit(0);
    }
  }
  if (!args.all && !args.screen) {
    process.stderr.write('error: pass --screen <slug> or --all\n');
    process.exit(2);
  }
  return args;
}

function screenUrl(port, slug) {
  // IMPORTANT: must NOT use /index.html in the path — `serve` strips .html
  // and produces a 301 chain that drops the query string, so the renderer
  // sees ?screen=null and falls back to its default (cinematic-home).
  // The trailing slash makes serve return index.html directly, query intact.
  return (
    `http://localhost:${port}/.kiro/scripts/visual-feedback/jsx-renderer/` +
    `?screen=${encodeURIComponent(slug)}`
  );
}

/**
 * Capture one screen baseline. Returns { slug, status, path, error }.
 * status ∈ {'ok','renderer_error','navigation_error','dimension_error'}
 */
async function captureOne({ page, port, slug, outDir }) {
  const url = screenUrl(port, slug);

  // Go to about:blank first to fully drop the previous document. Without this
  // step, when the renderer fast-loads from disk cache it can race and we end
  // up screenshotting the previous screen because window.__rendererReady is
  // still true from the prior navigation by the time we evaluate it.
  try {
    await page.goto('about:blank', { waitUntil: 'load', timeout: 10000 });
  } catch (_) {
    // best-effort
  }

  try {
    await page.goto(url, { waitUntil: 'load', timeout: 30000 });
  } catch (e) {
    return { slug, status: 'navigation_error', error: e.message };
  }

  // Wait for the renderer's readiness flag. In-browser Babel transpile makes
  // this 3-5s on a cold cache. Because we go through about:blank first,
  // window.__rendererReady is guaranteed to be set freshly by THIS document.
  try {
    await page.waitForFunction(
      () => window.__rendererReady === true,
      null,
      { timeout: READY_TIMEOUT_MS, polling: 200 },
    );
  } catch (e) {
    return { slug, status: 'renderer_error', error: 'timeout waiting for __rendererReady: ' + e.message };
  }

  const rendererErr = await page.evaluate(() => window.__rendererError || null);
  if (rendererErr) {
    return { slug, status: 'renderer_error', error: rendererErr };
  }

  // Wait for web fonts and a settle margin for layout to stabilise.
  await page.evaluate(() => (document.fonts ? document.fonts.ready : Promise.resolve()));
  await page.waitForTimeout(SETTLE_MS);

  // Capture.
  const filepath = path.join(outDir, slug + '.png');
  fs.mkdirSync(outDir, { recursive: true });
  await page.screenshot({ path: filepath, fullPage: false });

  // Validate dimensions via png-utils (loads it back, checks 1920x1080).
  try {
    const png = loadPng(filepath);
    assertDimensions(png, VIEWPORT.width, VIEWPORT.height);
    // Re-save normalised — pngjs round-trip strips any non-deterministic
    // chunks (tIME, gAMA) Playwright might emit, yielding more stable bytes.
    savePng(filepath, png);
  } catch (e) {
    return { slug, status: 'dimension_error', error: e.message, path: filepath };
  }

  return { slug, status: 'ok', path: filepath };
}

async function main() {
  const args = parseArgs(process.argv);
  const screens = args.all ? ALL_SCREENS : [args.screen];

  let serve;
  try {
    serve = await startServe({ root: REPO_ROOT, port: args.port, quiet: true });
  } catch (e) {
    process.stderr.write('FATAL: ' + e.message + '\n');
    process.exit(1);
  }

  const { browser, page } = await createBrowserContext();
  page.on('pageerror', (err) =>
    process.stderr.write('[browser-error] ' + err.message + '\n'),
  );

  const results = [];
  try {
    for (const slug of screens) {
      process.stderr.write(`[snapshot-jsx] ${slug} … `);
      const r = await captureOne({ page, port: args.port, slug, outDir: args.out });
      results.push(r);
      if (r.status === 'ok') {
        process.stderr.write(`ok → ${r.path}\n`);
      } else {
        process.stderr.write(`SKIP (${r.status}: ${r.error})\n`);
      }
    }
  } finally {
    await closeBrowserContext({ browser });
    await serve.stop();
  }

  const failed = results.filter((r) => r.status !== 'ok');
  process.stderr.write(
    `[snapshot-jsx] done — ${results.length - failed.length}/${results.length} ok\n`,
  );
  process.exit(failed.length === 0 ? 0 : 1);
}

main().catch((e) => {
  process.stderr.write('UNHANDLED: ' + e.stack + '\n');
  process.exit(1);
});
