extends Node3D

# Ein Mensch am Tisch: Quaternius-Koerper (CC0) mit aufgemalter Kleidung,
# Frisur am Kopfknochen und Animationen aus der Universal Animation Library.
# Lokal: Figur schaut nach -Z (zur Tischmitte), Ursprung auf dem Boden unter dem Becken.

const BODY_DIR := "res://assets/characters/body/"
const HAIR_DIR := "res://assets/characters/hair/"
const ANIM_PATH := "res://assets/characters/anim/UAL1_Standard.glb"
const ClothShader = preload("res://shaders/clothed_body.gdshader")
const ArmIKScript = preload("res://scripts/table3d/arm_ik.gd")

const BODY := {
	"m": {"scene": "Superhero_Male_FullBody.gltf", "mesh": "SuperHero_Male", "light": "T_Superhero_Male_Ligh.png", "dark": "T_Superhero_Male_Dark.png", "mask": "T_Mask_Clothes_Male.png"},
	"f": {"scene": "Superhero_Female_FullBody.gltf", "mesh": "Superhero_Female", "light": "T_Superhero_Female_Light_BaseColor.png", "dark": "T_Superhero_Female_Dark_BaseColor.png", "mask": "T_Mask_Clothes_Female.png"},
}

# Feste Typen fuer die Standardnamen, damit "Bruno" nie eine Frau ist.
const LOOKS := {
	"Lotte": {"g": "f", "skin": "light", "hair": "Hair_Long", "hair_tint": Color(0.55, 0.32, 0.16), "top": Color(0.45, 0.07, 0.12), "bottom": Color(0.1, 0.1, 0.12), "knit": 1.0, "height": 0.97},
	"Bruno": {"g": "m", "skin": "light", "hair": "Hair_SimpleParted", "beard": true, "hair_tint": Color(0.25, 0.17, 0.1), "top": Color(0.1, 0.16, 0.3), "bottom": Color(0.2, 0.17, 0.14), "knit": 1.0, "height": 1.02},
	"Erika": {"g": "f", "skin": "dark", "hair": "Hair_Buns", "hair_tint": Color(0.12, 0.08, 0.06), "top": Color(0.08, 0.32, 0.26), "bottom": Color(0.08, 0.08, 0.1), "knit": 0.0, "height": 0.95},
	"Kurt": {"g": "m", "skin": "dark", "hair": "Hair_Buzzed", "beard": true, "hair_tint": Color(0.1, 0.08, 0.07), "top": Color(0.55, 0.42, 0.25), "bottom": Color(0.12, 0.12, 0.13), "knit": 1.0, "height": 1.0},
	"Hilde": {"g": "f", "skin": "light", "hair": "Hair_BuzzedFemale", "hair_tint": Color(0.75, 0.73, 0.7), "top": Color(0.32, 0.18, 0.42), "bottom": Color(0.14, 0.12, 0.16), "knit": 1.0, "height": 0.96},
	"Otto": {"g": "m", "skin": "light", "hair": "Hair_Long", "hair_tint": Color(0.5, 0.48, 0.45), "beard": true, "top": Color(0.25, 0.28, 0.2), "bottom": Color(0.22, 0.2, 0.18), "knit": 0.0, "height": 1.0},
}
const FALLBACK := ["Lotte", "Bruno", "Erika", "Kurt", "Hilde", "Otto"]

static var _anim_lib: AnimationLibrary

var skeleton: Skeleton3D
var anim: AnimationPlayer
var body_mat: ShaderMaterial
var look: Dictionary = {}
var _idle := "Sitting_Idle"
var ik
var _rest_hands := {}

static func look_for(name: String, seat: int) -> Dictionary:
	if LOOKS.has(name):
		return LOOKS[name]
	return LOOKS[FALLBACK[seat % FALLBACK.size()]]


static func animations() -> AnimationLibrary:
	if _anim_lib == null:
		var src: Node = (load(ANIM_PATH) as PackedScene).instantiate()
		var ap: AnimationPlayer = src.get_node("AnimationPlayer")
		_anim_lib = ap.get_animation_library("").duplicate(true)
		src.free()
		for n in ["Sitting_Idle", "Sitting_Talking", "Idle", "Dance"]:
			if _anim_lib.has_animation(n):
				_anim_lib.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	return _anim_lib


