// Renders the Google Play feature graphics (1024×500) into store/:
//   store/feature-graphic-en.png, store/feature-graphic-de.png
// Uses the app icon, real screenshots from docs/screenshots/ and Roboto from
// the Flutter SDK. Usage: node tool/store/feature_graphic.js  (needs Playwright)
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '../..');
const dataUrl = (file, type) =>
  `data:${type};base64,${fs.readFileSync(path.join(root, file)).toString('base64')}`;

function robotoFace() {
  let flutterRoot;
  try {
    flutterRoot = path.dirname(path.dirname(fs.realpathSync(execSync('which flutter').toString().trim())));
  } catch (_) {
    return '';
  }
  const dir = path.join(flutterRoot,
    'bin/cache/dart-sdk/bin/resources/devtools/assets/packages/devtools_app_shared/fonts/Roboto');
  const face = (file, weight) => fs.existsSync(path.join(dir, file))
    ? `@font-face{font-family:Roboto;font-weight:${weight};src:url(data:font/ttf;base64,${fs.readFileSync(path.join(dir, file)).toString('base64')})}`
    : '';
  return face('Roboto-Regular.ttf', 400) + face('Roboto-Bold.ttf', 700);
}

const variants = {
  en: {
    tagline: 'View, edit and create JSON files &ndash; readable, with a form editor and code view.',
    chips: ['Offline', 'No ads', 'Open source'],
    front: 'docs/screenshots/01-phone-view-light.png',
    back: 'docs/screenshots/06b-phone-text-folded-light.png',
  },
  de: {
    tagline: 'JSON-Dateien lesbar ansehen, per Formular bearbeiten und neu erstellen.',
    chips: ['Offline', 'Ohne Werbung', 'Open Source'],
    front: 'docs/screenshots/14-phone-view-de.png',
    back: 'docs/screenshots/15-phone-form-de.png',
  },
};

const html = (v) => `<!doctype html><html><head><meta charset="utf-8"><style>
${robotoFace()}
*{box-sizing:border-box;margin:0}
body{width:1024px;height:500px;overflow:hidden;font-family:Roboto,'Liberation Sans',sans-serif;
  background:radial-gradient(circle at 78% 40%,#34505c 0%,#22323a 45%,#1a2429 100%);color:#eceff1;position:relative}
.text{position:absolute;left:64px;top:86px;width:470px}
.icon{width:104px;height:104px;border-radius:24px;box-shadow:0 10px 30px rgba(0,0,0,.35)}
h1{font-size:60px;font-weight:700;letter-spacing:-.5px;margin-top:26px}
p{font-size:23px;line-height:1.38;color:#b0bec5;margin-top:12px}
.chips{display:flex;gap:10px;margin-top:24px}
.chip{font-size:16px;padding:6px 14px;border-radius:999px;background:rgba(79,195,247,.14);color:#81d4fa;border:1px solid rgba(129,212,250,.35)}
.phone{position:absolute;width:218px;height:460px;border-radius:30px;background:#0d1417;padding:8px;
  box-shadow:0 24px 50px rgba(0,0,0,.5)}
.screen{width:100%;height:100%;border-radius:23px;overflow:hidden;background:#fff}
.screen img{width:106%;display:block;margin:-12% 0 0 -3%} /* crops status bar and emulator border */
.back{left:610px;top:58px;transform:rotate(-7deg);opacity:.96}
.front{left:768px;top:34px;transform:rotate(5deg)}
</style></head><body>
<div class="text">
  <img class="icon" src="${dataUrl('store/icon-512.png', 'image/png')}">
  <h1>JSON Viewer</h1>
  <p>${v.tagline}</p>
  <div class="chips">${v.chips.map((c) => `<span class="chip">${c}</span>`).join('')}</div>
</div>
<div class="phone back"><div class="screen"><img src="${dataUrl(v.back, 'image/png')}"></div></div>
<div class="phone front"><div class="screen"><img src="${dataUrl(v.front, 'image/png')}"></div></div>
</body></html>`;

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1024, height: 500 } });
  for (const [lang, v] of Object.entries(variants)) {
    await page.setContent(html(v));
    await page.waitForTimeout(300);
    const out = path.join(root, `store/feature-graphic-${lang}.png`);
    await page.screenshot({ path: out });
    console.log('wrote', path.relative(root, out));
  }
  await browser.close();
})();
