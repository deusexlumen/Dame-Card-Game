---
description: "Index for the DAME Godot port. Read before choosing a reference."
---

# DAME Godot graph

## Core

- [[rules]] — deck, points, phases, J/K/Q/A/10, Dame call, 50-point cut. Source of truth over the README.
- [[architecture]] — where rules stop and the scene tree starts. Hidden-info boundary.
- [[ui]] — 3D table, first-person hand, casino theme, effects, keys. No rule logic.
- [[gdscript-47]] — engine and renderer traps for this project.

## Cross-skill

Do not load generic Godot packs for this port unless a trap in [[gdscript-47]] is not enough. `card-game` genre skills assume untap/combat and leak the wrong phase model.
