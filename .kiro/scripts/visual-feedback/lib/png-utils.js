// png-utils.js — load/save/validate PNGs for visual-feedback pipeline.
//
// Spec: visual-feedback-pipeline req 2.2, 3.3 (1920x1080 PNG everywhere).

'use strict';

const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

/**
 * Synchronously load a PNG file from disk into a pngjs PNG instance.
 * Throws if the file does not exist or is not a valid PNG.
 *
 * @param {string} filepath - absolute or cwd-relative path
 * @returns {import('pngjs').PNG}
 */
function loadPng(filepath) {
  const buf = fs.readFileSync(filepath);
  return PNG.sync.read(buf);
}

/**
 * Synchronously save a pngjs PNG instance to disk. Creates parent directories
 * as needed.
 *
 * @param {string} filepath - target path
 * @param {import('pngjs').PNG} png
 */
function savePng(filepath, png) {
  fs.mkdirSync(path.dirname(filepath), { recursive: true });
  const buf = PNG.sync.write(png);
  fs.writeFileSync(filepath, buf);
}

/**
 * Throws if the PNG dimensions do not match exactly. Used as a guard around
 * baseline/current snapshots so we never compare images of different sizes.
 *
 * @param {import('pngjs').PNG} png
 * @param {number} width
 * @param {number} height
 */
function assertDimensions(png, width, height) {
  if (png.width !== width || png.height !== height) {
    throw new Error(
      `PNG dimensions mismatch: expected ${width}x${height}, got ${png.width}x${png.height}`,
    );
  }
}

module.exports = { loadPng, savePng, assertDimensions };
