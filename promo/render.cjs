// Renders index.html frame by frame.
//   node render.cjs out.mp4                 full video
//   node render.cjs --stills dir 1.5 4.8    PNG stills at the given seconds
// Needs playwright-core on NODE_PATH, plus Google Chrome and ffmpeg.
const { chromium } = require('playwright-core');
const { spawn } = require('node:child_process');
const path = require('node:path');

const FPS = 30;

async function open() {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  await page.goto('file://' + path.join(__dirname, 'index.html') + '?render');
  await page.evaluate(() => Promise.all([
    document.fonts.ready,
    ...[...document.images].map((i) => i.decode().catch(() => { throw new Error('missing image: ' + i.src); })),
  ]));
  return { browser, page };
}

async function stills(dir, times) {
  const { browser, page } = await open();
  for (const t of times) {
    await page.evaluate((v) => window.seek(v), t);
    await page.screenshot({ path: path.join(dir, `t${String(t).padStart(5, '0')}.png`) });
  }
  await browser.close();
}

async function video(output) {
  const { browser, page } = await open();
  const duration = await page.evaluate(() => window.DURATION);
  const ffmpeg = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-i', '-',
    '-c:v', 'libx264', '-crf', '16', '-preset', 'medium', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', output],
    { stdio: ['pipe', 'inherit', 'inherit'] });
  const done = new Promise((resolve, reject) => ffmpeg.on('close', (c) => (c === 0 ? resolve() : reject(new Error(`ffmpeg exited ${c}`)))));
  const total = Math.round(duration * FPS);
  for (let i = 0; i < total; i++) {
    await page.evaluate((v) => window.seek(v), i / FPS);
    const frame = await page.screenshot({ type: 'png' });
    if (!ffmpeg.stdin.write(frame)) await new Promise((r) => ffmpeg.stdin.once('drain', r));
    if (i % 90 === 0) console.log(`frame ${i}/${total}`);
  }
  ffmpeg.stdin.end();
  await done;
  await browser.close();
  console.log('wrote', output);
}

const args = process.argv.slice(2);
const run = args[0] === '--stills' ? stills(args[1], args.slice(2).map(Number)) : video(args[0] || 'chain-promo.mp4');
run.catch((e) => { console.error(e); process.exit(1); });
