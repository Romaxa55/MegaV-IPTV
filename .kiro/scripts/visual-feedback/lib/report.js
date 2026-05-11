// report.js — render an HTML diff report from a summary object.
//
// Spec: visual-feedback-pipeline req 4.4.
//
// Usage:
//   const { renderReport } = require('./report');
//   renderReport({
//     title, runDir, sourceLabel, generatedAt, thresholds: { pass, fail },
//     pairs: [{ screen, state, baseline_path, current_path, diff_path,
//               delta_percent, verdict }]
//   }, templatePath, outputPath);
//
// We intentionally use simple mustache-style {{placeholder}} substitution
// rather than pulling in a templating dependency. The template is fully
// owned by this repo (.kiro/screenshots/report-template.html), so escape
// rules can stay narrow: HTML-escape the small set of values that come from
// the summary, leave the rest literal.

'use strict';

const fs = require('fs');
const path = require('path');

const VALID_VERDICTS = new Set(['PASS', 'WARNING', 'FAIL']);

/**
 * HTML-escape a value going into an attribute or text node.
 * @param {unknown} v
 * @returns {string}
 */
function esc(v) {
  return String(v == null ? '' : v)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Compute aggregate verdict from a list of pair verdicts.
 * - any FAIL  → FAIL
 * - any WARNING (no FAIL) → WARNING
 * - else      → PASS
 * @param {Array<{verdict: string}>} pairs
 * @returns {'PASS' | 'WARNING' | 'FAIL'}
 */
function aggregateVerdict(pairs) {
  let anyFail = false;
  let anyWarn = false;
  for (const p of pairs) {
    if (p.verdict === 'FAIL') anyFail = true;
    else if (p.verdict === 'WARNING') anyWarn = true;
  }
  if (anyFail) return 'FAIL';
  if (anyWarn) return 'WARNING';
  return 'PASS';
}

/**
 * Resolve an image src for the HTML — prefer a path relative to outputPath
 * when both share a common ancestor; otherwise fall back to the absolute
 * path (which still opens in browsers via file://).
 */
function relSrc(filePath, outputPath) {
  if (!filePath) return '';
  try {
    const outDir = path.dirname(path.resolve(outputPath));
    const abs = path.resolve(filePath);
    let rel = path.relative(outDir, abs);
    if (!rel || rel.startsWith('..')) {
      // Different root — emit as file:// so the browser still resolves it.
      return 'file://' + abs;
    }
    return rel;
  } catch (_) {
    return filePath;
  }
}

function renderPair(pair, outputPath) {
  const verdict = VALID_VERDICTS.has(pair.verdict) ? pair.verdict : 'WARNING';
  const delta = typeof pair.delta_percent === 'number' ? pair.delta_percent.toFixed(3) : '—';
  const baselineSrc = relSrc(pair.baseline_path, outputPath);
  const currentSrc = relSrc(pair.current_path, outputPath);
  const diffSrc = relSrc(pair.diff_path, outputPath);

  const imgOrMissing = (src, label, reason) =>
    src
      ? `<img src="${esc(src)}" alt="${esc(label)} for ${esc(pair.screen)}/${esc(pair.state)}" loading="lazy"/>`
      : `<div class="missing">${esc(reason || 'missing')}</div>`;

  return [
    '<div class="pair">',
    '  <div class="pair-header">',
    `    <div class="name">${esc(pair.screen || '?')}</div>`,
    `    <div class="state">${esc(pair.state || '')}</div>`,
    `    <div class="delta">Δ <span class="num">${esc(delta)}%</span></div>`,
    `    <span class="verdict-pill ${verdict}">${verdict}</span>`,
    '  </div>',
    '  <div class="triple">',
    '    <figure><figcaption>baseline</figcaption>' + imgOrMissing(baselineSrc, 'baseline', 'no baseline') + '</figure>',
    '    <figure><figcaption>current</figcaption>'  + imgOrMissing(currentSrc, 'current', 'no current')   + '</figure>',
    '    <figure><figcaption>diff mask</figcaption>' + imgOrMissing(diffSrc, 'diff', 'no diff')           + '</figure>',
    '  </div>',
    '</div>',
  ].join('\n');
}

/**
 * Render the summary into HTML using the template at templatePath and
 * write the result to outputPath. Returns the resolved outputPath.
 *
 * @param {object} summary
 * @param {string} templatePath
 * @param {string} outputPath
 * @returns {string}
 */
function renderReport(summary, templatePath, outputPath) {
  const tpl = fs.readFileSync(templatePath, 'utf8');

  const pairs = Array.isArray(summary.pairs) ? summary.pairs : [];
  const agg = summary.aggregate_verdict || aggregateVerdict(pairs);
  const counts = {
    pass: pairs.filter((p) => p.verdict === 'PASS').length,
    warning: pairs.filter((p) => p.verdict === 'WARNING').length,
    fail: pairs.filter((p) => p.verdict === 'FAIL').length,
  };
  const thresholds = summary.thresholds || { pass: 2.0, fail: 5.0 };

  const vars = {
    title: summary.title || 'Visual Feedback Report',
    generated_at: summary.generated_at || new Date().toISOString(),
    run_dir: summary.run_dir || '?',
    source_label: summary.source_label || 'JSX baselines',
    aggregate_verdict: VALID_VERDICTS.has(agg) ? agg : aggregateVerdict(pairs),
    pair_count: String(pairs.length),
    pass_count: String(counts.pass),
    warning_count: String(counts.warning),
    fail_count: String(counts.fail),
    pass_threshold: String(thresholds.pass),
    fail_threshold: String(thresholds.fail),
    pairs_html: pairs.map((p) => renderPair(p, outputPath)).join('\n'),
  };

  let html = tpl;
  for (const [k, v] of Object.entries(vars)) {
    // pairs_html is the only field that intentionally contains HTML; everything
    // else has gone through esc() already at use sites, but be defensive and
    // escape strings here too for the simple-substitution placeholders.
    const replacement = k === 'pairs_html' ? v : esc(v);
    html = html.split('{{' + k + '}}').join(replacement);
  }

  fs.mkdirSync(path.dirname(path.resolve(outputPath)), { recursive: true });
  fs.writeFileSync(outputPath, html, 'utf8');
  return path.resolve(outputPath);
}

module.exports = { renderReport, aggregateVerdict };
