const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 430, height: 932 } });
  await page.goto('http://localhost:8895', { waitUntil: 'networkidle', timeout: 20000 }).catch(e => console.log('nav err:', e.message));
  await page.waitForTimeout(5000);
  await page.screenshot({ path: 'C:\\bamabao\\app\\build\\vp.png', fullPage: false });
  await page.close();
  await browser.close();
  console.log('DONE');
})();
