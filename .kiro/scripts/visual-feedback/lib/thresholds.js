// thresholds.js — load configurable pass/fail thresholds for diff classification.
//
// Spec: visual-feedback-pipeline req 4.2, 4.3.
//
// Default thresholds: delta < 2.0% → PASS, delta > 5.0% → FAIL, between → WARNING.
// Override via `.kiro/screenshots/config.json` with shape:
//   { "pass_threshold": 2.0, "fail_threshold": 5.0 }

'use strict';

const fs = require('fs');

const DEFAULTS = Object.freeze({ pass: 2.0, fail: 5.0 });

/**
 * Load thresholds from `.kiro/screenshots/config.json` if present; otherwise
 * return defaults and log the fallback to stderr (Req 4.3).
 *
 * @param {string} configPath - absolute path to config.json
 * @returns {{ pass: number, fail: number }}
 */
function loadThresholds(configPath) {
  if (!configPath || !fs.existsSync(configPath)) {
    process.stderr.write(
      `[thresholds] config.json not found at ${configPath || '(unset)'} — using defaults pass=${DEFAULTS.pass}% fail=${DEFAULTS.fail}%\n`,
    );
    return { ...DEFAULTS };
  }

  try {
    const raw = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    const pass = Number(raw.pass_threshold);
    const fail = Number(raw.fail_threshold);
    if (!Number.isFinite(pass) || !Number.isFinite(fail) || pass < 0 || fail <= pass) {
      process.stderr.write(
        `[thresholds] invalid values in ${configPath} (pass=${pass}, fail=${fail}) — using defaults\n`,
      );
      return { ...DEFAULTS };
    }
    return { pass, fail };
  } catch (e) {
    process.stderr.write(
      `[thresholds] failed to parse ${configPath}: ${e.message} — using defaults\n`,
    );
    return { ...DEFAULTS };
  }
}

/**
 * Classify a single diff delta percentage according to thresholds.
 *
 * @param {number} deltaPercent
 * @param {{ pass: number, fail: number }} thresholds
 * @returns {'PASS' | 'WARNING' | 'FAIL'}
 */
function classify(deltaPercent, thresholds) {
  const { pass, fail } = thresholds;
  if (deltaPercent < pass) return 'PASS';
  if (deltaPercent > fail) return 'FAIL';
  return 'WARNING';
}

module.exports = { DEFAULTS, loadThresholds, classify };
