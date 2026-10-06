# DAME Online-Server

Der Server ist **dasselbe Godot-Projekt**, nur ohne Grafik gestartet. Er nutzt dieselben Regeln
(`DameRules`) wie das Spiel. Es gibt keine zweite Regel-Implementierung.

Verbindliche Online-Regeln: `CONCEPT_DECISIONS.md` §10 (nur live) und §11 (Verbindungsabbruch).

## Lokal starten

```bash
npm run server:godot            # Port 8910
# oder direkt:
godot --headless --path godot res://scenes/server.tscn -- --port=8910
```

Im Spiel: **Online spielen** → Server `ws://127.0.0.1:8910` → Partie erstellen.
Zum Testen mit mehreren Spielern einfach mehrere Spielfenster oder Browser-Tabs öffnen.
Im lokalen Netz trägt man statt `127.0.0.1` die IP des Rechners ein, auf dem der Server läuft.

## Docker

```bash
docker build -f server/Dockerfile -t dame-server .
docker run -d --restart unless-stopped -p 127.0.0.1:8910:8910 dame-server
```

## Veröffentlichen (wss://)

Die Live-Seite läuft über `https`. Browser verbinden sich von dort nur mit `wss://`.
Deshalb kommt ein Reverse-Proxy mit TLS vor den Server, am einfachsten Caddy
(`server/Caddyfile.example`). Ein kleiner VPS reicht: Ein Prozess hält viele Partien,
ein Kartenspiel erzeugt kaum Last.

Danach die Adresse fest ins Spiel eintragen, damit niemand sie tippen muss:
`godot/project.godot` → Abschnitt `[dame]` → `online/server_url="wss://dame.example.org"`.

## Wie es funktioniert

| Datei | Aufgabe |
|---|---|
| `scripts/online/online_match.gd` | Eine Partie: Zugtimer, Aussetzen, KI-Vertretung, Strafen (§10/§11) |
| `scripts/online/dame_mirror.gd` | Zustand pro Spieler ohne verdeckte Karten, ohne Seed |
| `scripts/online/room_manager.gd` | Lobby: Codes, Beitritt, Wiedereinstieg per Token |
| `scripts/online/net_server.gd` | WebSocket-Server, Nachrichtenlimit |
| `scripts/online/net_client.gd` | Client im Spiel, automatischer Wiedereinstieg |
| `scripts/online/net_protocol.gd` | Nachrichtenformat und Prüfung |

Sicherheit: Jeder Client bekommt nur seine eigene Sicht. Karten-IDs verdeckter Karten,
die Stapelreihenfolge und der Mischungs-Seed verlassen den Server nie. Das prüft
`tests/test_online.gd` über ganze Partien.
