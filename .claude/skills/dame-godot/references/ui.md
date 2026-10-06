---
description: "DAME table UI: first-person 3D table, hand rig, casino theme, effects, keys on GL Compatibility. Read only for presentation."
connections: [architecture, rules]
---

# UI

Presentation only. If a button computes a score, move it to [[rules]].

## 3D table

`table_view.gd` puts `Table3D` (`scripts/table3d/table_3d.gd`) in a `SubViewportContainer` behind the HUD. It is a pure renderer: `sync(view, opts)` places cards, `queue_action(action)` before a sync animates that move (draw, swap, discard, king swap, peek), `pick(screen_pos)` turns clicks into card/deck/discard/drawn hits. Card faces come only from the view, like the 2D slots. Card nodes hang on `Table3D` directly, so `layout()` must free them on every hot-seat relayout. Setting `table_3d` switches back to the old 2D table.

## Characters and hand

`figure_3d.gd` builds an opponent from the Quaternius body (clothing painted via `T_Mask_Clothes_*` + `clothed_body.gdshader`), hair on the head bone, sitting animations from `UAL1_Standard.glb`. `arm_ik.gd` (SkeletonModifier3D) puts hands on the table and reaches. `hand_rig.gd` is your own right arm: only the arm triangles of the body, driven by IK; the node's transform is the hand target (fingers -Z, back of hand +Y, origin = wrist). If the target is out of reach the camera leans forward.

The 2D `SeatView`/`CardView` nodes are invisible proxies for keyboard focus and tests.

## Effects

`scripts/ui/fx_layer.gd`: Dame call (red edge pulse, banner, countdown), turn banner, winner zoom, confetti. `Table3D` flips cards one after another at round end and shows "denkt nach …" over a thinking AI.

## Keys

| Key | Action |
|---|---|
| 1–6 | Focus that slot |
| Space | Draw from deck |
| Enter | Confirm swap / end turn |
| A / X | Discard drawn / extra discard |
| D | Call Dame if `can_call_dame` |
| H | How-to overlay |
| Esc | Cancel targeting / pause |

`grab_focus()` after every state push. A full-rect `ColorRect` behind the table must use `mouse_filter = MOUSE_FILTER_IGNORE` or it eats clicks.

## Theme

Modern dark casino from `scripts/ui/ui_theme.gd`: near-black background, gold accent, ivory text, Inter body, Playfair Display headings, DejaVu Sans as symbol fallback. Buttons at least 44 px tall (touch). Card art comes from `assets/cards` (`tools/assets/gen_cards.py`), never drawn in code.

GL Compatibility: no glow, no volumetric fog. Do not switch the renderer to Forward+. Window stays 1280×720 with `canvas_items` stretch.
