import { expect, test, type Page } from '@playwright/test';

// Zwei Seiten im selben Browser-Kontext verbinden sich per Copy-Paste-Codes (WebRTC,
// kein Server) und spielen einen Zug. Gesteuert ueber die e2e-Bruecke (?e2e=1):
// window.dameHostInvite/dameGuestJoin/dameHostAccept und Konsolenzeilen ONLINE_*.

type Log = { page: Page; lines: string[]; errors: string[] };

function watch(page: Page): Log {
  const log: Log = { page, lines: [], errors: [] };
  page.on('console', (msg) => {
    log.lines.push(msg.text());
    if (msg.type() === 'error') log.errors.push(msg.text());
  });
  page.on('pageerror', (err) => log.errors.push(err.message));
  return log;
}

// Erste Konsolenzeile mit dem Praefix (Rest der Zeile), sonst warten.
async function lineAfter(log: Log, prefix: string, timeout: number): Promise<string> {
  let found = '';
  await expect
    .poll(
      () => {
        // Gescheitert: sofort abbrechen statt das ganze Zeitlimit zu warten.
        const failed = log.lines.find((m) => m.startsWith('ONLINE_FAILED'));
        if (failed) throw new Error(`${failed} (beim Warten auf ${prefix.trim()})`);
        const l = log.lines.find((m) => m.startsWith(prefix));
        found = l ? l.slice(prefix.length).trim() : '';
        return l !== undefined;
      },
      { timeout, message: `${prefix} nicht gesehen` },
    )
    .toBe(true);
  return found;
}

type ViewLine = { seat: number; rev: number; turn: number };

function views(log: Log): ViewLine[] {
  const out: ViewLine[] = [];
  for (const l of log.lines) {
    const m = /^ONLINE_VIEW seat=(\d+) rev=(\d+) turn=(-?\d+)/.exec(l);
    if (m) out.push({ seat: Number(m[1]), rev: Number(m[2]), turn: Number(m[3]) });
  }
  return out;
}

async function bridgeReady(page: Page, fn: string): Promise<void> {
  await page.waitForFunction((name) => typeof (window as never)[name] === 'function', fn, {
    timeout: 150000,
  });
}

// Bei Fehlschlag: Konsolenzeilen beider Seiten ausgeben (Diagnose ohne Bildschirm).
const logs: Log[] = [];
// eslint-disable-next-line no-empty-pattern
test.afterEach(async ({}, info) => {
  if (info.status === info.expectedStatus) return;
  logs.forEach((log, i) => {
    console.log(`--- Seite ${i === 0 ? 'A (Host)' : 'B (Gast)'} ---`);
    for (const l of log.lines.slice(-60)) console.log(l.slice(0, 300));
    for (const e of log.errors.slice(-20)) console.log('ERR ' + e.slice(0, 300));
  });
});

test('Zwei Browser-Seiten verbinden sich per WebRTC und spielen einen Zug', async ({ context }) => {
  const t0 = Date.now();
  const stamp = (what: string) => console.log(`[${((Date.now() - t0) / 1000).toFixed(1)}s] ${what}`);
  const a = watch(await context.newPage());
  const b = watch(await context.newPage());
  logs.push(a, b);

  // Direkt in den Online-Bildschirm (nur mit e2e=1 erlaubt).
  await Promise.all([a.page.goto('./?e2e=1&screen=online'), b.page.goto('./?e2e=1&screen=online')]);
  await Promise.all([bridgeReady(a.page, 'dameHostInvite'), bridgeReady(b.page, 'dameGuestJoin')]);
  stamp('beide Online-Bildschirme bereit');

  await a.page.evaluate(() => (window as unknown as { dameHostInvite: () => void }).dameHostInvite());
  const invite = await lineAfter(a, 'ONLINE_INVITE ', 60000);
  stamp(`Einladung (${invite.length} Zeichen)`);

  await b.page.evaluate(
    (code) => (window as unknown as { dameGuestJoin: (c: string) => void }).dameGuestJoin(code),
    invite,
  );
  const answer = await lineAfter(b, 'ONLINE_ANSWER ', 60000);
  stamp(`Antwort (${answer.length} Zeichen)`);

  await a.page.evaluate(
    (code) => (window as unknown as { dameHostAccept: (c: string) => void }).dameHostAccept(code),
    answer,
  );
  await Promise.all([lineAfter(a, 'ONLINE_CONNECTED', 60000), lineAfter(b, 'ONLINE_CONNECTED', 60000)]);
  stamp('verbunden');
  expect(await lineAfter(a, 'ONLINE_TABLE ', 60000)).toBe('seat=0');
  expect(await lineAfter(b, 'ONLINE_TABLE ', 60000)).toBe('seat=1');
  stamp('beide am Tisch');

  // Beide Tische haben eine Sicht; wer am Zug ist, steht in der letzten Sicht.
  await expect.poll(() => views(a).length > 0 && views(b).length > 0, { timeout: 120000 }).toBe(true);
  const turn = views(a)[views(a).length - 1].turn;
  expect([0, 1]).toContain(turn);
  const mover = turn === 0 ? a : b;
  const other = turn === 0 ? b : a;
  const otherSeat = turn === 0 ? 1 : 0;
  // Warten, bis der Tisch steht (Austeil-Animation), dann ist die Sicht ruhig.
  await mover.page.waitForTimeout(3000);
  const revBefore = Math.max(...views(other).map((v) => v.rev));
  stamp(`am Zug: Platz ${turn}, rev vorher ${revBefore}`);

  // Fokus auf die Leinwand (ohne Klick: unten liegt die eigene Hand), dann Leertaste: ziehen.
  await mover.page.locator('canvas').focus();
  await mover.page.keyboard.press('Space');
  await expect
    .poll(() => views(other).some((v) => v.seat === otherSeat && v.rev > revBefore), {
      // Unter SwiftShader kam die Sicht beim Gast bis zu ~90 s nach dem Host an
      // (beide 3D-Tische teilen sich die CPU, unter 1 Bild/s).
      timeout: 240000,
      message: 'Die andere Seite meldet keine neue Sicht',
    })
    .toBe(true);
  stamp('andere Seite hat die neue Sicht');

  for (const log of [a, b]) {
    const scriptErrors = log.errors.filter((e) => /SCRIPT ERROR|USER ERROR/.test(e));
    expect(scriptErrors).toEqual([]);
  }
  await a.page.screenshot({ path: 'test-results/godot-online-host.png' });
  await b.page.screenshot({ path: 'test-results/godot-online-guest.png' });
});
