extends SkeletonModifier3D

# Zwei-Knochen-IK fuer Arme plus Fingerhaltung, nach der Animation angewendet.
# Ziel je Arm ist ein Welt-Transform in der Hand-Konvention des Tisches:
# Finger zeigen nach -Z, Handruecken nach +Y, Ursprung = Handgelenk.

const FINGERS := ["index", "middle", "ring", "pinky"]

# side -> {target: Transform3D, enabled: bool, curl: float, thumb: float, pole: Vector3}
var arms := {}
var _offset := {}
var _ready_bones := false

func set_arm(side: String, target: Transform3D, curl: float = 0.35, thumb: float = 0.3) -> void:
	var a: Dictionary = arms.get(side, {})
	a.target = target
	a.enabled = true
	a.curl = curl
	a.thumb = thumb
	if not a.has("pole"):
		# Ellbogen nach aussen, unten und hinten (Figurenraum, Gesicht nach +Z).
		a.pole = Vector3(-0.7 if side == "r" else 0.7, -0.6, -0.4)
	arms[side] = a


func release(side: String) -> void:
	if arms.has(side):
		arms[side].enabled = false


func _setup() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for side in ["r", "l"]:
		var hand := sk.find_bone("hand_" + side)
		var mid := sk.find_bone("middle_01_" + side)
		if hand < 0 or mid < 0:
			continue
		var rest := sk.get_bone_global_rest(hand)
		# Handrahmen in Ruhelage: Finger entlang -Z, Handruecken +Y.
		var f := (sk.get_bone_global_rest(mid).origin - rest.origin).normalized()
		var z := -f
		var y := Vector3.UP
		var x := y.cross(z).normalized()
		y = z.cross(x)
		_offset[side] = Basis(x, y, z).inverse() * rest.basis.orthonormalized()
	_ready_bones = true


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if not _ready_bones:
		_setup()
	var to_skel := sk.global_transform.affine_inverse()
	for side in arms:
		var a: Dictionary = arms[side]
		if not bool(a.get("enabled", false)) or not _offset.has(side):
			continue
		var t: Transform3D = to_skel * (a.target as Transform3D)
		_solve(sk, side, t, a.pole)
		_fingers(sk, side, float(a.curl), float(a.thumb))


func _solve(sk: Skeleton3D, side: String, t: Transform3D, pole: Vector3) -> void:
	var up := sk.find_bone("upperarm_" + side)
	var lo := sk.find_bone("lowerarm_" + side)
	var hd := sk.find_bone("hand_" + side)
	var gu := sk.get_bone_global_pose(up)
	var s := gu.origin
	var e := sk.get_bone_global_pose(lo).origin
	var w := sk.get_bone_global_pose(hd).origin
	var l1 := s.distance_to(e)
	var l2 := e.distance_to(w)
	var d := clampf(s.distance_to(t.origin), 0.05, (l1 + l2) * 0.999)
	var axis := (t.origin - s).normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var bend := (pole - axis * pole.dot(axis))
	if bend.length() < 0.001:
		bend = Vector3.DOWN
	bend = bend.normalized()
	var e2 := s + axis * l1 * cos_a + bend * l1 * sqrt(1.0 - cos_a * cos_a)
	gu.basis = Basis(Quaternion((e - s).normalized(), (e2 - s).normalized())) * gu.basis
	sk.set_bone_global_pose(up, gu)
	var gl := sk.get_bone_global_pose(lo)
	var wc := sk.get_bone_global_pose(hd).origin
	var reach := t.origin if s.distance_to(t.origin) <= l1 + l2 else s + axis * d
	gl.basis = Basis(Quaternion((wc - gl.origin).normalized(), (reach - gl.origin).normalized())) * gl.basis
	sk.set_bone_global_pose(lo, gl)
	var gh := sk.get_bone_global_pose(hd)
	gh.basis = t.basis.orthonormalized() * (_offset[side] as Basis)
	sk.set_bone_global_pose(hd, gh)


# Finger beugen: lokale X-Achse der Fingerknochen zeigt quer zur Hand.
func _fingers(sk: Skeleton3D, side: String, curl: float, thumb: float) -> void:
	# Rechts und links beugen beide mit positivem Winkel (Achsen sind gespiegelt angelegt).
	var sign := 1.0
	for f in FINGERS:
		var spread: float = {"index": 0.8, "middle": 1.0, "ring": 1.1, "pinky": 1.2}[f]
		for k in [1, 2, 3]:
			var b := sk.find_bone("%s_0%d_%s" % [f, k, side])
			if b < 0:
				continue
			var ang := curl * float(spread) * (0.9 if k == 1 else 1.1) * sign
			sk.set_bone_pose_rotation(b, sk.get_bone_rest(b).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, ang))
	for k in [1, 2, 3]:
		var tb := sk.find_bone("thumb_0%d_%s" % [k, side])
		if tb >= 0:
			sk.set_bone_pose_rotation(tb, sk.get_bone_rest(tb).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, thumb * 0.6 * sign))
