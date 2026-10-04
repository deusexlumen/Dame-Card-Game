---
description: "Godot 4.5 and GL Compatibility traps for the DAME stub. Read when porting a 4.7 snippet or when a node call returns null."
connections: [architecture, ui]
---

# Godot 4.5 traps

Project features are `4.5` and `GL Compatibility`. A 4.7 skill is not authoritative here.

| Trap | Do |
|---|---|
| `@onready` and `@export` on the same var | Pick one. `@onready` overwrites the export. |
| `TileMap` | Not used. If a snippet mentions it, ignore. |
| Signal API | `signal.connect(callable)`, `signal.emit()`. No string `connect`. |
| Typed GDScript | Static types on every rules function. |
| Shared `Resource` | `duplicate(true)` per card instance. |
| `res://` write | Rules and saves go to memory or `user://`. |
| `get_node` in `_ready` race | `%UniqueName` or `@onready`. Null-check before peek tween. |
| Freed card view | Disconnect before `queue_free`. |
| `await` inside rules | Forbidden. Tween awaits live on the slot node. |
| Renderer swap | Do not edit `renderer/rendering_method`. |

Headless tests: extend `SceneTree` or a plain `RefCounted` suite invoked from a `--headless` script. Do not boot `table.tscn` to prove a Dame call.
