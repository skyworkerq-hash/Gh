const { chromium } = require('playwright');
const handle = process.argv[2] || 'vikamomplants';

const targets = [
  `https://imginn.com/${handle}/`,
  `https://www.picuki.com/profile/${handle}`,
  `https://gramhir.com/profile/${handle}`,
  `https://greatfon.com/v/${handle}`,
  `https://anonyig.com/en/profile/${handle}/`,
];

(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  const ctx = await browser.newContext({
    locale: 'en-US',
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36',
    ignoreHTTPSErrors: true,
    viewport: { width: 1200, height: 1400 },
  });
  for (const url of targets) {
    const page = await ctx.newPage();
    const res = { url };
    try {
      const r = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 40000 });
      res.status = r && r.status();
      await page.waitForTimeout(5000);
      res.title = await page.title();
      const txt = await page.evaluate(() => document.body ? document.body.innerText : '');
      res.text = txt.replace(/\n{2,}/g, '\n').slice(0, 1800);
      const slug = url.replace(/[^a-z0-9]+/gi, '_').slice(0, 40);
      await page.screenshot({ path: `/root/smm/v_${slug}.png`, fullPage: false });
      res.shot = `/root/smm/v_${slug}.png`;
    } catch (e) {
      res.error = String(e).slice(0, 160);
    }
    console.log('\n===== ' + url + ' =====');
    console.log(JSON.stringify(res, null, 2));
    await page.close();
  }
  await browser.close();
})();
