const puppeteer = require('puppeteer');
const path = require('path');

(async () => {
  const theme = process.argv[2] || 'disaster_prevention';
  const url = `http://localhost:8000/styles/${theme}/#2/0/0`;
  const screenshotPath = path.resolve('./tmp/screenshot.png');

  console.log(`Taking screenshot of ${url}`);

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
  await page.goto(url, {
    waitUntil: 'networkidle0',
  });
  // Wait for an additional 15 seconds to ensure all tiles are loaded
  await new Promise(resolve => setTimeout(resolve, 15000));
  await page.screenshot({ path: screenshotPath });
  await browser.close();

  console.log(`Screenshot saved to: ${screenshotPath}`);
  console.log("Analyze this screenshot and describe what you see.");
})();
