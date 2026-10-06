import { expect, test } from '@playwright/test';

// Laedt den Godot-Web-Export, wartet auf das Hauptmenue und prueft die Eingabe.
test('Web-Build startet ins Hauptmenue und reagiert auf Eingaben', async ({ page }) => {
  const messages: string[] = [];
  const errors: string[] = [];
  page.on('console', (msg) => {
    messages.push(msg.text());
    if (msg.type() === 'error') errors.push(msg.text());
  });
  page.on('pageerror', (err) => errors.push(err.message));

  // Relativ, damit der Test auch unter einem Unterpfad (GitHub Pages) laeuft.
  await page.goto('./');
  const canvas = page.locator('canvas');
  await expect(canvas).toBeVisible();
  await expect.poll(() => messages.some((m) => m.includes('DAME_READY')), { timeout: 150000 }).toBe(true);

  // Erst klicken (Fokus, Audio-Freigabe), dann Taste: Pfeil runter + Enter oeffnet Hot-Seat-Setup.
  await canvas.click({ position: { x: 640, y: 690 } });
  await page.keyboard.press('ArrowDown');
  await page.keyboard.press('Enter');
  await expect
    .poll(() => messages.some((m) => m.includes('SCREEN_READY Setup')), { timeout: 60000 })
    .toBe(true);

  const scriptErrors = errors.filter((e) => /SCRIPT ERROR|USER ERROR/.test(e));
  expect(scriptErrors).toEqual([]);
  await page.screenshot({ path: 'test-results/godot-web.png' });
});
