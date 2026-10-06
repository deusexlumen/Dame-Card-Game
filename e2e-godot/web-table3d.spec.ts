import { expect, test } from '@playwright/test';

// Startet eine Partie gegen die KI und prueft, dass der 3D-Tisch im Browser laeuft.
test('Web-Build zeigt den 3D-Tisch und nimmt einen Zug an', async ({ page }) => {
  const messages: string[] = [];
  const errors: string[] = [];
  page.on('console', (msg) => {
    messages.push(msg.text());
    if (msg.type() === 'error') errors.push(msg.text());
  });
  page.on('pageerror', (err) => errors.push(err.message));

  await page.goto('./');
  const canvas = page.locator('canvas');
  await expect(canvas).toBeVisible();
  await expect.poll(() => messages.some((m) => m.includes('DAME_READY')), { timeout: 60000 }).toBe(true);

  // Fokus liegt auf "Gegen die KI spielen", im Setup auf "Start".
  await canvas.click({ position: { x: 640, y: 690 } });
  await page.keyboard.press('Enter');
  await expect.poll(() => messages.some((m) => m.includes('SCREEN_READY Setup')), { timeout: 15000 }).toBe(true);
  await page.keyboard.press('Enter');
  await expect.poll(() => messages.some((m) => m.includes('TABLE_READY 3d=true')), { timeout: 20000 }).toBe(true);

  // Leertaste zieht vom Stapel, die Hand nimmt die Karte.
  await page.waitForTimeout(1500);
  await page.keyboard.press('Space');
  await page.waitForTimeout(1500);

  const scriptErrors = errors.filter((e) => /SCRIPT ERROR|USER ERROR/.test(e));
  expect(scriptErrors).toEqual([]);
  await page.screenshot({ path: 'test-results/godot-web-table3d.png' });
});