func build(p_look: Dictionary, with_anim: bool = true) -> void:
	look = p_look
	var g := str(look.get("g", "m"))
	var spec: Dictionary = BODY[g]
	var body: Node3D = (load(BODY_DIR + str(spec.scene)) as PackedScene).instantiate()
	add_child(body)
	skeleton = body.get_node("Armature/Skeleton3D")
	_slim(skeleton)
	var mesh: MeshInstance3D = skeleton.get_node(str(spec.mesh))
	var src_mat := mesh.get_active_material(0) as BaseMaterial3D
	body_mat = ShaderMaterial.new()
	body_mat.shader = ClothShader
	var skin_tex: Texture2D = load(BODY_DIR + str(spec.light if str(look.get("skin", "light")) == "light" else spec.dark))
	body_mat.set_shader_parameter("albedo_tex", skin_tex)
	if src_mat != null:
		body_mat.set_shader_parameter("normal_tex", src_mat.normal_texture)
		body_mat.set_shader_parameter("rough_tex", src_mat.roughness_texture)
	body_mat.set_shader_parameter("mask_tex", load(BODY_DIR + str(spec.mask)))
	body_mat.set_shader_parameter("top_color", look.get("top", Color(0.3, 0.1, 0.1)))
	body_mat.set_shader_parameter("bottom_color", look.get("bottom", Color(0.1, 0.1, 0.1)))
	body_mat.set_shader_parameter("shoe_color", look.get("shoes", Color(0.07, 0.05, 0.04)))
	body_mat.set_shader_parameter("top_knit", float(look.get("knit", 1.0)))
	mesh.material_override = body_mat
	var head := skeleton.find_bone("Head")
	if head >= 0:
		var attach := BoneAttachment3D.new()
		attach.bone_name = "Head"
		skeleton.add_child(attach)
		# Frisuren sind im Figurenraum modelliert: Kopf-Ruhelage herausrechnen.
		var offset := skeleton.get_bone_global_rest(head).affine_inverse()
		for part in [str(look.get("hair", "")), "Hair_Beard" if bool(look.get("beard", false)) else ""]:
			if part == "":
				continue
			var hair: Node3D = (load(HAIR_DIR + part + ".gltf") as PackedScene).instantiate()
			hair.transform = offset
			attach.add_child(hair)
			_tint(hair, look.get("hair_tint", Color(0.3, 0.2, 0.12)))
	scale = Vector3.ONE * float(look.get("height", 1.0))
	if with_anim:
		anim = AnimationPlayer.new()
		body.add_child(anim)
		anim.root_node = NodePath("..")
		anim.add_animation_library("", animations())
		play_idle()


static func _tint(n: Node, c: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in range(mi.get_surface_override_material_count()):
			var m := mi.get_active_material(i)
			if m is BaseMaterial3D:
				var dup := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				dup.albedo_color = c * 1.6
				mi.set_surface_override_material(i, dup)
	for ch in n.get_children():
		_tint(ch, c)


func play_idle() -> void:
	if anim == null:
		return
	anim.play(_idle, 0.4)
	# Nicht alle Figuren atmen im Gleichtakt.
	anim.seek(randf() * anim.current_animation_length, true)


# Kurz reden (wenn die Figur am Zug ist oder Dame ruft).
func talk(on: bool) -> void:
	if anim == null:
		return
	var want := "Sitting_Talking" if on else "Sitting_Idle"
	if want != _idle:
		_idle = want
		anim.play(_idle, 0.5)


func cheer() -> void:
	if anim != null and anim.has_animation("Sitting_Talking"):
		anim.play("Sitting_Talking", 0.3)


# Haende per IK auf feste Welt-Ziele legen (z. B. auf den Tisch vor die Karten).
func rest_hands(left: Transform3D, right: Transform3D) -> void:
	if ik == null:
		ik = ArmIKScript.new()
		skeleton.add_child(ik)
	_rest_hands = {"l": left, "r": right}
	ik.set_arm("l", left, 0.45, 0.3)
	ik.set_arm("r", right, 0.45, 0.3)


# Rechte Hand kurz zu einem Punkt fuehren (Karte ziehen, ablegen, antippen).
func reach(target: Transform3D, dur: float = 0.35) -> void:
	if ik == null or not _rest_hands.has("r"):
		return
	var start: Transform3D = _rest_hands.r
	var tw := create_tween()
	tw.tween_method(func(f: float) -> void: ik.set_arm("r", start.interpolate_with(target, f), 0.15, 0.2), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.12)
	tw.tween_method(func(f: float) -> void: ik.set_arm("r", target.interpolate_with(start, f), 0.45, 0.3), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Die Gratis-Koerper sind Superhelden-Proportionen: Brust, Schultern und Arme
# schmaler machen, damit Pullover nicht wie Bodybuilder-Stretch aussehen.
const SLIM := {
	"spine_03": Vector3(0.88, 1.0, 0.9),
	"upperarm_l": Vector3(0.84, 1.0, 0.84), "upperarm_r": Vector3(0.84, 1.0, 0.84),
	"hand_l": Vector3(1.12, 1.0, 1.12), "hand_r": Vector3(1.12, 1.0, 1.12),
	"thigh_l": Vector3(0.9, 1.0, 0.9), "thigh_r": Vector3(0.9, 1.0, 0.9),
	"neck_01": Vector3(1.0 / 0.88, 1.0, 1.0 / 0.9),
}

static func _slim(sk: Skeleton3D) -> void:
	for n in SLIM:
		var b := sk.find_bone(n)
		if b < 0:
			continue
		var rest := sk.get_bone_rest(b)
		rest.basis = rest.basis.scaled_local(SLIM[n])
		sk.set_bone_rest(b, rest)
		sk.set_bone_pose_scale(b, SLIM[n])
