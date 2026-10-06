extends Node3D

# Die eigene rechte Hand in der Egoperspektive, aus einfachen Formen gebaut.
# Lokal: Handgelenk im Ursprung, Finger zeigen nach -Z, Handflaeche nach -Y, Aermel nach +Z.

const SKIN := Color(0.87, 0.67, 0.56)
const SLEEVE := Color(0.36, 0.27, 0.22)
const CUFF := Color(0.3, 0.22, 0.18)
# x-Versatz, Laenge: Zeigefinger (Daumenseite -X) bis kleiner Finger.
const FINGERS := [[-0.026, 0.074], [-0.009, 0.082], [0.009, 0.076], [0.025, 0.062]]

var _fingers: Array = []
var _thumb: Node3D
var _thumb_tip: Node3D
var _curl := 0.0

func _init() -> void:
	var skin := _mat(SKIN, 0.55)
	var sleeve := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.044
	cyl.bottom_radius = 0.056
	cyl.height = 0.42
	sleeve.mesh = cyl
	sleeve.material_override = _mat(SLEEVE, 0.95)
	sleeve.rotation.x = PI / 2.0
	sleeve.position.z = 0.245
	add_child(sleeve)
	var cuff := MeshInstance3D.new()
	var cuff_mesh := CylinderMesh.new()
	cuff_mesh.top_radius = 0.047
	cuff_mesh.bottom_radius = 0.047
	cuff_mesh.height = 0.04
	cuff.mesh = cuff_mesh
	cuff.material_override = _mat(CUFF, 0.95)
	cuff.rotation.x = PI / 2.0
	cuff.position.z = 0.04
	add_child(cuff)
	var wrist := _ellipsoid(Vector3(0.032, 0.022, 0.04), skin)
	wrist.position.z = 0.0
	add_child(wrist)
	var palm := _ellipsoid(Vector3(0.043, 0.016, 0.05), skin)
	palm.position = Vector3(0.0, 0.0, -0.05)
	add_child(palm)
	var knuckles := _ellipsoid(Vector3(0.042, 0.013, 0.016), skin)
	knuckles.position = Vector3(0.0, 0.002, -0.088)
	add_child(knuckles)
	for f in FINGERS:
		var pivot := Node3D.new()
		pivot.position = Vector3(float(f[0]), 0.0, -0.092)
		add_child(pivot)
		var length: float = f[1]
		var seg1 := _segment(length * 0.55, 0.0088, skin)
		pivot.add_child(seg1)
		var joint := Node3D.new()
		joint.position.z = -length * 0.55
		pivot.add_child(joint)
		var seg2 := _segment(length * 0.45, 0.0082, skin)
		joint.add_child(seg2)
		_fingers.append([pivot, joint])
	_thumb = Node3D.new()
	_thumb.position = Vector3(-0.036, -0.004, -0.03)
	add_child(_thumb)
	_thumb.add_child(_segment(0.038, 0.0105, skin))
	_thumb_tip = Node3D.new()
	_thumb_tip.position.z = -0.038
	_thumb.add_child(_thumb_tip)
	_thumb_tip.add_child(_segment(0.03, 0.0095, skin))
	set_pose("rest")


static func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _ellipsoid(radii: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 20
	s.rings = 12
	mi.mesh = s
	mi.scale = radii
	mi.material_override = m
	return mi


# Fingerglied, das vom Pivot aus nach -Z reicht.
static func _segment(length: float, radius: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = length + radius * 2.0
	c.radial_segments = 12
	c.rings = 4
	mi.mesh = c
	mi.material_override = m
	mi.rotation.x = -PI / 2.0
	mi.position.z = -length / 2.0
	return mi


# "rest" locker gekruemmt, "reach" gestreckt zum Greifen, "hold" Karte zwischen Daumen und Fingern.
func set_pose(pose: String) -> void:
	match pose:
		"reach":
			_apply(0.15, 0.25, Vector3(-0.2, -0.7, 0.0), -0.2)
		"hold":
			_apply(0.55, 0.6, Vector3(0.9, -0.35, 0.0), -0.5)
		"pinch":
			_apply(0.35, 0.4, Vector3(-0.1, -0.35, 0.0), -0.5)
		_:
			_apply(0.45, 0.55, Vector3(-0.35, -0.8, 0.0), -0.35)


func _apply(base: float, tip: float, thumb_rot: Vector3, thumb_tip: float) -> void:
	for i in range(_fingers.size()):
		var spread := (float(i) - 1.5) * 0.05
		_fingers[i][0].rotation = Vector3(-base, spread, 0.0)
		_fingers[i][1].rotation = Vector3(-tip, 0.0, 0.0)
	_thumb.rotation = thumb_rot
	_thumb_tip.rotation = Vector3(thumb_tip, 0.0, 0.0)
