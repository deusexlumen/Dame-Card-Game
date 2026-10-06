---
description: "DAME table UI: four-slot hand, keyboard, phosphor theme on GL Compatibility. Read only for presentation."
connections: [architecture, rules]
---

# UI

Presentation only. If a button computes a score, move it to [[rules]].

## Hand

Four `CardSlot` nodes in an `HBoxContainer`. Do not animate layout by setting `position` on container children. Selected slot is focus, not a parallel index that can desync.

Unknown card: back texture, no rank label in the accessibility text. Known card: rank and suit. Peek flash is a tween on modulate, then the view decides if it stays known.

## Keys

| Key | Action |
|---|---|
| 1–4 | Focus that slot |
| Space | Draw from deck |
| Enter | Confirm swap or discard |
| D | Call Dame if `can_call_dame` |
| Z / E | Undo an uncommitted peek |
| Esc | Cancel targeting |

`grab_focus()` after every state push. A full-rect `ColorRect` behind the table must use `mouse_filter = MOUSE_FILTER_IGNORE` or it eats clicks.

## Theme

Black background, green phosphor labels (`Color(0.55, 1.0, 0.55)`). One `Theme` on `Table`. No per-slot font overrides.

GL Compatibility: no `WorldEnvironment` glow, no volumetric fog. Phosphor is a `CanvasItem` shader or modulate. If the shader fails on GL Compatibility, fall back to modulate. Do not switch the renderer to Forward+.

Window stays 1280×720. Anchors full-rect on the root `Control`. Containers do the rest.

German on every button: Ziehen, Ablegen, Tauschen, Dame rufen, Strafkarte.
