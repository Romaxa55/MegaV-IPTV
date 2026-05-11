// serve-helper.js — spawn `npx serve` as a child, wait for it to accept
// connections, expose a stop() handle. Used by bin/snapshot-jsx.js and
// bin/snapshot-flutter.js. Avoids `serve -s` (SPA mode) which strips .html
// and produces redirect chains to directory listings.

'use strict';

const { spawn } = require('child_process');
const path = require('path');
const http = require('http');

const SERVE_BIN = path.resolve(__dirname, '..', 'node_modules', '.bin', 'serve');

/**
 * Spawn `serve` rooted at `root` on `port`. Returns { stop }, where stop()
 * kills the child and waits for exit.
 *
 * Note: pass `root` as the LAST argument (positional); do NOT pass `-s`.
 *
 * @param {{ root: string, port?: number, quiet?: boolean }} opts
 * @returns {Promise<{ stop: () => Promise<void>, port: number }>}
 */
async function startServe({ root, port = 8765, quiet = false }) {
  const child = spawn(SERVE_BIN, ['-l', String(port), '--no-clipboard', root], {
    cwd: root,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  let ready = false;
  child.stdout.on('data', (d) => {
    const s = d.toString();
    if (!quiet) process.stderr.write('[serve] ' + s);
    if (s.includes('Accepting connections')) ready = true;
  });
  child.stderr.on('data', (d) => {
    if (!quiet) process.stderr.write('[serve!] ' + d);
  });

  // Wait up to 15s for the "Accepting connections" banner OR an actual HTTP
  // 200 on the root. Either signal is enough.
  const deadline = Date.now() + 15000;
  while (Date.now() < deadline) {
    if (ready) break;
    if (await ping(port)) {
      ready = true;
      break;
    }
    await sleep(150);
  }
  if (!ready) {
    child.kill('SIGTERM');
    throw new Error(`serve did not start on port ${port} within 15s`);
  }

  return {
    port,
    stop: () =>
      new Promise((resolve) => {
        child.once('exit', () => resolve());
        child.kill('SIGTERM');
        // hard fallback after 3s
        setTimeout(() => {
          try { child.kill('SIGKILL'); } catch (_) {}
          resolve();
        }, 3000);
      }),
  };
}

function ping(port) {
  return new Promise((resolve) => {
    const req = http.request(
      { method: 'HEAD', host: '127.0.0.1', port, path: '/', timeout: 1000 },
      (res) => {
        res.resume();
        resolve(res.statusCode != null && res.statusCode < 500);
      },
    );
    req.on('error', () => resolve(false));
    req.on('timeout', () => { req.destroy(); resolve(false); });
    req.end();
  });
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

module.exports = { startServe };
