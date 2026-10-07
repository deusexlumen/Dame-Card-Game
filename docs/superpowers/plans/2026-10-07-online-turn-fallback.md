# Online: TURN als Rückfall (Cloudflare) — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Vor jeder Godot-Arbeit Skill `dame-godot` laden.

**Goal:** Verbindungen, die ohne Weiterleitung scheitern (strenge NAT, Mobilfunk), laufen über einen TURN-Server von Cloudflare, ohne eigenen Server und im kostenlosen Rahmen.

**Architecture:** Eine kleine Supabase Edge Function hält den Cloudflare-TURN-Schlüssel als Secret und gibt nur kurzlebige Zugangsdaten (12 h) heraus. Das Spiel holt sie vor jeder Einladung bzw. jedem Beitritt mit einem pollbaren `IceFetcher` (HTTPClient, 4 s Zeitlimit) und hängt sie an die STUN-Liste. Scheitert das Holen oder ist keine URL eingetragen, läuft alles wie bisher nur mit STUN. `RtcConnector` bekommt nur die Liste (`ice_config`) und kürzt Kandidaten so, dass `relay` und `srflx` nie wegfallen.

**Tech Stack:** Godot 4.7.2 (`HTTPClient`, `JSON`, `WebRTCPeerConnection`), Supabase Edge Functions (Deno), Cloudflare Realtime TURN (1.000 GB/Monat gratis, danach $0.05/GB; Quelle: developers.cloudflare.com/realtime/turn/faq).

**Spec:** `docs/online-p2p-plan.md` (Risiko 2 „Kein TURN“), Plan `2026-10-07-online-2-webrtc-verbindung.md`.

## Global Constraints

- Kein Secret im Repo und nie im Spiel. Der Cloudflare-Schlüssel liegt nur als Supabase-Secret (`CF_TURN_KEY_ID`, `CF_TURN_API_TOKEN`).
- Rückfall immer: Ohne URL, bei Zeitlimit (4000 ms), HTTP-Fehler oder Müll-Antwort läuft die Verbindung mit `stun:stun.l.google.com:19302` wie heute. Nie ein Skriptfehler.
- Zugangsdaten-TTL 43200 s (12 h, Cloudflare erlaubt bis 48 h; lange Abende sollen nicht mittendrin abbrechen).
- Höchstens 3 TURN-URLs, je eine Art in dieser Rangfolge: `turn:` UDP, `turn:` TCP, `turns:` Port 443 (kommt durch strenge Firewalls, darf nie wegfallen). Keine auf Port 53. Code bleibt unter 1500 Zeichen (in Task 3 neu messen; wird es knapp, nur ein relay-Kandidat je Art).
- Antwortform (Cloudflare-Doku, wörtlich): `{"iceServers": [{"urls": ["stun:…"]}, {"urls": ["turn:turn.cloudflare.com:3478?transport=udp", "turn:…:443?transport=udp", "turn:…:3478?transport=tcp", "turn:…:80?transport=tcp", "turns:…:5349?transport=tcp", "turns:…:443?transport=tcp"], "username": "<96 hex>", "credential": "<96 hex>"}]}`. `parse_turn` nimmt auch ein einzelnes Objekt statt Array.
- Offline und Hot-Seat bleiben bitgleich: `test_golden.gd` grün, Fixture unverändert.
- Ein Testlauf ist nur grün mit `ALL_TESTS_OK`, `FLOW_OK` **und** null `SCRIPT ERROR`.
- Neue Spielertexte über `tr()`/Konstanten mit Englisch in `scripts/i18n.gd`. Kommentare Deutsch, Bezeichner Englisch.

## Review Focus

1. **Dienst antwortet nie oder langsam:** Einladung kommt trotzdem, spätestens nach 4 s + ICE-Sammlung. → Test in Task 2 (Zeitlimit) und Task 3.
2. **Feindliche/kaputte Antwort:** HTML-Fehlerseite, riesiger Body, falsche Typen, `javascript:`-URL. → nur STUN, kein Absturz. Test in Task 1 und Task 2.
3. **TURN-Kandidat fällt beim Kürzen weg:** Bei mehr als `MAX_CANDIDATES` Kandidaten bleiben `relay` und `srflx`. → Test in Task 1.
4. **Abbrechen während des Holens:** Gast bricht ab oder verlässt den Bildschirm, der wartende Beitritt darf danach nicht mehr starten. → Test in Task 3.
5. **Doppelklick während des Holens:** Kein zweiter Abruf, keine zwei Einladungen. → Test in Task 3.

---

## Dateien

