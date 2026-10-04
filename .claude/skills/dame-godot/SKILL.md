---
name: dame-godot
description: "Port and build DAME, the hidden-hand memory card game, in the Godot 4.5 stub at godot/. Use when implementing table.tscn, Dame rules, card zones, peek memory, Dame-call, AI, phosphor UI, or headless rule tests. Not for the React app, not for generic Godot 3D, platformers, or unrelated engines."
type: workflow
lifecycle: active
---

# DAME Godot — Port Contract

Build the playable Godot client of DAME inside `godot/`. The React tree is the rules oracle, not the runtime. Godot 4.5, GL Compatibility, main scene `res://scenes/table.tscn`, 1280×720.

Read `references/rules.md` before any rule code. Read `references/architecture.md` before any scene. Read `references/ui.md` only for presentation. Read `references/gdscript-45.md` when an API call fails or a 4.7 snippet appears.

## Hard stops

1. Do not invent MTG phases, mana, or a stack. Phases are `SETUP`, `FIRST_TURN`, `REGULAR_PLAY`, `DAME_CALLED`, `ROUND_END`, `GAME_OVER`.
2. Do not treat `is_visible` as knowledge. Knowledge is a per-player memory map. Human UI and AI may read only own memory plus public discard top.
3. A card id exists in exactly one zone: deck, a hand slot, discard, or that player's penalty pile. Move is remove-then-add. Assert after every mutation.
4. Queen the card (`Q`, 0 points) is not the Dame call. Never merge them.
5. User-facing strings and `last_action` stay German. Identifiers stay English.
6. Rules live in a `RefCounted` with no `Node`, no `get_tree()`, no `await`. UI only projects a public view.
7. Do not copy Godot 4.7-only APIs. This project is `config/features=PackedStringArray("4.5", "GL Compatibility")`.
8. Do not mutate a shared `CardData` resource in a hand. `duplicate(true)` per instance.

## Build order

1. Read `godot/project.godot`. If features are not 4.5, stop and report the version.
2. Add `res://scripts/rules/` with pure state transitions matching `references/rules.md`. No scenes yet.
3. Add headless tests that fail if a card is in two zones, if AI reads a foreign hand, or if a wrong Dame call does not add a penalty card.
4. Add `res://scenes/table.tscn` as view only: deck, discard, seats, four-slot hands. It calls rules, it does not contain them.
5. Wire input to the existing web keys: `1-4` select slot, `Space` draw, `Enter` confirm, `D` Dame, `Z`/`E` undo peek, `Esc` cancel. Focus must survive a redraw.
6. AI runs on the same rules object with a memory projection. Difficulty changes policy, not visibility.
7. Theme last: black field, green phosphor, no Forward+ glow. GL Compatibility only.

## File map

| Path | Owns |
|---|---|
| `scripts/rules/dame_state.gd` | State, zones, ids |
| `scripts/rules/dame_rules.gd` | Transitions. One function per oracle export |
| `scripts/rules/dame_view.gd` | Public projection for a viewer id |
| `scripts/ai/dame_policy.gd` | Easy / medium / hard. Reads a view, returns an action |
| `scenes/table.tscn` | Layout and signal bindings |
| `scenes/card_slot.tscn` | One slot. Face from view, never from raw state |

## Knowledge graph

Start at `references/INDEX.md`.

- [[rules]] — oracle transitions and illegal moves
- [[architecture]] — call down, signal up, test boundary
- [[ui]] — hand, focus, phosphor, hidden faces
- [[gdscript-45]] — 4.5 traps that break this port
