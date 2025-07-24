const puppeteer = require('puppeteer');
const path = require('path');

(async () => {
  const theme = process.env.THEME || 'disaster_prevention';
  const outputPath = process.env.OUTPUT || './tmp/screenshot.png';
  const zoom = process.env.ZOOM || '2';
  const lat = process.env.LAT || '0';
  const lon = process.env.LON || '0';

  const url = `http://localhost:8000/styles/${theme}/#${zoom}/${lat}/${lon}`;
  const screenshotPath = path.resolve(outputPath);

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