| Datei | Zweck |
|---|---|
| `godot/scripts/net/ice_servers.gd` (neu) | Pur: Standard-Konfig, TURN-Antwort prüfen, Konfig bauen, Kandidaten kürzen |
| `godot/scripts/net/ice_fetcher.gd` (neu) | Pollbarer HTTPS-Abruf der Zugangsdaten mit Zeitlimit |
| `godot/scripts/net/net_config.gd` (neu) | `TURN_URL` (öffentlich, leer = aus) |
| `godot/scripts/net/rtc_connector.gd` | Standard aus `IceServers`, Kürzen über `limit_candidates` |
| `godot/scripts/screens/online_screen.gd` | Vor Einladung/Beitritt Zugangsdaten holen |
| `godot/scripts/i18n.gd` | Text „Verbindung wird vorbereitet …“ |
| `supabase/functions/turn-credentials/index.ts` (neu) | Edge Function |
| `godot/tests/test_ice_servers.gd`, `test_ice_fetcher.gd` (neu) | Headless-Tests |

---

### Task 1: IceServers (pur) und Kandidaten-Kürzung

**Files:** Create `godot/scripts/net/ice_servers.gd`, `godot/tests/test_ice_servers.gd`; Modify `godot/scripts/net/rtc_connector.gd` (ICE_CONFIG, `_check_gathering`), `godot/tests/run_all.gd` (Suite).

**Interfaces (Produces):**
- `IceServers.default_config() -> Dictionary` = `{"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]}`
- `IceServers.parse_turn(text: String) -> Array` — TURN-Einträge `{urls: Array[String], username, credential}`, `[]` bei allem Unerwarteten
- `IceServers.build_config(turn: Array) -> Dictionary` — Standard + TURN
- `IceServers.limit_candidates(cands: Array, max_count: int) -> Array` — Originalreihenfolge, `relay` dann `srflx` zuerst ausgewählt
- Konstanten `MAX_RESPONSE := 16384`, `MAX_TURN_URLS := 3`

- [ ] **Step 1: Failing test** `test_ice_servers.gd`: Cloudflare-Beispielantwort (wörtlich aus Global Constraints, plus eine `:53`-URL) → genau 3 URLs: `turn:…:3478?transport=udp`, `turn:…:3478?transport=tcp`, `turns:…:443?transport=tcp`; keine `:53`, Zugangsdaten übernommen; STUN-Eintrag fällt weg. Müll: `""`, `"<html>"`, `"[]"`, `{"iceServers": 5}`, `urls` als Zahl, `username` als Zahl, leeres `credential`, `javascript:alert(1)`, Body über 16384 Zeichen → `[]`. `urls` als String wird akzeptiert. `build_config([])` == `default_config()`. `limit_candidates`: 34 Kandidaten (32 host, dann 1 srflx, 1 relay) mit max 32 → 32 lang, enthält relay und srflx, Reihenfolge wie im Original; unter max unverändert.
- [ ] **Step 2:** `npm run test:godot` → FAIL (Suite nicht ladbar).
- [ ] **Step 3:** Implementieren (siehe Interfaces). `rtc_connector.gd`: `var ice_config: Dictionary = IceServers.default_config()`, `ICE_CONFIG` entfernen, in `_check_gathering` `cands = IceServers.limit_candidates(cands, RtcCode.MAX_CANDIDATES)`.
- [ ] **Step 4:** `npm run test:godot` → ALL_TESTS_OK, FLOW_OK, 0 SCRIPT ERROR.
- [ ] **Step 5: Commit** `feat(net): ICE-Server-Liste mit TURN, Kandidaten behalten relay`

### Task 2: IceFetcher

**Files:** Create `godot/scripts/net/ice_fetcher.gd`, `godot/scripts/net/net_config.gd`, `godot/tests/test_ice_fetcher.gd`; Modify `run_all.gd`.

**Interfaces (Produces):** `IceFetcher.new()`, `start(url: String)`, `poll()`, `is_done() -> bool`, `config: Dictionary` (immer gültig, Standard bis Erfolg), `has_turn: bool`, `close()`, `var timeout_ms := 4000`. `NetConfig.TURN_URL := ""`.

- [ ] **Step 1: Failing test** mit lokalem `TCPServer` auf 127.0.0.1 (freier Port), der synchron im Poll-Schleifchen eine HTTP-Antwort schreibt:
  - 200 + gültiges JSON → `has_turn`, `config.iceServers.size() == 2`.
  - 500 → Standard, `has_turn == false`.
  - 200 + Body größer `MAX_RESPONSE` → Standard.
  - Server nimmt an, antwortet nie, `timeout_ms = 300` → nach ≤ 1 s fertig, Standard.
  - Leere URL, `ftp://x`, `https://` ohne Host → sofort `is_done()`, Standard.
  - Kein Server auf dem Port → fertig, Standard.
