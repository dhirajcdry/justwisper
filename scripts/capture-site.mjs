// Reproducible browser captures. See docs/ASSETS.md for setup and invocation.
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const base = process.env.WISPR_PREVIEW_URL || 'http://127.0.0.1:8765';
const output = path.resolve('site/assets');
await mkdir(output, { recursive: true });
const browser = await chromium.launch({ channel: process.env.PLAYWRIGHT_CHANNEL || undefined });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 }, deviceScaleFactor: 2 });
const errors = [];
page.on('pageerror', error => errors.push(error.message));
await page.goto(`${base}/site/`, { waitUntil: 'networkidle' });
await page.locator('img').evaluateAll(images => images.forEach(image => image.loading = 'eager'));
await page.locator('img').evaluateAll(images => Promise.all(images.map(image => image.decode())));
await page.screenshot({ path: '/tmp/justwisper-site-desktop.png', fullPage: true });
for (const style of ['galley', 'column', 'ticker', 'proof']) {
  await page.locator(`[data-style="${style}"]`).click();
  await page.locator('#style-image').evaluate(image => image.decode());
  if (await page.locator(`[data-style="${style}"]`).getAttribute('aria-pressed') !== 'true') throw new Error('Overlay selector failed');
}
await page.locator('summary').first().click();
if (!(await page.locator('details').first().evaluate(detail => detail.open))) throw new Error('FAQ did not open');
await page.setViewportSize({ width: 390, height: 844 });
await page.evaluate(() => scrollTo(0, 0));
await page.screenshot({ path: '/tmp/justwisper-site-mobile.png', fullPage: true });
const overflow = await page.evaluate(() => document.documentElement.scrollWidth > innerWidth);
if (overflow) throw new Error('Mobile layout overflows horizontally');
const brokenImages = await page.locator('img').evaluateAll(images => images.filter(image => !image.complete || !image.naturalWidth).map(image => image.src));
if (brokenImages.length || errors.length) throw new Error(JSON.stringify({ brokenImages, errors }));
// Share card + README header, captured from the same source.
await page.setViewportSize({ width: 1200, height: 630 });
await page.goto(`${base}/scripts/visuals.html`, { waitUntil: 'networkidle' });
await page.evaluate(() => document.fonts.ready);
await page.locator('img').evaluateAll(images => Promise.all(images.map(image => image.decode())));
await page.screenshot({ path: path.join(output, 'social-card.png') });
// Three honest, clearly labeled walkthrough frames. No transcription timing claim.
await page.setViewportSize({ width: 1440, height: 1000 });
await page.goto(`${base}/site/`, { waitUntil: 'networkidle' });
await page.locator('#walkthrough').scrollIntoViewIfNeeded();
await page.addStyleTag({ content: '.demo-overlay { transition: none !important; }' });
await page.locator('#play-demo').click();
await mkdir('/tmp/justwisper-walkthrough', { recursive: true });
for (let step = 0; step < 3; step++) {
  await page.waitForFunction(expected => document.querySelector('#walkthrough').dataset.step === String(expected), step);
  await page.locator('#walkthrough').screenshot({ path: `/tmp/justwisper-walkthrough/step-${step}.png` });
}
await page.waitForFunction(() => document.querySelector('#play-demo').textContent.includes('Replay'));
await page.locator('#play-demo').click();
if (await page.locator('#walkthrough').getAttribute('data-step') !== '0') throw new Error('Replay failed');
await browser.close();
await writeFile('/tmp/justwisper-web-checks.json', JSON.stringify({ mobileOverflow: overflow, brokenImages, browserErrors: errors, overlayStyles: 4, walkthroughSteps: 3 }, null, 2));
console.log('Desktop/mobile captures, social card, walkthrough frames, and browser checks passed.');
