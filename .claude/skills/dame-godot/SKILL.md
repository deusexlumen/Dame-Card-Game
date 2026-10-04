---
name: dame-godot
description: "Build DAME, the hidden-hand memory card game, in the Godot 4.7 project at godot/. Use when implementing table.tscn, Dame rules, card zones, peek memory, Dame-call, AI, menus, shop, phosphor UI, export, or headless rule tests. Not for the React app, not for generic Godot 3D, platformers, or unrelated engines."
type: workflow
lifecycle: active
---

# DAME Godot — Port Contract

Build the playable Godot client of DAME inside `godot/`. Godot is the main project. The React tree is reference only, not the runtime and not the rules authority. Godot 4.7, GL Compatibility, main scene `res://scenes/main_menu.tscn` (table: `res://scenes/table.tscn`), 1280×720.

Read `references/rules.md` before any rule code. Read `references/architecture.md` before any scene. Read `references/ui.md` only for presentation. Read `references/gdscript-47.md` when an API call fails.

## Hard stops

1. Do not invent MTG phases, mana, or a stack. Rules phases are `play`, `dame_called`, `round_end`, `game_over`; turn steps `draw`, `play`, `jack`, `king`.
2. Do not treat `face_up` as knowledge. Knowledge is a per-player memory. Human UI and AI may read only their own memory plus the public discard top.
3. A card id exists in exactly one zone: deck, a hand slot, discard, drawn card, or a penalty pile. Move is remove-then-add. Tests assert zones after every mutation.
4. Queen the card (`Q`, 0 points) is not the Dame call. Never merge them.
5. User-facing strings and `last_action` stay German. Identifiers stay English.
6. Rules live in a `RefCounted` with no `Node`, no `get_tree()`, no `await`. UI only projects a public view.
7. Engine is Godot 4.7.2. `config/features=PackedStringArray("4.7", "GL Compatibility")`. Do not switch renderer.
8. Rules source is the existing Godot code plus `CONCEPT_DECISIONS.md`. Jack: peek any face-down card. King: peek own card, then blind swap with opponent. Ace and Ten: no effect.
9. No real-money purchase code. Only the `PurchaseProvider` stub. No multiplayer.

## Build order

1. Read `godot/project.godot`. If features are not 4.7, stop and report the version.
2. Follow the milestone plan in `docs/superpowers/plans/2026-10-04-dame-godot-bauplan.md`.
3. Run `npm run test:godot` before every commit.

## File map

| Path | Owns |
|---|---|
| `scripts/dame_rules.gd` | State, zones, transitions (`DameRules`, RefCounted) |
| `scripts/dame_view.gd` | Public projection for a viewer seat |
| `scripts/dame_policy.gd` | Easy / medium / hard. Reads a view, returns an action |
| `scripts/dame_ai.gd` | Drives one AI turn via view + policy |
| `scenes/table.tscn` + `scripts/table_view.gd` | Table layout and input |
| `scenes/card_slot.tscn` | One slot. Face from view, never from raw state |
| `scripts/app.gd` (autoload `App`) | Services and scene switching. No game state |
| `tests/run_all.gd` | Headless test entry |

## Knowledge graph

Start at `references/INDEX.md`.

- [[rules]] — transitions and illegal moves
- [[architecture]] — call down, signal up, test boundary
- [[ui]] — hand, focus, phosphor, hidden faces
- [[gdscript-47]] — engine traps that break this port
