# 10x Analysis: DAME — Entscheidungen & neue Priorität
Session 2 | Date: 2026-10-04

## Entscheidungen des Owners
- **Online-Multiplayer ist das Ziel.** Nur gegen KI zu spielen macht auf Dauer keinen Spaß.
- **Ein Backend ist okay.** Das README-Versprechen „ohne Backend" fällt (das Versprechen „ohne Tracking" kann bleiben).
- **Geld ist nicht das Ziel, aber willkommen.** Monetarisierung darf nie das Spiel stören, also kein Pay-to-win.

## Was sich gegenüber Session 1 ändert
Die „Link-Partie" wandert von *Explore* an **Platz 1**. Alles andere wird danach bewertet, ob es Online-Spiel trägt.

## Empfohlene Backend-Wahl: Supabase
- Ist in dieser Umgebung bereits verbunden (MCP), es braucht also kein neues Setup.
- **Anonymous Auth** heißt: kein Account-Zwang, ein Spieler ist ein Gerät plus ein optionaler Name. Login (Google/E-Mail) kann später kommen, z. B. für Freundesliste oder gekaufte Skins.
- **Postgres + Row Level Security** speichert den Spielzustand. Verdeckte Karten liegen in einer Tabelle, die der Client nicht direkt lesen darf.
- **Edge Functions** führen die Züge aus. `gameLogic.ts` ist React-frei und pur und kann dort im Kern unverändert laufen. Damit ist der Server die Autorität: Clients sehen nur ihre eigenen erlaubten Karten, und Schummeln über die DevTools ist unmöglich.
- **Realtime** pusht neue Züge sofort an alle in der Partie. Dasselbe System trägt auch asynchrone Partien (Zug machen, App schließen, später weiter).
- Kosten: Der Free-Tier reicht für die ersten tausenden Partien.

Alternative: Cloudflare Durable Objects (stärker für Echtzeit, aber mehr Eigenbau). Nicht empfohlen, solange Supabase reicht.

## Neue Reihenfolge

### Jetzt (vor dem Online-Bau, klein)
1. **Asset-Pfad-Bug fixen** (Skins und Musik geben in Produktion vermutlich 404).
2. **Zufall seedbar machen** (`shuffleDeck` und KI): Voraussetzung für Server-Autorität, Replays und Tagesdame.
3. **Hook entflechten**: Rundenende- und Zug-Orchestrierung aus `useGameEngine.ts` in eine pure Funktion `applyAction(state, action)` ziehen. Der Typ `GameAction` existiert bereits in `types/game.ts`. Diese Funktion läuft dann identisch im Browser (gegen KI) und auf dem Server (online).

### Online v1: „Private Partie per Link"
1. Lobby: Partie erstellen → Link/Code teilen → Freunde treten bei (2–6), offene Plätze werden mit KI aufgefüllt.
2. Server-autoritative Züge über eine Edge Function, Updates per Realtime.
3. Live **und** asynchron: Zug-Timer optional; wer offline ist, wird nach Timeout von der KI vertreten.
4. Reconnect: Tab neu laden → zurück in der Partie.
5. Share-Button und „Nochmal!" mit derselben Gruppe.

### Online v2: Wachstum
1. **Schnelles Spiel**: Matchmaking mit Fremden (2–4 Spieler).
2. Freundesliste, Rematch-Einladungen, Push-Benachrichtigung „Du bist dran" (PWA).
3. **Tagesdame** mit globaler Rangliste.
4. Ranglisten/ELO pro Saison.

### Geld (optional, ohne Pay-to-win)
1. Kosmetik: Skins, Tische, Kartenrücken, Emotes/Reaktionen am Tisch. Das bestehende Skin-System und `inventoryService` sind dafür vorbereitet.
2. Freischalten durch Spielen bleibt immer möglich; Kaufen ist nur die Abkürzung.
3. Optional „Unterstützer-Paket" (einmalig) statt Werbung. Werbung macht ein Kartenspiel kaputt.
4. Zahlung erst, wenn es echte Spieler gibt (Stripe über Supabase Edge Function).

## Offene Punkte (kein Blocker, Default gewählt)
- Kontoform: **Default anonym**, Login später optional.
- Matchmaking mit Fremden: **Default erst v2**, zuerst Freunde per Link (kleinere Moderations- und Abuse-Fläche).
- Chat: **Default nur vorgefertigte Reaktionen/Emotes**, kein Freitext (keine Moderation nötig, passt zum Bluff-Charakter).

## Nächster Schritt
Programm-Design für „Online v1" (Datenmodell, Edge Function `apply-action`, Sichtbarkeitsregeln, Realtime-Kanäle, Slices). Danach Umsetzung Slice für Slice.