- [ ] **Step 2:** FAIL. **Step 3:** Implementieren mit `HTTPClient` (`connect_to_host`, `TLSOptions.client()` bei https, `request(GET)`, Body in Stücken, Abbruch über `MAX_RESPONSE`), Ergebnis über `IceServers.parse_turn`/`build_config`. **Step 4:** grün.
- [ ] **Step 5: Commit** `feat(net): TURN-Zugangsdaten abrufen mit Zeitlimit`

### Task 3: Online-Bildschirm holt Zugangsdaten

**Files:** Modify `godot/scripts/screens/online_screen.gd`, `godot/scripts/i18n.gd`, `godot/tests/test_online_screen.gd`.

**Interfaces (Consumes):** `IceFetcher`, `NetConfig.TURN_URL`. **Produces:** `var turn_url: String = NetConfig.TURN_URL` (vor `add_child` setzbar), Text `PREPARING_TEXT := "Verbindung wird vorbereitet …"`.

Verhalten: Ist `ice_config` leer und `turn_url` gesetzt, startet `host_invite()`/`guest_join(text)` zuerst den Abruf, zeigt `PREPARING_TEXT` und merkt sich die Aktion. Weitere Klicks währenddessen tun nichts. Ist der Abruf fertig (in `poll_net`), läuft die Aktion mit `fetcher.config` als `ice_config` des Connectors. `guest_cancel()` und das Verlassen verwerfen Abruf und gemerkte Aktion. Tests setzen `ice_config` und laufen unverändert.

- [ ] **Step 1: Failing tests:** (a) `turn_url` auf toten lokalen Port, `ice_config` leer: `host_invite()` → Status `PREPARING_TEXT`; zweiter Klick startet keinen zweiten Abruf; nach Pumpen Status `MAKING_INVITE_TEXT`, Connector hat Standard-Konfig. (b) Gast: `guest_join(code)` mit Abruf, dann `guest_cancel()` → nach Pumpen kein Connector, Status leer. (c) Text in `TEXTS`, Englisch vorhanden.
- [ ] **Step 2:** FAIL. **Step 3:** Implementieren. **Step 4:** grün, Web-Tests `npm run export:godot && npm run test:godot:web && npm run test:godot:online` grün.
- [ ] **Step 5: Commit** `feat(ui): Online holt TURN-Zugangsdaten vor dem Verbinden`

### Task 4: Edge Function und Doku

**Files:** Create `supabase/functions/turn-credentials/index.ts`; Modify `docs/online-p2p-plan.md`, `.claude/skills/dame-godot/references/architecture.md`.

- [ ] Function: `OPTIONS` → CORS; nur `GET`; fehlen Secrets → 503; `POST https://rtc.live.cloudflare.com/v1/turn/keys/$CF_TURN_KEY_ID/credentials/generate-ice-servers` mit `Bearer $CF_TURN_API_TOKEN`, Body `{"ttl": 43200}`; Antwort nur Einträge mit `username`, `Cache-Control: no-store`; Upstream-Fehler → 502 ohne Details.
- [ ] Doku: Einrichtung (Nutzer): Cloudflare → Realtime → TURN-Schlüssel anlegen; `supabase secrets set CF_TURN_KEY_ID=… CF_TURN_API_TOKEN=…`; `supabase functions deploy turn-credentials --no-verify-jwt`; URL in `NetConfig.TURN_URL`. Risiko: Die URL ist öffentlich, jeder kann Zugangsdaten holen und Kontingent verbrauchen. Vor Live-Gang klären, was Cloudflare bei Überschreitung tut (Zahlungsart hinterlegt?).
- [ ] **Commit** `feat(online): Supabase-Funktion fuer TURN-Zugangsdaten`

### Task 5 (Nutzer, von Hand)

- [ ] Schlüssel anlegen, Funktion deployen, URL eintragen.
- [ ] Beweis, dass TURN trägt: `test:godot:online` einmal mit erzwungenem Relay (`iceTransportPolicy: "relay"`, nur Browser) gegen die echte Funktion. Verbindet es sich, ist TURN bewiesen. Hinweis: `webrtc-native` (libdatachannel) kann TURN evtl. nur über UDP; ein weiterleitender Browser-Gast auf 443 reicht meist.
- [ ] Test Gast im **Mobilfunknetz**, Host im WLAN. In `docs/online-p2p-plan.md` festhalten: Netz, Anbieter, verbunden ja/nein, über TURN ja/nein.
