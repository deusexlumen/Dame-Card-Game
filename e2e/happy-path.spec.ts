import { test, expect } from '@playwright/test';

test('Human-vs-AI happy path: play a full round to score calculation', async ({ page }) => {
  // Force German locale so the UI labels match the selectors below.
  await page.goto('/Dame-Card-Game/');

  // Main menu
  await expect(page.getByRole('heading', { name: 'Dame' })).toBeVisible();
  await page.getByRole('button', { name: 'Spiel starten' }).click();

  // Game start dialog
  await expect(page.getByText('Kartenspiel mit Bluff und Strategie')).toBeVisible();
  await page.getByRole('button', { name: 'Neues Spiel' }).click();

  // Peek phase: memorize the two visible cards
  await expect(page.getByText('Merke dir deine Karten')).toBeVisible();
  await page.getByRole('button', { name: 'Bereit' }).click();

  // Turn hand-off overlay
  await expect(page.getByText('Ich bin bereit')).toBeVisible();
  await page.getByRole('button', { name: 'Ich bin bereit' }).click();

  // Human turn: draw from deck, discard the drawn card, end turn
  const drawPile = page.getByRole('button', { name: 'Stapel auswählen' }).first();
  await expect(drawPile).toBeVisible();
  await drawPile.click();

  await expect(page.getByText('Gezogene Karte')).toBeVisible();
  await page.getByRole('button', { name: 'Ablegen' }).click();

  await page.getByRole('button', { name: 'Zug beenden' }).click();

  // AI turn and round-end overview
  // endTurn already incremented the round counter, so the overview shows "Runde 2 beendet!".
  await expect(page.getByText(/Runde \d+ beendet!/)).toBeVisible({ timeout: 30000 });

  // Score calculation is shown for both players
  const summary = page.locator('text=/\\+\\d+ pts/');
  await expect(summary).toHaveCount(2);

  await expect(page.getByRole('button', { name: 'Nächste Runde' })).toBeVisible();
});
