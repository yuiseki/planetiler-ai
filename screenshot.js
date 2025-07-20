const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: "new",
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--single-process'
    ]
  });
  const page = await browser.newPage();
  await page.goto('http://localhost:8000/styles/human_security/#0.81/0/0', {
    waitUntil: 'networkidle0',
  });
  // Wait for an additional 15 seconds to ensure all tiles are loaded
  await new Promise(resolve => setTimeout(resolve, 15000));
  await page.screenshot({ path: '/home/yuiseki/src/github.com/yuiseki/planetiler-ai/tmp/screenshot.png' });
  await browser.close();
})();
