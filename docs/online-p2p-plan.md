# Online ohne Server: WebRTC-P2P (Plan, 2026-10-06)

Ziel: Das Spiel in Gesellschaft online spielen, bei Kosten von ca. 0 EUR. Kein eigener Server. Plattform ist egal (CONCEPT_DECISIONS §12), das Spiel muss überall gleich sein.

Dieser Plan ersetzt die Hosting-Zeile in `.claude/docs/ai/dame/10x/session-3.md` (VPS mit Headless-Godot). Der Rest dieser Session bleibt gültig: Regelcode ist derselbe, `apply_action` rein, `DameView.for_viewer` raus.

## Architektur

- **Host-autoritativ.** Ein Spieler ist Host und führt `DameRules` aus. Gäste senden nur Aktionen und erhalten ihre `DameView`.
- **Transport:** `WebRTCMultiplayerPeer` (DataChannels), Host = Server-Peer.
- **Verbindungsaufbau (Signaling), kostenlos:**
  1. Raumcode (z. B. `KX7Q`) über einen Supabase-Realtime-Broadcast-Channel. Der Channel dient nur zum Austausch von SDP/ICE, danach läuft alles direkt.
  2. Notfall-Fallback: Copy-Paste-Code (Host-Code, Gast-Antwortcode), ohne jeden Dienst.
- **STUN:** öffentliche, kostenlose Server. **TURN:** zunächst keiner (siehe Risiken).

## Kosten und Grenzen (geprüft in den Supabase-Docs, 2026-10-06)

Supabase Realtime, Free-Plan:
- 200 gleichzeitige Verbindungen
- 100 Nachrichten pro Sekunde
- 2 Mio. Nachrichten pro Monat
- 256 KB pro Broadcast-Nachricht

Signaling braucht pro Beitritt nur wenige Nachrichten. Das reicht weit über private Nutzung hinaus.
Nicht geprüft: Pausierung inaktiver Free-Projekte. Vor dem Bau klären.

TURN, falls später nötig: Cloudflare Realtime TURN, laut Suchergebnis 1.000 GB/Monat gratis (Preisseite vor Nutzung gegenlesen).

## Plattformen

- **Web-Export:** WebRTC ist in Godot eingebaut.
- **Windows/Android:** Godot liefert WebRTC nativ nur über die GDExtension `webrtc-native`. Sie muss in die Exports eingebunden und getestet werden. Das ist der Preis für "überall gleich" (§12).

## Risiken (ehrlich)

1. **Host weg = Partie weg (entschieden 2026-10-06).** Verlässt der Host oder bricht seine Verbindung ab, endet die Partie für alle ohne Wertung (keine Niederlage, keine Chips). Keine Host-Migration in v1. Regel steht in CONCEPT_DECISIONS §11.
2. **Kein TURN:** Ein Teil der Verbindungen (strenge NAT, manche Mobilnetze) scheitert. v1 akzeptiert das, Copy-Paste hilft dabei nicht, da es dasselbe Netz braucht. Erst messen, dann TURN ergänzen.
3. **Host sieht alle Karten** (Client trägt vollen Zustand). Für Freunde okay, für öffentliche Matchmaking-Partien/Rangliste nicht.
4. **Rangliste/Matchmaking/Echtgeld** brauchen später doch einen vertrauenswürdigen Server. Dieser Plan deckt nur private Räume mit Freunden ab.

## Schritte

1. ✅ Netz-Kern in `godot/scripts/net/` (2026-10-06): `dame_host.gd` (autoritativ, Sitz aus Absender), `dame_guest.gd`, Binär-Codec, Aktions-Whitelist, Loopback-Link für Tests (`tests/test_net.gd`). Gemeinsame Schnittstelle: `send_action`, `poll`, Signale `view_changed`/`action_result`, Presence-Haken `peer_joined`/`peer_left`.
1b. Tisch (`table_view.gd`) auf diese Schnittstelle umstellen. Er liest heute rund 80-mal direkt `rules.state`, ein Gast hat aber nur seine Sicht. Eigener, größerer Schritt, Plan: `docs/superpowers/plans/2026-10-06-online-1b-tisch-aus-sicht.md`.
2. Protokoll: Aktion rein, View raus, Reconnect-Token, Abwesenheits-Stufen aus §11 im Host.
3. Signaling-Modul: Raumcode über Supabase-Channel, danach WebRTC-Handshake.
4. Lobby-UI: Raum erstellen / per Code beitreten.
5. Tests: Protokoll headless (ohne echtes Netz, Loopback-Peer), plus ein manueller Test zwischen zwei Browsern und zwischen Web und Windows.
6. Copy-Paste-Fallback.
7. Messen, wie oft Verbindungen ohne TURN scheitern.
