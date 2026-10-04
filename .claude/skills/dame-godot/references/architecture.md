---
description: "Scene boundary, autoload, and hidden-info projection for DAME. Read before creating nodes."
connections: [rules, ui, gdscript-45]
---

# Architecture

The web split was `gameLogic.ts` (pure) / `aiPlayer.ts` (pure) / `useGameEngine.ts` (React). Keep that cut.

## Call down, signal up

Parent calls child methods. Child emits. Rules never emit. A `DameTable` node owns one `DameRules` instance and is the only writer.

```
DameTable (Node)
  calls DameRules.draw_from_deck(state, actor_id)
  builds DameView.for_viewer(state, viewer_id)
  pushes view into seat widgets
Seat emits slot_pressed(index)
DameTable validates, then calls rules
```

No autoload for state. An autoload may hold audio bus names only. State in an autoload leaks across tests.

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
