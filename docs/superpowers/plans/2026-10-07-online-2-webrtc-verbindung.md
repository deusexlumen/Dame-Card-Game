# Online 2: Echte Verbindung per WebRTC — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Vor jeder Godot-Arbeit Skill `dame-godot` laden.

**Goal:** Zwei Geräte spielen zum ersten Mal wirklich miteinander. Der Host erzeugt einen Verbindungscode, der Gast fügt ihn ein und schickt einen Antwortcode zurück. Danach sitzen beide am selben Tisch, ohne Server.

**Architecture:** Ein `PeerLink` macht aus jedem Godot-`MultiplayerPeer` dieselbe `send`/`receive`-Schnittstelle, die heute der Loopback-Link hat. Dadurch bleiben `DameHost`/`DameGuest` unverändert. Ein `RtcConnector` baut die WebRTC-Verbindung auf und packt Angebot/Antwort samt ICE-Kandidaten in je einen kurzen Code (nicht-trickelnd: erst senden, wenn alle Kandidaten gesammelt sind). Der Tisch bekommt den fehlenden Online-Host-Modus. Raumcode über Supabase folgt im nächsten Plan; Copy-Paste bleibt danach als Fallback.

**Tech Stack:** Godot 4.7.2 (`WebRTCPeerConnection`, `WebRTCMultiplayerPeer`, `ENetMultiplayerPeer` für Tests), GDExtension `webrtc-native` 1.2.1 (MIT) für Windows/Linux, Playwright für den Browser-Test.

