const puppeteer = require('puppeteer');
const path = require('path');

(async () => {
  const theme = process.env.THEME || 'disaster_prevention';
  const outputPath = process.env.OUTPUT || './tmp/screenshot.png';
  const zoom = process.env.ZOOM || '2';
  const lat = process.env.LAT || '0';
  const lon = process.env.LON || '0';

  const baseUrl = `http://localhost:8000/styles/${theme}/`;
  const screenshotPath = path.resolve(outputPath);

  console.log(`Taking screenshot of ${baseUrl} (zoom:${zoom} lat:${lat} lon:${lon})`);

  const browser = await puppeteer.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage'
    ]
  });
  const page = await browser.newPage();
  await page.goto(baseUrl, {
    waitUntil: 'domcontentloaded',
    timeout: 120000
  });
  await page.evaluate((z, la, lo) => {
    const hash = `#${z}/${la}/${lo}`;
    if (window.location.hash !== hash) {
      window.location.hash = hash;
    }
  }, zoom, lat, lon);
  // Wait for an additional 15 seconds to ensure all tiles are loaded
  await new Promise(resolve => setTimeout(resolve, 15000));
  await page.screenshot({ path: screenshotPath });
  await browser.close();

  console.log(`Screenshot saved to: ${screenshotPath}`);
  console.log("Analyze this screenshot and describe what you see.");
})();
