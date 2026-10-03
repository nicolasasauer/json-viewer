// Renders the legacy launcher PNGs (API < 26) and the 512px Play Store icon
// from tool/icon/icon.svg. Usage: node tool/icon/render.js  (needs Playwright)
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '../..');
const svg = fs.readFileSync(path.join(__dirname, 'icon.svg'), 'utf8');
const res = path.join(root, 'android/app/src/main/res');
const targets = [
  ['mipmap-mdpi/ic_launcher.png', 48, 'legacy'],
  ['mipmap-hdpi/ic_launcher.png', 72, 'legacy'],
  ['mipmap-xhdpi/ic_launcher.png', 96, 'legacy'],
  ['mipmap-xxhdpi/ic_launcher.png', 144, 'legacy'],
  ['mipmap-xxxhdpi/ic_launcher.png', 192, 'legacy'],
].map(([p, s, k]) => [path.join(res, p), s, k]);
targets.push([path.join(root, 'store/icon-512.png'), 512, 'store']);

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  for (const [file, size, kind] of targets) {
    // Legacy icons: rounded square showing the 18..90 region (the visible part
    // of an adaptive icon). Store icon: full-bleed square, Play applies the mask.
    const inner = kind === 'legacy'
      ? `<div style="width:${size * 0.92}px;height:${size * 0.92}px;margin:${size * 0.04}px;border-radius:${size * 0.2}px;overflow:hidden">
           <div style="width:100%;height:100%;background:url('data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}') center/150% no-repeat"></div></div>`
      : `<div style="width:${size}px;height:${size}px;background:#1E2A30 url('data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}') center/125% no-repeat"></div>`;
    await page.setViewportSize({ width: size, height: size });
    await page.setContent(`<html><body style="margin:0;background:transparent">${inner}</body></html>`);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    await page.screenshot({ path: file, omitBackground: true });
    console.log('wrote', path.relative(root, file));
  }
  await browser.close();
})();
