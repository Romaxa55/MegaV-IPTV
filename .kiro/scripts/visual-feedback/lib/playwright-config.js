// playwright-config.js — shared headless Chromium context for snapshots.
//
// Spec: visual-feedback-pipeline req 6.1, 6.3 (deterministic 1920x1080 viewport,
// reduced motion, no scaling).
//
// Usage:
//   const { createBrowserContext, closeBrowserContext } = require('./playwright-config');
//   const { browser, context, page } = await createBrowserContext();
//   // ... use page ...
//   await closeBrowserContext({ browser });

'use strict';

const { chromium } = require('playwright');

const VIEWPORT = Object.freeze({ width: 1920, height: 1080 });
const DEVICE_SCALE_FACTOR = 1;

/**
 * Launch a headless Chromium with a fixed viewport optimised for deterministic
 * snapshots. Returns { browser, context, page }.
 *
 * @param {object} [overrides] - optional partial override of context defaults
 * @returns {Promise<{browser:import('playwright').Browser,
 *                     context:import('playwright').BrowserContext,
 *                     page:import('playwright').Page}>}
 */
async function createBrowserContext(overrides = {}) {
  const browser = await chromium.launch({
    headless: true,
    args: [
      '--force-prefers-reduced-motion',
      '--disable-renderer-backgrounding',
      '--disable-background-timer-throttling',
      '--disable-features=IsolateOrigins,site-per-process',
      '--no-sandbox',
    ],
  });

  const context = await browser.newContext({
    viewport: VIEWPORT,
    deviceScaleFactor: DEVICE_SCALE_FACTOR,
    reducedMotion: 'reduce',
    locale: 'ru-RU',
    timezoneId: 'Europe/Moscow',
    ...overrides,
  });

  const page = await context.newPage();
  return { browser, context, page };
}

/**
 * Tear down browser. Safe to call multiple times; ignores already-closed.
 */
async function closeBrowserContext({ browser }) {
  if (!browser) return;
  try {
    await browser.close();
  } catch (_) {
    // browser already closed — no-op
  }
}

module.exports = {
  VIEWPORT,
  DEVICE_SCALE_FACTOR,
  createBrowserContext,
  closeBrowserContext,
};
