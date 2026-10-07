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
2. **TURN (seit 2026-10-07 vorbereitet):** Ohne TURN scheitert ein Teil der Verbindungen (strenge NAT, manche Mobilnetze). Lösung: Cloudflare Realtime TURN (1.000 GB/Monat gratis, danach $0.05/GB). Eine Supabase Edge Function (`supabase/functions/turn-credentials`) hält den Schlüssel und gibt 12-h-Zugangsdaten aus; das Spiel holt sie vor jeder Einladung/jedem Beitritt (`IceFetcher`, 4 s Zeitlimit) und fällt sonst auf STUN zurück. Plan: `docs/superpowers/plans/2026-10-07-online-turn-fallback.md`.
   - **Stand 2026-10-07:** Cloudflare verlangt zum Aktivieren eine Zahlungsart, deshalb vorerst **ExpressTURN** (1.000 GB/Monat gratis, feste Zugangsdaten). Funktion läuft im Supabase-Projekt `biunpatbnpbvwprfltni`, `TURN_URL` ist eingetragen. Secrets für ExpressTURN: `TURN_URLS` (kommagetrennt), `TURN_USERNAME`, `TURN_CREDENTIAL`. Ohne Secrets antwortet die Funktion 503 und das Spiel nimmt nur STUN. **Geprüft 2026-10-07:** Secrets gesetzt, Funktion liefert `turn:free.expressturn.com:3478` (UDP+TCP); Chrome mit `iceTransportPolicy: "relay"` bekommt Relay-Kandidaten über UDP und TCP. Offen: echte Partie mit Gast im Mobilfunknetz.
   - **Einrichtung (einmalig, Nutzer):** Cloudflare-Dashboard → Realtime → TURN → Schlüssel anlegen (Key-ID + API-Token). Dann `supabase secrets set CF_TURN_KEY_ID=<id> CF_TURN_API_TOKEN=<token>` und `supabase functions deploy turn-credentials --no-verify-jwt`. Die Funktions-URL in `godot/scripts/net/net_config.gd` (`TURN_URL`) eintragen. Schlüssel nie ins Repo.
   - **Offen vor Live-Gang:** Die URL ist öffentlich, jeder kann Zugangsdaten holen und Kontingent verbrauchen. Klären, was Cloudflare bei Überschreitung tut (mit hinterlegter Zahlungsart: Kosten möglich).
   - **Bekannte Grenze:** `webrtc-native` (libdatachannel) kann TURN möglicherweise nur über UDP. Ein weiterleitender Browser-Gast (TLS auf 443) reicht meist.
3. **Host sieht alle Karten** (Client trägt vollen Zustand). Für Freunde okay, für öffentliche Matchmaking-Partien/Rangliste nicht.
4. **Rangliste/Matchmaking/Echtgeld** brauchen später doch einen vertrauenswürdigen Server. Dieser Plan deckt nur private Räume mit Freunden ab.

## Schritte

1. ✅ Netz-Kern in `godot/scripts/net/` (2026-10-06): `dame_host.gd` (autoritativ, Sitz aus Absender), `dame_guest.gd`, Binär-Codec, Aktions-Whitelist, Loopback-Link für Tests (`tests/test_net.gd`). Gemeinsame Schnittstelle: `send_action`, `poll`, Signale `view_changed`/`action_result`, Presence-Haken `peer_joined`/`peer_left`.
1b. ✅ 2026-10-06: Tisch (`table_view.gd`) auf diese Schnittstelle umstellen. Er liest nur seine `DameView` und schreibt nur über die Session; Host führt Regeln und AI aus, Gast hat nur Views.
1c. ✅ 2026-10-07 (Plan `2026-10-07-online-2-webrtc-verbindung.md`): Link-Adapter `PeerLink` über `MultiplayerPeer`, `RtcConnector` mit Copy-Paste-Codes, Online-Host-Tisch, `webrtc-native` 1.2.2 für Windows/Linux per Ladeskript, Test-UI „Online (Test)“. Gemessen im Browser-Test: Einladung 802 Zeichen, Antwort 720 Zeichen (Ziel unter 1500). Zwei Browser-Seiten verbinden sich und spielen einen Zug (`npm run test:godot:online`). Offen: Test zwischen zwei echten Geräten, davon einer im Mobilfunknetz.
2. Protokoll: Aktion rein, View raus, Reconnect-Token, Abwesenheits-Stufen aus §11 im Host.
3. Signaling-Modul: Raumcode über Supabase-Channel, danach WebRTC-Handshake.
4. Lobby-UI: Raum erstellen / per Code beitreten.
5. Tests: Protokoll headless (ohne echtes Netz, Loopback-Peer), plus ein manueller Test zwischen zwei Browsern und zwischen Web und Windows.
6. ✅ Copy-Paste-Fallback (2026-10-07, siehe 1c).
7. Messen, wie oft Verbindungen ohne TURN scheitern.
