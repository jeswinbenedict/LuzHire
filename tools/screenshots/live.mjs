// Screenshots of the live site through Chrome's DevTools protocol (no
// packages: Node's own fetch and WebSocket). Flutter's WebAssembly app needs
// real time to load, so each page waits before the capture.
// usage: node tools/screenshots/live.mjs <outDir> "<name|url|width|height|dark|waitMs|scrollY>"...
import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { setTimeout as sleep } from 'node:timers/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [outDir, ...jobs] = process.argv.slice(2);
mkdirSync(outDir, { recursive: true });
const chrome = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const port = 9333;
const profile = join(tmpdir(), `luz-shots-${Date.now()}`);
const proc = spawn(chrome, [
  '--headless=new',
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${profile}`,
  '--hide-scrollbars',
  '--no-first-run',
  '--no-default-browser-check',
  'about:blank',
], { stdio: 'ignore' });

async function json(path, method = 'GET') {
  for (let i = 0; i < 50; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${port}${path}`, { method });
      return await r.json();
    } catch { await sleep(200); }
  }
  throw new Error('chrome did not start');
}

let id = 0;
function session(wsUrl) {
  const ws = new WebSocket(wsUrl);
  const pending = new Map();
  ws.onmessage = (m) => {
    const msg = JSON.parse(m.data);
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
      pending.delete(msg.id);
    }
  };
  const ready = new Promise((r) => (ws.onopen = r));
  const send = async (method, params = {}) => {
    await ready;
    const n = ++id;
    ws.send(JSON.stringify({ id: n, method, params }));
    const msg = await new Promise((r) => pending.set(n, r));
    if (msg.error) throw new Error(`${method}: ${msg.error.message}`);
    return msg.result;
  };
  return { send, close: () => ws.close() };
}

try {
  await json('/json/version');
  for (const job of jobs) {
    const [name, url, w, h, dark, waitMs, scrollY] = job.split('|');
    const target = await json(`/json/new?about:blank`, 'PUT');
    const s = session(target.webSocketDebuggerUrl);
    const width = Number(w), height = Number(h);
    const mobile = width < 600;
    await s.send('Emulation.setDeviceMetricsOverride', {
      width, height, deviceScaleFactor: mobile ? 2 : 1, mobile,
    });
    if (mobile) {
      await s.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });
    }
    await s.send('Emulation.setEmulatedMedia', {
      features: [{ name: 'prefers-color-scheme', value: dark === '1' ? 'dark' : 'light' }],
    });
    await s.send('Page.enable');
    await s.send('Page.navigate', { url });
    await sleep(Number(waitMs || 9000));
    if (Number(scrollY || 0) > 0) {
      // Flutter scrolls on wheel events at the pointer.
      await s.send('Input.dispatchMouseEvent', {
        type: 'mouseWheel', x: width / 2, y: height / 2, deltaX: 0, deltaY: Number(scrollY),
      });
      await sleep(1500);
    }
    const shot = await s.send('Page.captureScreenshot', { format: 'png' });
    writeFileSync(join(outDir, `${name}.png`), Buffer.from(shot.data, 'base64'));
    console.log('saved', name);
    s.close();
    await fetch(`http://127.0.0.1:${port}/json/close/${target.id}`).catch(() => {});
  }
} finally {
  proc.kill();
}
