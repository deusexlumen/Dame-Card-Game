# 10x Analysis: DAME — Neubau in Godot
Session 3 | Date: 2026-10-04

## Entscheidung des Owners
Das Spiel wird **komplett neu in Godot** gebaut. Die React-Webversion ist nur noch Referenz; die Live-Seite ist egal.

## Was aus dem bisherigen Stand weiterlebt
- **Regeln:** `CONCEPT_DECISIONS.md` (inkl. Abschnitt 6/7: nur live, Abbruch-Stufen) bleibt die verbindliche Spezifikation.
- **Spiellogik:** `src/lib/gameLogic.ts` ist pur und React-frei, also eine fertige, getestete Referenzimplementierung (97 Tests), entweder zum Portieren oder direkt serverseitig nutzbar (siehe unten).
- **KI:** `src/lib/aiPlayer.ts` mit 3 Stufen als Vorlage für Bots und die „vorsichtige Ersatz-KI" bei Abbruch.
- **Produktplan:** Session 2 gilt weiter (Online v1 per Link → v2 Matchmaking/Rangliste → Kosmetik ohne Pay-to-win). Gestrichen: Web-spezifische Quick-Wins. (PWA bleibt doch, Entscheidung 2026-10-06: Plattform ist egal, Hauptsache das Spiel ist überall gleich.)

## Stand im Repo (gefunden 2026-10-06)
Das Godot-Projekt existiert bereits in `godot/` auf `main` (Godot 4.7.2, live auf GitHub Pages, 565 Tests, 3D-Casino-Tisch, 2–6 Spieler, Hot-Seat, KI, Chips/Shop). Die Regeln sind in GDScript neu geschrieben und weichen von der React-Version ab (König, Ass/Zehn, Mehrfach-Decks, Timeout-Strafkarte; siehe `CONCEPT_DECISIONS.md` §6–§9).

Wichtig für Online: Die Architektur ist schon fast server-tauglich.
- `DameRules.apply_action(action: Dictionary)` ist der einzige Schreibzugriff (eine Aktion rein, Ergebnis raus).
- `DameRules.to_dict()` / `from_dict()` serialisieren den kompletten Zustand.
- `DameView.for_viewer(state, viewer_id)` erzeugt genau die erlaubte Sicht pro Spieler (eigene bekannte Karten, Gegner nur als Anzahl, Deck nur als Zahl). Das ist exakt das, was ein Server an jeden Client schicken muss.
- Die KI arbeitet bereits nur auf `DameView`, nicht auf dem vollen Zustand.

## Backend-Empfehlung (revidiert): Headless-Godot-Server
Weil die Regeln jetzt in GDScript leben, wäre ein Nakama-TypeScript-Server eine **zweite Regel-Implementierung**, die auseinanderlaufen kann. Daher:

- **Autoritativer Server = dasselbe Godot-Projekt, headless gestartet** (`--headless`, eigene Server-Szene). Er hält `DameRules`, nimmt Aktionen per RPC entgegen, validiert über `apply_action` und schickt jedem Client nur `DameView.for_viewer(...)`.
- **Transport: `WebSocketMultiplayerPeer`.** Funktioniert im Web-Export (Browser kann kein ENet) und nativ. Später optional WebRTC.
- **Ein Regelcode für Offline, Hot-Seat und Online.** Die 565 Tests sichern auch den Server ab.
- **Lobby v1 selbst gebaut und klein:** Partie erstellen → 6-stelliger Code/Link → beitreten. Ein Server-Prozess kann viele Partien parallel halten (Kartenspiel = wenig Last).
- **Presence/Abbruch-Stufen (§11)** direkt im Server: Verbindungs- und Fokus-Events (`NOTIFICATION_APPLICATION_FOCUS_OUT`, Web `visibilitychange`) zählen die Reserven.
- **Hosting überholt (2026-10-06): kein VPS, P2P per WebRTC, siehe `docs/online-p2p-plan.md`.** Ursprünglich: kleiner VPS (Hetzner o. Ä.) mit Docker-Image des Godot-Servers hinter TLS (wss://), weil die Seite über https läuft.
- **Später (v2):** Für Accounts, Freunde, Matchmaking, Ranglisten und Echtgeld-Inventar kann **Nakama daneben** kommen. Dann macht Nakama Matchmaking/Accounts und vermittelt an Godot-Server-Instanzen, die Regeln bleiben in Godot.

Verworfen: Nakama-only mit TS-Regeln (doppelte Regeln), Supabase (kein Echtzeit-Tick, Presence/Autorität selbst stricken).

## Nächster Schritt
Bauplan „Online v1" im Stil von `docs/superpowers/plans/2026-10-04-dame-godot-bauplan.md`: Server-Szene, RPC-Protokoll (Aktion rein, View raus), Lobby/Codes, Reconnect-Token, Abbruch-Stufen, Server-Tests, Docker/Deploy, Web-Client gegen wss.