**Spec:** `docs/online-p2p-plan.md`, `CONCEPT_DECISIONS.md` §10–§12. Baut auf Branch `feat/online-net-core` (PR #14) auf; dieser Plan läuft auf `feat/online-webrtc`.

## Global Constraints

- Engine Godot 4.7.2, GL Compatibility. Regeln nur in `DameRules`, kein zweiter Regelcode.
- `DameHost`/`DameGuest`/`net_protocol.gd` bleiben inhaltlich gleich; neu ist nur die Transportschicht darunter.
- Der Sitz kommt immer aus dem Absender (Peer-ID), nie aus der Nachricht. Host-Peer-ID ist `1`.
- Kein eigener Server, keine kostenpflichtigen Dienste. STUN: `stun:stun.l.google.com:19302`. Kein TURN in diesem Plan.
- Verbindungscodes: nur SDP + ICE-Kandidaten + Version, komprimiert, URL-sicheres Base64. Fremde/kaputte Codes dürfen nie abstürzen (immer Fehlertext statt Skriptfehler).
- Offline und Hot-Seat bleiben bitgleich: `test_golden.gd` grün mit unveränderter Fixture.
- Ein Testlauf ist nur grün mit `ALL_TESTS_OK`, `FLOW_OK` **und** null `SCRIPT ERROR`.
- Alle neuen Spielertexte über `tr()` mit Englisch in `scripts/i18n.gd`. Kommentare Deutsch, Bezeichner Englisch.

## Nicht in diesem Plan

- Raumcode/Signaling über Supabase (nächster Plan).
- Abwesenheitsstufen §11, Host-Abbruch-Ende, Zugtimer-Hoheit online (eigener Plan).
- Android-Export, TURN.
- Mehr als ein Gast ist technisch vorbereitet (ein Code pro Gast), die Test-UI bietet in diesem Plan aber nur **Host + 1 Gast**, restliche Plätze KI.

## Review Focus

1. **Verbindung bricht ab:** Gast schließt den Tab mitten im Spiel. Der Host darf nicht abstürzen und muss weiterlaufen (Gast-Platz bleibt stehen, bis §11 kommt). → Test in Task 1 (ENet-Trennung) und Task 2.
2. **Online-Host sieht nie Gast-Karten:** Der Host-Tisch zeigt nur die Sicht des Host-Platzes, keine Hot-Seat-Übergabe online. → Test in Task 2.
3. **Kaputter oder fremder Code:** Abgeschnittener, doppelt eingefügter oder manipulierter Code ergibt eine verständliche Meldung, keinen Absturz. → Test in Task 3.
4. **Antwortcode zum falschen Angebot:** Gast-Antwort eines alten Angebots wird abgelehnt (Angebots-ID im Code). → Test in Task 3.
5. **Code-Länge:** Ein Code muss in WhatsApp/Signal als eine Nachricht passen (Ziel unter 1500 Zeichen). → Messung in Task 3 und Task 5.
6. **Feindliche Pakete über echtes Netz:** Übergroße oder kaputte Pakete eines Gasts werden verworfen, bevor sie dekodiert werden (Grenze 64 KB). → Test in Task 1.
7. **Host verlässt die Partie:** Der Gast bekommt eine Meldung und einen Weg zurück ins Menü statt eines eingefrorenen Tischs (Ende ohne Wertung, §11 schon entschieden). → Test in Task 2.

---

## Dateien

| Datei | Zweck |
|---|---|
| `godot/scripts/net/peer_link.gd` (neu) | `MultiplayerPeer` → `send/receive/my_id`, Signale `peer_connected/peer_disconnected` |
| `godot/scripts/net/rtc_code.gd` (neu) | Code kodieren/dekodieren (pur) |
| `godot/scripts/net/rtc_connector.gd` (neu) | WebRTC-Aufbau Host/Gast, liefert Codes und am Ende einen `PeerLink` |
| `godot/scripts/net/dame_host.gd` | `peer_left`/`remove_peer` an Link-Trennung anschließen (kleine Ergänzung) |
| `godot/scripts/table_view.gd` | Online-Host-Modus |
| `godot/scripts/screens/online_screen.gd` + `godot/scenes/online.tscn` (neu) | Test-UI: Hosten / Beitreten mit Codes |
| `godot/scripts/screens/main_menu.gd` | Menüpunkt „Online (Test)“ |
| `godot/addons/webrtc/` (neu) | `webrtc-native` für Windows x86_64 und Linux x86_64 |
| `godot/tests/test_peer_link.gd`, `test_rtc_code.gd`, `test_online_table.gd` (neu) | Headless-Tests |
| `e2e-godot/online-webrtc.spec.ts` (neu) | Zwei Browser-Seiten verbinden sich und spielen einen Zug |

---

### Task 1: PeerLink über MultiplayerPeer

**Interfaces:**
- Produces: `PeerLink.new(peer: MultiplayerPeer)`; `my_id() -> int`; `send(to: int, bytes: PackedByteArray)` (setzt `transfer_mode = TRANSFER_MODE_RELIABLE`, `set_target_peer(to)`, `put_packet`); `receive() -> Array` von `{from, bytes}` (ruft `peer.poll()`, liest bis `get_available_packet_count() == 0`, `from = get_packet_peer()`); Signale `peer_connected(id: int)`, `peer_disconnected(id: int)` (weitergereicht); `close()`.
- `DameHost`: im Konstruktor, wenn `link` die Signale hat, `peer_disconnected` → `remove_peer(id)`.
- Pflichtdetails (sicherheitsrelevant, gegen die 4.7-Doku prüfen):
  - **Reihenfolge:** `get_packet_peer()` liefert den Absender des *nächsten* Pakets, also **vor** `get_packet()` aufrufen. Falsche Reihenfolge ordnet Pakete dem falschen Peer und damit dem falschen Sitz zu.
  - **Kein SceneMultiplayer:** Den Peer nie `multiplayer.multiplayer_peer` zuweisen; SceneMultiplayer würde die Rohpakete verbrauchen. Nur `PeerLink` ruft `poll()`.
  - **Größengrenze:** Pakete über 64 KB vor dem Dekodieren verwerfen (Review Focus 6).
- Jede Warte-Schleife im Test hat eine harte Obergrenze; alle Peers vor `quit()` schließen (hängende Testprozesse gab es schon einmal).

- [ ] **Step 1: Test** `test_peer_link.gd` (zusätzlich: Paket > 64 KB vom Gast wird verworfen, kein Skriptfehler; Pakete zweier Gäste werden dem richtigen Absender zugeordnet): zwei `ENetMultiplayerPeer` im selben Prozess (Server auf freiem Port ab 24600, Client auf `127.0.0.1`), Poll-Schleife bis verbunden (max. 200 Iterationen, sonst klarer Fehler). Dann: `DameHost` mit Server-Link, `DameGuest` mit Client-Link, Hello/Welcome, Sitz zuweisen, eine Gast-Aktion, Sicht kommt an, `rev` steigt. Danach Client schließen → Host bekommt `peer_left` und läuft weiter (Review Focus 1).
- [ ] **Step 2: Rot. Step 3: Umsetzen. Step 4: Grün** (+ Golden). **Step 5: Commit** `feat(net): PeerLink ueber MultiplayerPeer`

Hinweis: ENet ist nur Testtransport, damit die Link-Schicht ohne WebRTC headless prüfbar ist. Gelingt ENet-Loopback headless nicht, sofort BLOCKED melden.

---

### Task 2: Online-Host-Tisch

**Interfaces:**
- Consumes: `PeerLink`, `DameHost(rules, link)`.
- Produces in `table_view.gd`: `var pending_online_host: Dictionary` (vor `add_child`): `{"config": Dictionary, "link": PeerLink, "host_seat": int, "guest_seats": {peer_id: seat}}`. Der Tisch startet die Regeln wie offline, baut `DameHost(r, link)`, setzt `local_seats = [host_seat]` (nicht alle Menschen), weist `HOST_PEER` → `host_seat` und jeden Gast-Peer → seinen Sitz zu. Kein Hot-Seat online, kein Speichern (Regel aus 1b: nur ohne Link), KI-Plätze laufen wie offline über `session.ai_step`.
- Gast-Sitze werden **erst bei `peer_joined`** zugewiesen (das kommt nach gültigem `hello` mit Versionsprüfung), nie beim Tischstart; nur Peer-IDs aus `guest_seats` werden angenommen.
- Übergabe im echten Spiel: `online.tscn` → Tisch läuft über `App.goto` + `take_pending`. Link/Session reisen im Pending-Job von `App` mit und werden beim Abholen gelöscht. Zwischen Bildschirm und Tisch darf niemand die Pakete des Peers abholen (der Tisch übernimmt das Pollen). `pending_online_host`/`pending_session` bleiben für Tests.
- Online-Verhalten, das in 1b zurückgestellt war und jetzt erreichbar wird:
  - **„Neues Spiel“ am Spielende:** online (Gast und Host mit Link) Verbindung schließen und zurück zum Online-Bildschirm, nie still ein Offline-Spiel starten.
  - **Pause-Menü:** online kein „Spiel wird gespeichert“, sondern „Hauptmenü (Verbindung wird getrennt)“.
  - **Doppelte Eingabe:** Gast-Eingaben sperren, solange ein Ergebnis aussteht (bis `action_result` oder neue Sicht).
  - **Host weg:** `peer_disconnected(1)` beim Gast → Meldung „Der Host hat die Partie verlassen. Die Partie endet ohne Wertung.“ + Knopf ins Menü (Review Focus 7).

- [ ] **Step 1: Test** `test_online_table.gd` (zusätzlich je ein Test für: Gast-Sitz erst nach `hello`, „Neues Spiel“ online, Pause-Text online, Eingabesperre beim Gast, Host-Trennung beim Gast): Host-Tisch (Online-Host-Modus) und Gast-Tisch (`pending_session` = `DameGuest`) im selben Prozess über ENet-Links, 3 Plätze (Host, Gast, KI). Beide Tische nur über die Eingabeschicht steuern (wie `test_table_net.gd`), Partie bis `game_over`. Prüfen: `host_table.is_hotseat() == false`; jede Sicht auf dem Host-Tisch hat `viewer_seat == host_seat` (Review Focus 2); keine Gesichter für unbekannte Karten auf beiden Tischen; kein Spielstand geschrieben; Gast trennt sich mitten im Spiel → Host-Tisch läuft weiter, kein `SCRIPT ERROR`.
- [ ] **Step 2: Rot. Step 3: Umsetzen. Step 4: Grün** (+ Golden). **Step 5: Commit** `feat(table): Online-Host-Modus`

---

### Task 3: Verbindungscode (pur)

**Interfaces:**
- Produces `RtcCode` (static): `encode(kind: String, offer_id: String, sdp: String, candidates: Array) -> String` und `decode(code: String) -> Dictionary` (`{"ok": bool, "error": String, "kind", "offer_id", "sdp", "candidates"}`). `kind` ist `"offer"` oder `"answer"`. Format: `var_to_bytes({"v": 1, ...})` → `compress(COMPRESSION_DEFLATE)` → Base64 URL-sicher (`+`→`-`, `/`→`_`, ohne `=`), Präfix `DAME1-`. Dekodieren entfernt Leerzeichen/Zeilenumbrüche, prüft Präfix, Version, Typen, Größen (dekomprimiert max. 64 KB), nie `bytes_to_var_with_objects`.
- Fehlertexte (deutsch, über `tr()` mit Englisch): „Code unvollständig oder beschädigt.“, „Code von einer anderen Spielversion.“, „Das ist ein Antwortcode, kein Einladungscode.“ (und umgekehrt), „Dieser Antwortcode gehört zu einer anderen Einladung.“

- [ ] **Step 1: Test** `test_rtc_code.gd`: Rundreise mit realistischem SDP (feste Beispiel-SDP aus Chrome, ~1 KB, als Konstante im Test) plus 4 Kandidaten; Länge < 1500 Zeichen (Review Focus 5); abgeschnitten, ein Zeichen geändert, doppelt eingefügt, leer, falsches Präfix, Version 2, falscher `kind`, gigantischer Code → jeweils `ok == false` mit passendem Fehlertext und null `SCRIPT ERROR` (Review Focus 3); Zeilenumbrüche im Code werden toleriert.
- [ ] **Step 2: Rot. Step 3: Umsetzen. Step 4: Grün. Step 5: Commit** `feat(net): Verbindungscode fuer WebRTC`

---

### Task 4: webrtc-native einbinden

- [ ] **Step 1:** Release `1.2.1-stable` von https://github.com/godotengine/webrtc-native/releases laden (Datei `godot-extension-4.1-webrtc.zip` bzw. die im Release für Godot 4.3+ ausgewiesene Datei), in eigenes leeres Verzeichnis entpacken, Lizenz prüfen (MIT). Nur Windows x86_64 und Linux x86_64 nach `godot/addons/webrtc/` übernehmen (plus `.gdextension`, Lizenzdatei). Größe notieren.
- [ ] **Step 2:** Prüfen, dass Headless-Godot unter Windows die Erweiterung lädt: kleines Testskript erzeugt `WebRTCPeerConnection.new()` und `initialize({})` liefert `OK`.
- [ ] **Step 3:** Export-Presets: Windows-Export enthält die DLL (Export laufen lassen, `build/windows/` prüfen); Web-Export enthält sie **nicht** (Browser hat WebRTC eingebaut; Größe des Web-Builds darf nicht steigen).
- [ ] **Step 4:** CI (`.github/workflows/deploy.yml`) läuft unter Linux: sicherstellen, dass die Godot-Tests dort die Linux-Bibliothek laden (oder die WebRTC-Tests ohne Erweiterung sauber überspringen, mit sichtbarem Hinweis statt stillem Grün).
- [ ] **Step 5: Commit** `chore: webrtc-native 1.2.1 fuer Windows und Linux` (Lizenz in `godot/addons/webrtc/` und Hinweis in `README.md`/Credits, falls dort Lizenzen gelistet sind).

---

### Task 5: RtcConnector (Host und Gast)

**Interfaces:**
- Consumes: `RtcCode`, `PeerLink`.
- Produces `RtcConnector` (RefCounted, mit `poll()` vom Bildschirm aufgerufen):
  - Host: `start_host() -> void` (erstellt `WebRTCMultiplayerPeer.create_server()`), `create_invite(guest_peer_id: int) -> void` → Signal `invite_ready(code: String)` sobald ICE-Sammlung fertig; `accept_answer(code: String) -> Dictionary` (`{ok, error}`).
  - Gast: `join(code: String) -> Dictionary` (`create_client(guest_peer_id aus dem Code)`), Signal `answer_ready(code: String)`.
  - Beide: Signal `connected(link: PeerLink)`, Signal `failed(reason: String)`, `close()`.
  - Die Gast-Peer-ID wird vom Host vergeben (2, 3, …) und steht im Einladungscode.
  - ICE: `initialize({"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]})`. Sammlung fertig = `get_gathering_state() == GATHERING_STATE_COMPLETE` (in 4.7 prüfen); falls nicht verfügbar: nach letztem `ice_candidate_created` 1,5 s Ruhe, höchstens 8 s.
  - `close()` schließt Peer-Verbindungen und den `WebRTCMultiplayerPeer`; Tests rufen es immer vor `quit()` (native WebRTC-Threads können Headless-Godot sonst am Leben halten).
  - Zeitlimit Verbindungsaufbau 30 s → `failed("Verbindung nicht zustande gekommen. Seid ihr beide online?")`.

- [ ] **Step 1: Test** `test_rtc_connector.gd` (läuft nur, wenn webrtc-native geladen ist; sonst ein sichtbarer Hinweis-Check, kein stilles Grün): Host und Gast im selben Prozess, Codes per Variable austauschen, Verbindung über Localhost-Kandidaten, danach über die beiden `PeerLink`s ein Hello/Welcome. Code-Längen messen und ins Protokoll schreiben (Review Focus 5). Antwortcode an eine zweite, neuere Einladung → `ok == false` (Review Focus 4).
- [ ] **Step 2: Rot. Step 3: Umsetzen. Step 4: Grün. Step 5: Commit** `feat(net): WebRTC-Verbindungsaufbau mit Codes`

---

### Task 6: Test-UI „Online (Test)“

**Interfaces:** Consumes `RtcConnector`, Online-Host-Modus (`pending_online_host`), Gast-Tisch (`pending_session`).

- Hauptmenü: Knopf „Online (Test)“ → `online.tscn`.
- **Hosten:** Spieleranzahl 2–4 (Host + 1 Gast, Rest KI), „Einladung erstellen“ → Code in Textfeld + „Kopieren“ (`DisplayServer.clipboard_set`). Feld „Antwortcode einfügen“ + „Verbinden“. Bei `connected`: Tisch im Online-Host-Modus starten.
- **Beitreten:** Feld „Einladungscode einfügen“ + „Weiter“ → Antwortcode + „Kopieren“. Bei `connected` und erster Sicht: Tisch als Gast starten.
- Alle Fehler aus `RtcCode`/`RtcConnector` als Text unter dem Feld, nie Absturz. Casino-Look wie die anderen Menüs (`ui_theme.gd`).
- Web-Test-Brücke: nur wenn die URL `?e2e=1` enthält, registriert der Bildschirm über `JavaScriptBridge` die Funktionen `dameHostInvite()`, `dameGuestJoin(code)`, `dameHostAccept(code)` und schreibt Statuszeilen `ONLINE_INVITE <code>`, `ONLINE_ANSWER <code>`, `ONLINE_CONNECTED`, `ONLINE_TABLE seat=<n>` in die Konsole.

- [ ] **Step 1: Test** (headless, Szene): Bildschirm lädt, kaputter Code im Beitreten-Feld zeigt Fehlertext, Knöpfe bleiben bedienbar; Texte DE/EN vorhanden.
- [ ] **Step 2: Rot. Step 3: Umsetzen. Step 4: Grün. Step 5: Commit** `feat(ui): Online-Testbildschirm mit Verbindungscodes`

---

### Task 7: Browser-Test mit zwei Seiten

- [ ] **Step 1:** `e2e-godot/online-webrtc.spec.ts`: Web-Build, zwei Seiten im selben Browser-Kontext (`/?e2e=1`). Seite A ruft `dameHostInvite()`, Test liest `ONLINE_INVITE` aus der Konsole, ruft auf Seite B `dameGuestJoin(code)`, liest `ONLINE_ANSWER`, ruft auf A `dameHostAccept(answer)`. Erwartet auf beiden `ONLINE_CONNECTED` und `ONLINE_TABLE seat=0` (A) bzw. `seat=1` (B) innerhalb von 60 s. Danach ein Zug: Ist B am Zug, Leertaste auf B (Ziehen), sonst auf A; die andere Seite muss die neue Sicht melden (Konsolenzeile `ONLINE_VIEW rev=<n>` im E2E-Modus).
- [ ] Hinweise: Chrome ersetzt lokale IPs durch mDNS-`.local`-Kandidaten. Verbinden sich die Seiten nicht, Startflag `--disable-features=WebRtcHideLocalIpsWithMdns` nur für diesen Test setzen. Zwei 3D-Instanzen unter SwiftShader sind langsam: eigenes, großzügiges Timeout für diesen Test.
- [ ] Dieser Test kommt **nicht** in den CI-Pfad, der das Deployment auslöst, bis er sich mehrfach stabil gezeigt hat (jeder Push auf `main` geht live).
- [ ] **Step 2:** `npm run export:godot` und `npm run test:godot:web` lokal grün (bestehende Web-Tests eingeschlossen).
- [ ] **Step 3: Commit** `test(e2e): zwei Browser verbinden sich per WebRTC`

---

### Task 8: Abschluss

- [ ] `npm run test:godot` (ALL_TESTS_OK + FLOW_OK + null SCRIPT ERROR) und `npm run test:godot:web` grün.
- [ ] **Offener Punkt vor Task 8 (Nutzer entscheidet):** Wie kommt das zweite Gerät an den Branch-Build? Pages baut nur `main`. Optionen: Windows-Build auf beiden Rechnern; Handy im WLAN über den lokalen Server (unsichere Herkunft: Kopieren/Einfügen kann dort eingeschränkt sein, früh prüfen). Klappt Einfügen in Godots Textfeld im Handy-Browser nicht zuverlässig, wird die Einladung ein Link mit dem Code im URL-Fragment (geht nie an einen Server), und nur der Antwortcode wird kopiert.
- [ ] Mindestens ein Test mit dem Gast im **Mobilfunknetz** (nicht im selben WLAN), sonst wird STUN/NAT nie geprüft.
- [ ] Von Hand (Nutzer): Windows-Build auf einem Rechner hostet, Handy/zweiter Rechner tritt im Browser bei, eine Runde spielen. Ergebnis und Code-Längen in `docs/online-p2p-plan.md` festhalten (auch: Verbindung klappte / klappte nicht, welches Netz).
- [ ] Doku: `docs/online-p2p-plan.md` Schritte 2 (Link-Adapter) und 4 (webrtc-native) abhaken; `.claude/skills/dame-godot/references/architecture.md` um PeerLink/RtcConnector ergänzen; Datenschutzhinweis in der UI-Hilfe: „Der Code enthält deine IP-Adresse. Teile ihn nur mit Leuten, mit denen du spielen willst.“
- [ ] Commit `docs: Online-Verbindung per WebRTC (Codes)`

---

## Weg bis „Freunde können spielen“ (Stand nach diesem Plan)

1. ✅ 1b Tisch aus der Sicht (PR #14).
2. Dieser Plan: echte Verbindung, Codes per Copy-Paste, Online-Host-Tisch.
3. Raumcode über Supabase Realtime (Codes werden automatisch ausgetauscht), Copy-Paste bleibt Fallback.
4. Lobby-UI für mehr als einen Gast, Namen, Plätze.
5. §11: Abwesenheit, KI übernimmt, Host-Abbruch beendet ohne Wertung, Zugtimer beim Host.
