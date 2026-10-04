# 10x Analysis: DAME — Neubau in Godot
Session 3 | Date: 2026-10-04

## Entscheidung des Owners
Das Spiel wird **komplett neu in Godot** gebaut. Die React-Webversion ist nur noch Referenz; die Live-Seite ist egal.

## Was aus dem bisherigen Stand weiterlebt
- **Regeln:** `CONCEPT_DECISIONS.md` (inkl. Abschnitt 6/7: nur live, Abbruch-Stufen) bleibt die verbindliche Spezifikation.
- **Spiellogik:** `src/lib/gameLogic.ts` ist pur und React-frei, also eine fertige, getestete Referenzimplementierung (97 Tests), entweder zum Portieren oder direkt serverseitig nutzbar (siehe unten).
- **KI:** `src/lib/aiPlayer.ts` mit 3 Stufen als Vorlage für Bots und die „vorsichtige Ersatz-KI" bei Abbruch.
- **Produktplan:** Session 2 gilt weiter (Online v1 per Link → v2 Matchmaking/Rangliste → Kosmetik ohne Pay-to-win). Gestrichen: PWA, Web-spezifische Quick-Wins.

## Backend-Empfehlung neu: Nakama statt Supabase
Für ein Godot-Echtzeit-Kartenspiel ist **Nakama** (Open-Source-Gameserver von Heroic Labs) die passendere Wahl:
- Offizieller **Godot-Client** (GDScript).
- **Server-autoritative Matches** mit Tick-Loop: Der Server hält die verdeckten Karten, Clients bekommen nur ihre erlaubte Sicht.
- **Presence, Reconnect und Matchmaking eingebaut**, also genau das, was die Abbruch-Stufen (60 s / 2 Min. / 5 Min.) brauchen.
- Match-Logik kann in **TypeScript** geschrieben werden, damit lässt sich `gameLogic.ts` fast 1:1 als Server-Regelwerk übernehmen. Godot rendert nur noch und schickt Aktionen (`GameAction` aus `types/game.ts`).
- Gerätebasierte Anmeldung ohne Account-Zwang, später Social Login; Leaderboards und Wallet/Inventar für Kosmetik sind ebenfalls eingebaut.
- Hosting: selbst (Docker + Postgres/CockroachDB, ein kleiner VPS reicht anfangs) oder Heroic Cloud.

Alternative: **Headless-Godot-Server** mit Godots eigenem High-Level-Multiplayer. Vorteil: Regeln einmal in GDScript für Client und Server. Nachteil: Matchmaking, Reconnect, Accounts, Leaderboards alles selbst bauen. Nur sinnvoll, wenn bewusst alles in Godot bleiben soll.

Supabase rutscht ab: Es hat keinen Godot-First-Support für autoritative Echtzeit-Matches, und Presence/Tick-Logik müsste man selbst zusammenstecken.

## Offen
- Gibt es schon ein Godot-Projekt/Repo? (Dieses Repo ist aktuell nur in `deusexlumen/Dame-Card-Game` freigegeben.)
- Godot-Version (Annahme: 4.x) und Zielplattformen (Annahme: Android/iOS + Desktop, Web optional).
- Bauen wir Godot im selben Repo (z. B. `godot/` + `server/`) oder in einem neuen?
