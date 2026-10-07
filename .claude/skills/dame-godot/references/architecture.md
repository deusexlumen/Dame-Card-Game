---
description: "Scene boundary, autoload, and hidden-info projection for DAME. Read before creating nodes."
connections: [rules, ui, gdscript-47]
---

# Architecture

The web split was `gameLogic.ts` (pure) / `aiPlayer.ts` (pure) / `useGameEngine.ts` (React). Keep that cut.

## Call down, signal up

Parent calls child methods. Child emits. Rules never emit. A `DameTable` node reads only its own `DameView` and writes only through a session (`DameHost` or `DameGuest`).

```
DameTable (Node)
  reads its own DameView (updated by session)
  receives action_result signal
  emits seat input → session
DameHost/DameGuest (session)
  holds/calls DameRules (Host only)
  sends view with each action
  writes to table via signal
```

## Session

`DameHost` führt die Spielregeln aus, gilt als Autorität und ist der einzige Schreiber von `DameRules`. Sie empfängt Aktionen, führt sie durch, berechnet die neue `DameView` für alle und sendet sie. `DameGuest` sendet Aktionen und empfängt nur Sichten — keine `DameRules`-Instanz, kein Save, kein Zugtimer, kein Auslöser für nächste Runde. Hot-Seat wechselt `HOST_PEER` nur in `confirm_handoff`. Auf dem Tisch ist `rules` bei Gästen `null`. Tests: `test_golden` (bitgenau offline), `test_net` (Online), `test_table_net` (Tisch-Netzwerk-Interaktion).

### Transport (scripts/net/)

`DameHost`/`DameGuest` kennen nur einen Link mit `send(to, bytes)`, `receive()`, `my_id()`. Tests nutzen den Loopback-Link, echtes Netz den `PeerLink`.

- `peer_link.gd` (`PeerLink`): macht aus jedem `MultiplayerPeer` (WebRTC, in Tests ENet) diesen Link. Pakete über 64 KB werden vor dem Dekodieren verworfen. Signale `peer_connected`/`peer_disconnected`; der Host hängt `remove_peer` an die Trennung.
- `rtc_code.gd` (`RtcCode`, pur): Angebot/Antwort + ICE-Kandidaten als ein komprimierter, URL-sicherer Code mit Version und Angebots-ID. Kaputte oder fremde Codes liefern `{ok=false, error}`, nie einen Skriptfehler.
- `rtc_connector.gd` (`RtcConnector`): baut WebRTC nicht-trickelnd auf (Code erst, wenn alle Kandidaten da sind). Host: `start_host`, `create_invite`, `accept_answer`. Gast: `join`. Am Ende Signal `connected(link)`. `is_available()` ist false ohne WebRTC (Desktop ohne `webrtc-native`).
- `webrtc-native` 1.2.2 kommt per `scripts/fetch-webrtc.mjs` nach `godot/addons/webrtc/` (nicht im Repo). Im Web ist WebRTC eingebaut.
- Test-UI: `scenes/online.tscn` (Menü „Online (Test)“), Host + 1 Gast, Rest KI. Browser-Test: `npm run test:godot:online` (nicht im Deploy-Pfad).

No autoload for match state. The autoload `App` holds only services (settings, stats, profile, saves, audio) and scene switching. Match state in an autoload leaks across tests.

## Projection

`DameView.for_viewer` returns:

- discard top, always
- own hand slots with rank only if memory contains them
- opponent slots as count plus any card this viewer has peeked
- deck count, not deck order
- scores, phase, German `last_action`

The table scene for a hot-seat human must swap viewer id when the seat changes, and clear the previous projection before the next seat draws. Do not leave the last player's ranks on screen.

AI receives the same view factory. If a policy function signature accepts `GameState`, the test is wrong. It must accept `DameView`.

## Scenes

The visible table is the first-person 3D renderer in `scripts/table3d/` (see [[ui]]). The tree below describes the hidden 2D seat proxies that still own focus and tests.


`project.godot` already points at `res://scenes/table.tscn`. Create that file. Do not change the main scene path.

Suggested tree:

```
Table (Control, full rect)
  Background
  DiscardSlot
  DeckSlot
  Seats (GridContainer or anchors)
    Seat (instance)
      Name
      Score
      Hand (HBoxContainer, 4 CardSlot)
  ActionBar
  Log
```

Card faces are children of `CardSlot`, instanced from a packed scene. Rules do not preload textures.

## Tests

Headless: `DameRules` only, no `SubViewport`. One test file per oracle function group: deal, draw/reshuffle, powers, dame call, score cut. Compare outcomes to a fixture copied from the Vitest names, not to a rewritten rule.
