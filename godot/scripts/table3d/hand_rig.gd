extends Node3D

# Die eigene rechte Hand in der Egoperspektive. Dieser Knoten ist nur das Ziel:
# Der Tisch bewegt ihn wie eine Hand (Finger -Z, Handruecken +Y, Ursprung Handgelenk).
# Ein echter Figurenarm (nur Arm-Dreiecke sichtbar) folgt per IK. Ist das Ziel
# weiter weg als der Arm reicht, lehnt sich der Spieler vor (Kamera + Schulter).

const Figure3DScript = preload("res://scripts/table3d/figure_3d.gd")
const ArmIKScript = preload("res://scripts/table3d/arm_ik.gd")

const ARM_BONES := ["upperarm_r", "lowerarm_r", "hand_r"]
const MAX_LEAN := 0.38
# Arm etwas laenger als echt (ueblich in Ego-Ansichten), damit die ruhende Hand im Bild liegt.
const ARM_SCALE := 1.15
const POSES := {
	"rest": [0.55, 0.35],
	"reach": [0.12, 0.15],
	"pinch": [0.4, 0.75],
	"hold": [0.75, 0.9],
}

var camera: Camera3D
var _rig: Node3D
var _ik
var _cam_base := Vector3.ZERO
var _shoulder_cam := Vector3(0.22, -0.3, -0.08)
var _reach := 0.5
var _lean := 0.0
var _pose := "rest"

func setup(cam: Camera3D, look: Dictionary) -> void:
	camera = cam
	_cam_base = cam.position
	_rig = Figure3DScript.new()
	_rig.top_level = true
	add_child(_rig)
	var l := look.duplicate()
	l.erase("hair")
	l.erase("beard")
	_rig.build(l, false)
	var sk: Skeleton3D = _rig.skeleton
	for c in sk.get_children():
		if c is MeshInstance3D:
			if c.material_override is ShaderMaterial:
				c.mesh = _arm_only(c as MeshInstance3D, sk)
				c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				c.visible = false
	var up := sk.find_bone("upperarm_r")
	var lo := sk.find_bone("lowerarm_r")
	var hd := sk.find_bone("hand_r")
	_reach = (sk.get_bone_global_rest(up).origin.distance_to(sk.get_bone_global_rest(lo).origin) + sk.get_bone_global_rest(lo).origin.distance_to(sk.get_bone_global_rest(hd).origin)) * ARM_SCALE
	_ik = ArmIKScript.new()
	sk.add_child(_ik)
	set_pose("rest")


# Nur Dreiecke, die ueberwiegend an Oberarm, Unterarm, Hand oder Fingern rechts haengen.
static func _arm_only(mi: MeshInstance3D, sk: Skeleton3D) -> ArrayMesh:
	var src: Mesh = mi.mesh
	var arrays: Array = src.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var per := bones.size() / verts.size()
	var keep_bone := {}
	var skin: Skin = mi.skin
	for i in range(skin.get_bind_count() if skin != null else 0):
		var bn := str(skin.get_bind_name(i))
		var bi := skin.get_bind_bone(i)
		if bn == "" and bi >= 0:
			bn = sk.get_bone_name(bi)
		if bn in ARM_BONES or (bn.ends_with("_r") and (bn.begins_with("index") or bn.begins_with("middle") or bn.begins_with("ring") or bn.begins_with("pinky") or bn.begins_with("thumb"))):
			keep_bone[i] = true
	var arm_w := PackedFloat32Array()
	arm_w.resize(verts.size())
	for v in range(verts.size()):
		var s := 0.0
		for k in range(per):
			if keep_bone.has(bones[v * per + k]):
				s += weights[v * per + k]
		arm_w[v] = s
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var out := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		if arm_w[idx[t]] + arm_w[idx[t + 1]] + arm_w[idx[t + 2]] > 2.4:
			out.append_array([idx[t], idx[t + 1], idx[t + 2]])
	arrays[Mesh.ARRAY_INDEX] = out
	var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	m.surface_set_material(0, src.surface_get_material(0))
	return m


# Kamera wurde verschoben (andere Platzzahl): neue Grundposition merken.
func rebase() -> void:
	if camera != null:
		_cam_base = camera.position
		_lean = 0.0


func set_pose(pose: String) -> void:
	_pose = pose if POSES.has(pose) else "rest"


func _process(delta: float) -> void:
	if _rig == null or camera == null:
		return
	# Vorlehnen, wenn das Ziel ausser Reichweite ist.
	var flat_fwd := -camera.global_transform.basis.z
	flat_fwd.y = 0.0
	flat_fwd = flat_fwd.normalized()
	var base_cam := (camera.get_parent() as Node3D).global_transform * _cam_base if camera.get_parent() is Node3D else _cam_base
	var cam_basis := camera.global_transform.basis
	var shoulder0 := base_cam + cam_basis * _shoulder_cam
	var need := clampf(shoulder0.distance_to(global_position) - _reach * 0.93, 0.0, MAX_LEAN)
	_lean = lerpf(_lean, need, clampf(delta * 6.0, 0.0, 1.0))
	camera.position = _cam_base + flat_fwd * _lean
	var shoulder := shoulder0 + flat_fwd * _lean
	# Figur schaut in Blickrichtung; rechte Schulter liegt auf "shoulder".
	var sk: Skeleton3D = _rig.skeleton
	var face := Basis.looking_at(-flat_fwd, Vector3.UP)
	var rest_sh := sk.get_bone_global_rest(sk.find_bone("upperarm_r")).origin
	_rig.global_transform = Transform3D(face.scaled(Vector3.ONE * ARM_SCALE), shoulder - face * (rest_sh * ARM_SCALE))
	var p: Array = POSES[_pose]
	_ik.set_arm("r", global_transform, float(p[0]), float(p[1]))
