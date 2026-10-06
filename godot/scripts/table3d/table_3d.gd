extends Node3D

# Der Spieltisch in 3D aus der Egoperspektive. Reiner Darsteller: bekommt die Sicht
# (DameView) und Hinweise auf ausgefuehrte Aktionen, schreibt nie in die Regeln.
# Eingaben laufen ueber pick(), die Entscheidung trifft table_view.gd.

const Card3DScript = preload("res://scripts/table3d/card_3d.gd")
const HandRigScript = preload("res://scripts/table3d/hand_rig.gd")
const Figure3DScript = preload("res://scripts/table3d/figure_3d.gd")
const UiThemeScript = preload("res://scripts/ui/ui_theme.gd")

const TABLE_Y := 0.76
const TABLE_R := 0.64
const CARD_R := 0.37
const FIGURE_R := 1.02
const CARD_GAP := 0.078
# Seitliche Plaetze leicht nach hinten gedreht, damit sie im Bild sitzen statt am Rand.
const SEAT_ANGLE := {"self": 0.0, "left": -PI * 0.62, "right": PI * 0.62, "opposite": PI}
const DECK_POS := Vector3(-0.09, 0.0, -0.03)
const DISCARD_POS := Vector3(0.09, 0.0, -0.03)
const FIGURE_COLORS := [Color(0.48, 0.2, 0.2), Color(0.2, 0.32, 0.5), Color(0.5, 0.42, 0.2), Color(0.3, 0.45, 0.32), Color(0.42, 0.28, 0.48)]
const HAIR_COLORS := [Color(0.12, 0.08, 0.05), Color(0.45, 0.3, 0.15), Color(0.6, 0.58, 0.55), Color(0.25, 0.12, 0.07)]
const SKIN_TONES := [Color(0.85, 0.66, 0.54), Color(0.62, 0.45, 0.34), Color(0.93, 0.76, 0.64), Color(0.48, 0.33, 0.24)]

var accent := Color(0.55, 1.0, 0.55)
var back_style := "raster"
var felt := Color(0.07, 0.3, 0.16)
var animate := true

var camera: Camera3D
var hand
var _seat_roots := {}
var _roles := {}
var _slots := {}
var _figures := {}
var _penalty_stacks := {}
var _deck_stack: MeshInstance3D
var _deck_top
var _deck_label: Label3D
var _discard_stack: MeshInstance3D
var _discard_top
var _discard_label: Label3D
var _self_label: Label3D
var _held
var _held_seat := -1
var _viewer := 0
var _last_deal := -1
var _pending: Array = []
var _hand_tw: Tween
var _hand_state := "rest"
var _hand_cursor := Transform3D()
var _hover: Dictionary = {}
var _markers := {}
var _built := false

func build(p_accent: Color, p_back: String, table_color: Color) -> void:
	accent = p_accent
	back_style = p_back
	felt = _felt_from(table_color)
	_build_room()
	_build_table()
	_build_piles()
	_held = _new_card("drawn")
	_held.visible = false
	add_child(_held)
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.near = 0.03
	camera.far = 30.0
	camera.position = Vector3(0.0, 1.27, 0.98)
	camera.rotation.x = deg_to_rad(-22.0)
	add_child(camera)
	camera.current = true
	hand = HandRigScript.new()
	add_child(hand)
	hand.setup(camera, Figure3DScript.look_for("Spieler", 0).merged({"top": Color(0.16, 0.14, 0.2), "skin": "light", "g": "m"}, true))
	hand.transform = _hand_rest()
	_built = true


# Filzfarbe aus der Tischfarbe des Profils, aber nie so dunkel, dass Karten verschwinden.
static func _felt_from(c: Color) -> Color:
	var h := c.h
	var s := c.s
	if s < 0.15:
		h = 0.38
		s = 0.55
	return Color.from_hsv(h, clampf(s, 0.45, 0.7), 0.2)


func _mat(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _mesh(mesh: Mesh, m: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _cyl(top: float, bottom: float, height: float, segs: int = 48) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segs
	return c


func _build_room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.014, 0.016)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.45, 0.42)
	env.ambient_light_energy = 0.16
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(12, 12)
	_mesh(floor_mesh, _mat(Color(0.13, 0.085, 0.06), 0.85), Vector3.ZERO)
	# Waende des kleinen Hinterzimmers.
	var wall_m := _mat(Color(0.11, 0.1, 0.095), 1.0)
	for i in range(4):
		var wall := MeshInstance3D.new()
		var wm := PlaneMesh.new()
		wm.size = Vector2(9, 4)
		wm.orientation = PlaneMesh.FACE_Z
		wall.mesh = wm
		wall.material_override = wall_m
		var ang := i * PI / 2.0
		wall.rotation.y = ang
		wall.position = Vector3(sin(ang) * -3.6, 2.0, cos(ang) * -3.6)
		add_child(wall)

	# Haengelampe ueber dem Tisch.
	var cord := _mesh(_cyl(0.006, 0.006, 1.2, 8), _mat(Color(0.05, 0.05, 0.05)), Vector3(0, 2.75, 0))
	cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shade_m := _mat(Color(0.12, 0.2, 0.14), 0.5, 0.3)
	shade_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shade := _mesh(_cyl(0.07, 0.3, 0.2, 32), shade_m, Vector3(0, 2.08, 0))
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bulb_m := StandardMaterial3D.new()
	bulb_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_m.albedo_color = Color(1.0, 0.92, 0.75)
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.045
	bulb_mesh.height = 0.09
	var bulb := _mesh(bulb_mesh, bulb_m, Vector3(0, 2.0, 0))
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 1.98, 0)
	spot.rotation.x = -PI / 2.0
	spot.spot_angle = 58.0
	spot.spot_attenuation = 0.7
	spot.spot_range = 4.0
	spot.light_energy = 2.4
	spot.light_color = Color(1.0, 0.86, 0.66)
	spot.shadow_enabled = true
	add_child(spot)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 1.4, 1.3)
	fill.omni_range = 2.5
	fill.light_energy = 0.2
	fill.light_color = Color(0.85, 0.85, 1.0)
	add_child(fill)


func _build_table() -> void:
	var wood := _mat(Color(0.25, 0.14, 0.08), 0.45)
	var felt_m := _mat(felt, 1.0)
	_mesh(_cyl(TABLE_R, TABLE_R, 0.03, 64), felt_m, Vector3(0, TABLE_Y - 0.015, 0))
	var rim := TorusMesh.new()
	rim.inner_radius = TABLE_R - 0.02
	rim.outer_radius = TABLE_R + 0.085
	rim.rings = 64
	rim.ring_segments = 12
	var rim_i := _mesh(rim, wood, Vector3(0, TABLE_Y + 0.004, 0))
	rim_i.scale = Vector3(1.0, 0.45, 1.0)
	_mesh(_cyl(TABLE_R + 0.06, TABLE_R + 0.03, 0.09, 64), wood, Vector3(0, TABLE_Y - 0.06, 0))
	_mesh(_cyl(0.11, 0.14, 0.66, 24), wood, Vector3(0, 0.36, 0))
	_mesh(_cyl(0.42, 0.46, 0.04, 32), wood, Vector3(0, 0.02, 0))
	# Feiner Leuchtring im Filz in der Akzentfarbe.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.33
	ring.outer_radius = 0.338
	ring.rings = 64
	ring.ring_segments = 4
	var ring_m := StandardMaterial3D.new()
	ring_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_m.albedo_color = Color(accent.r, accent.g, accent.b) * 0.55
	var ring_i := _mesh(ring, ring_m, Vector3(0, TABLE_Y + 0.0005, 0))
	ring_i.scale = Vector3(1.0, 0.05, 1.0)
	ring_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_piles() -> void:
	var edge := _mat(Color(0.88, 0.87, 0.83), 0.8)
	_deck_stack = _mesh(BoxMesh.new(), edge, DECK_POS + Vector3(0, TABLE_Y, 0))
	_deck_top = _new_card("deck")
	add_child(_deck_top)
	_discard_stack = _mesh(BoxMesh.new(), edge, DISCARD_POS + Vector3(0, TABLE_Y, 0))
	_discard_top = _new_card("discard")
	add_child(_discard_top)
	_deck_label = _flat_label(24, DECK_POS + Vector3(0, TABLE_Y + 0.001, 0.08))
	_discard_label = _flat_label(24, DISCARD_POS + Vector3(0, TABLE_Y + 0.001, 0.08))
	_self_label = _flat_label(22, Vector3(0, TABLE_Y + 0.001, CARD_R + 0.095))


func _flat_label(size: int, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.font = UiThemeScript.font()
	l.font_size = size
	l.pixel_size = 0.0011
	l.outline_size = 0
	l.modulate = Color(accent.r, accent.g, accent.b, 0.9)
	l.position = pos
	l.rotation.x = -PI / 2.0
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.double_sided = false
	add_child(l)
	return l


func _new_card(kind: String):
	var c = Card3DScript.new()
	c.kind = kind
	c.setup_style(accent, back_style)
	return c


# ---------------------------------------------------------------- Plaetze

# roles: Platz -> "self"/"left"/"right"/"opposite", names: Platz -> Name.
func layout(roles: Dictionary, names: Dictionary) -> void:
	for r in _seat_roots.values():
		r.queue_free()
	# Karten haengen direkt am Tisch, nicht an den Plaetzen: sonst bleiben nach
	# jeder Hot-Seat-Uebergabe alte Karten liegen.
	for list in _slots.values():
		for c in list:
			remove_child(c)
			c.queue_free()
	_seat_roots.clear()
	_slots.clear()
	_figures.clear()
	_penalty_stacks.clear()
	_roles = roles.duplicate()
	_held.visible = false
	_held_seat = -1
	for seat in roles:
		var root := Node3D.new()
		root.rotation.y = float(SEAT_ANGLE.get(str(roles[seat]), 0.0))
		add_child(root)
		_seat_roots[seat] = root
		_slots[seat] = []
		if str(roles[seat]) == "self":
			_viewer = int(seat)
		else:
			_figures[seat] = _build_figure(root, int(seat), str(names.get(seat, "")))
		var pstack := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(Card3DScript.W, 0.002, Card3DScript.H)
		pstack.mesh = pm
		pstack.material_override = _mat(Color(0.55, 0.12, 0.1), 0.7)
		pstack.visible = false
		root.add_child(pstack)
		_penalty_stacks[seat] = pstack


func _build_figure(root: Node3D, seat: int, name: String) -> Dictionary:
	var fig := Node3D.new()
	fig.position = Vector3(0, 0, FIGURE_R)
	root.add_child(fig)
	# Stuhl.
	var chair_m := _mat(Color(0.18, 0.1, 0.06), 0.5)
	var seat_box := BoxMesh.new()
	seat_box.size = Vector3(0.46, 0.05, 0.44)
	_mesh(seat_box, chair_m, Vector3(0, 0.48, 0.05), fig)
	var back_box := BoxMesh.new()
	back_box.size = Vector3(0.46, 0.62, 0.05)
	_mesh(back_box, chair_m, Vector3(0, 0.82, 0.27), fig)
	var person = Figure3DScript.new()
	fig.add_child(person)
	person.build(Figure3DScript.look_for(name, seat))
	# Modelle schauen nach +Z, am Tisch soll die Figur zur Mitte (-Z) sehen.
	person.rotation.y = PI
	var head: Node3D = person
	# Haende liegen vor den eigenen Karten auf dem Tisch, Finger zur Mitte.
	var hz := -(FIGURE_R - TABLE_R) - 0.13
	person.rest_hands(
		fig.global_transform * Transform3D(Basis(Vector3.UP, -0.35), Vector3(-0.16, TABLE_Y + 0.035, hz)),
		fig.global_transform * Transform3D(Basis(Vector3.UP, 0.35), Vector3(0.16, TABLE_Y + 0.035, hz)))
	var label := Label3D.new()
	label.font = UiThemeScript.bold_font()
	label.font_size = 40
	label.pixel_size = 0.0016
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 32
	# Namensschild vor der Brust, damit es nie unter der oberen Leiste verschwindet.
	label.position = Vector3(0, 1.02, -0.2)
	label.text = name
	fig.add_child(label)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, TABLE_Y + 0.25, -0.62)
	glow.omni_range = 0.55
	glow.light_energy = 0.0
	glow.light_color = accent
	glow.shadow_enabled = false
	fig.add_child(glow)
	return {"node": fig, "label": label, "glow": glow, "head": head, "person": person}


func _limb(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var len := a.distance_to(b)
	var cap := CapsuleMesh.new()
	cap.radius = r
	cap.height = len + r * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = cap
	mi.material_override = m
	parent.add_child(mi)
	var mid := (a + b) / 2.0
	var dir := (b - a).normalized()
	var up := Vector3.FORWARD if absf(dir.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var x := up.cross(dir).normalized()
	var z := x.cross(dir)
	mi.transform = Transform3D(Basis(x, dir, z), mid)


# ---------------------------------------------------------------- Aktualisieren

# Vor dem naechsten sync(): diese Aktion wurde gerade ausgefuehrt (Mensch oder KI).
func queue_action(action: Dictionary) -> void:
	_pending.append(action.duplicate())


# opts: face (Callable seat,i,card -> bool), peek (Callable seat,i -> bool), targets (Platz -> Array),
# selected (int), drawn_face (bool), deck_target, discard_target, drawn_target (bool).
func sync(view: Dictionary, opts: Dictionary) -> void:
	if not _built:
		return
	var from := {}
	var bumps: Array = []
	var hand_plan := ""
	var hand_target_key := ""
	for a in _pending:
		var s := int(a.get("seat", -1))
		if s != _viewer:
			_figure_reach(s, a)
		match str(a.get("type", "")):
			"draw_deck":
				from["held"] = _deck_top.global_transform
				if s == _viewer:
					hand_plan = "draw"
					hand_target_key = "deck"
			"draw_discard":
				from["held"] = _discard_top.global_transform
				if s == _viewer:
					hand_plan = "draw"
					hand_target_key = "discard"
			"discard_drawn":
				from["discard"] = _held.global_transform
				if s == _viewer:
					hand_plan = "place"
					hand_target_key = "discard"
			"swap":
				var i := int(a.get("hand_index", -1))
				var old = _slot(s, i)
				from["slot:%d:%d" % [s, i]] = _held.global_transform
				if old != null:
					from["discard"] = old.global_transform
				if s == _viewer:
					hand_plan = "place"
					hand_target_key = "slot:%d:%d" % [s, i]
			"discard_extra":
				var e = _slot(s, int(a.get("hand_index", -1)))
				if e != null:
					from["discard"] = e.global_transform
			"king_swap":
				var own = _slot(s, int(a.get("chosen_index", -1)))
				var other = _slot(int(a.get("opponent_seat", -1)), int(a.get("opponent_index", -1)))
				if own != null and other != null:
					from["slot:%d:%d" % [s, int(a.chosen_index)]] = other.global_transform
					from["slot:%d:%d" % [int(a.opponent_seat), int(a.opponent_index)]] = own.global_transform
				if s == _viewer:
					hand_plan = "tap"
					hand_target_key = "slot:%d:%d" % [int(a.opponent_seat), int(a.opponent_index)]
			"look_card":
				bumps.append([int(a.get("target_seat", -1)), int(a.get("hand_index", -1))])
				if s == _viewer:
					hand_plan = "tap"
					hand_target_key = "slot:%d:%d" % [int(a.get("target_seat", -1)), int(a.get("hand_index", -1))]
			"call_dame":
				_pulse_figure(s)
	_pending.clear()

	var dealing := int(view.deal) != _last_deal
	_last_deal = int(view.deal)
	var face_cb: Callable = opts.get("face", Callable())
	var peek_cb: Callable = opts.get("peek", Callable())
	var targets: Dictionary = opts.get("targets", {})
	var selected := int(opts.get("selected", -1))
	_markers.clear()
	var deal_order := 0
	for p in view.players:
		var seat := int(p.seat)
		if not _seat_roots.has(seat):
			continue
		var root: Node3D = _seat_roots[seat]
		var list: Array = p.cards
		var cards: Array = _slots[seat]
		while cards.size() < list.size():
			var c = _new_card("hand")
			c.seat = seat
			c.index = cards.size()
			add_child(c)
			c.global_transform = _deck_top.global_transform
			cards.append(c)
		while cards.size() > list.size():
			var gone = cards.pop_back()
			gone.queue_free()
		var n := list.size()
		var gap := CARD_GAP if n <= 5 else CARD_GAP * 5.0 / float(n)
		var seat_targets: Array = targets.get(seat, [])
		for i in range(n):
			var c = cards[i]
			var key := "slot:%d:%d" % [seat, i]
			var show: bool = face_cb.call(seat, i, list[i]) if face_cb.is_valid() else false
			var peeking: bool = peek_cb.call(seat, i) if peek_cb.is_valid() and seat == _viewer else false
			c.set_card(list[i], show, animate and not dealing)
			var local := Transform3D(Basis(), Vector3((i - (n - 1) / 2.0) * gap, TABLE_Y + Card3DScript.T / 2.0 + 0.0008, CARD_R))
			if peeking and show:
				# Kurz anheben und zum Gesicht kippen wie beim Spicken.
				local = Transform3D(Basis(Vector3.RIGHT, 1.05), local.origin + Vector3(0, 0.07, 0.05))
			elif seat == _viewer and i == selected:
				local.origin.y += 0.014
			if bool(p.eliminated):
				local.origin.y -= 0.0005
			var target: Transform3D = root.global_transform * local
			var mode := ""
			if seat == _viewer and i == selected:
				mode = "selected"
			elif seat_targets.has(i):
				mode = "target"
			c.set_marker(mode)
			_markers[key] = mode
			if dealing:
				_move(c, target, 0.32, deal_order * 0.045, _deck_top.global_transform)
				deal_order += 1
			else:
				_move(c, target, 0.38 if from.has(key) else 0.16, 0.0, from.get(key))
		for b in bumps:
			if int(b[0]) == seat and int(b[1]) < cards.size() and not (seat == _viewer and peek_cb.is_valid() and peek_cb.call(seat, int(b[1]))):
				_bump(cards[int(b[1])])
		var pstack: MeshInstance3D = _penalty_stacks[seat]
		var pc := int(p.penalty_count)
		pstack.visible = pc > 0
		if pc > 0:
			(pstack.mesh as BoxMesh).size = Vector3(Card3DScript.W, 0.0016 * pc, Card3DScript.H)
			pstack.position = Vector3((n + 1) / 2.0 * gap + 0.06, TABLE_Y + 0.0008 * pc, CARD_R + 0.02)
			pstack.rotation.y = 0.25
		_update_figure(seat, p)
		if seat == _viewer:
			var txt := "%s  ·  Gesamt %d" % [str(p.name), int(p.total_score)]
			if pc > 0:
				txt += "  ·  Strafe +%d" % pc
			if bool(p.locked):
				txt += "  ·  DAME!"
			_self_label.text = txt

	# Stapel und Ablage.
	var deck_n := int(view.deck_count)
	var deck_h := maxf(0.0004 * deck_n, 0.0004)
	(_deck_stack.mesh as BoxMesh).size = Vector3(Card3DScript.W - 0.001, deck_h, Card3DScript.H - 0.001)
	_deck_stack.position = DECK_POS + Vector3(0, TABLE_Y + deck_h / 2.0, 0)
	_deck_stack.visible = deck_n > 1
	_deck_top.set_card({"known": false} if deck_n > 0 else {}, false, false)
	_deck_top.global_transform = Transform3D(Basis(Vector3.UP, 0.04), DECK_POS + Vector3(0, TABLE_Y + deck_h + Card3DScript.T / 2.0, 0))
	_deck_top.set_marker("target" if bool(opts.get("deck_target", false)) else "")
	_markers["deck"] = "target" if bool(opts.get("deck_target", false)) else ""
	_deck_label.text = "Stapel %d" % deck_n

	var disc_n := int(view.discard_count)
	var disc_h := maxf(0.0004 * maxi(disc_n - 1, 0), 0.0)
	(_discard_stack.mesh as BoxMesh).size = Vector3(Card3DScript.W - 0.001, maxf(disc_h, 0.0004), Card3DScript.H - 0.001)
	_discard_stack.position = DISCARD_POS + Vector3(0, TABLE_Y + disc_h / 2.0, 0)
	_discard_stack.visible = disc_n > 1
	var top = view.discard_top
	_discard_top.set_card(top if top != null else {}, true, false)
	var disc_target := Transform3D(Basis(Vector3.UP, -0.06), DISCARD_POS + Vector3(0, TABLE_Y + disc_h + Card3DScript.T / 2.0 + 0.0004, 0))
	_move(_discard_top, disc_target, 0.36, 0.0, from.get("discard"))
	_discard_top.set_marker("target" if bool(opts.get("discard_target", false)) else "")
	_markers["discard"] = "target" if bool(opts.get("discard_target", false)) else ""
	_discard_label.text = "Ablage %d" % disc_n

	# Gezogene Karte: in der eigenen Hand oder ueber dem Platz des Gegners.
	var drawn = view.drawn
	if drawn != null:
		var holder := int(view.current_index)
		var mine := holder == _viewer
		var face := bool(opts.get("drawn_face", false)) if mine else bool(drawn.known)
		_held.set_card(drawn, face, false)
		_held.visible = true
		var target: Transform3D
		if mine:
			target = _held_pose()
		else:
			var root2: Node3D = _seat_roots.get(holder)
			var basis := Basis(Vector3.RIGHT, PI / 2.0)
			if bool(drawn.known):
				basis = Basis(Vector3.UP, PI) * basis
			target = root2.global_transform * Transform3D(basis, Vector3(0, TABLE_Y + 0.2, FIGURE_R - 0.5)) if root2 != null else _held_pose()
		var delay := 0.2 if hand_plan == "draw" and animate else 0.0
		_move(_held, target, 0.4, delay, from.get("held"))
		_held.set_marker("target" if bool(opts.get("drawn_target", false)) else "")
		_markers["drawn"] = "target" if bool(opts.get("drawn_target", false)) else ""
		_held_seat = holder
	else:
		_held.visible = false
		_held_seat = -1
		_markers["drawn"] = ""
	_apply_hover()
	_plan_hand(hand_plan, hand_target_key)


# Gegner greift sichtbar nach Stapel, Ablage oder Karte (nur Darstellung).
func _figure_reach(seat: int, a: Dictionary) -> void:
	if not _figures.has(seat) or not animate:
		return
	var point := Vector3.INF
	match str(a.get("type", "")):
		"draw_deck":
			point = _deck_top.global_position
		"draw_discard", "discard_drawn", "discard_extra":
			point = _discard_top.global_position
		"swap":
			var c = _slot(seat, int(a.get("hand_index", -1)))
			if c != null:
				point = c.global_position
		"look_card":
			var c2 = _slot(int(a.get("target_seat", -1)), int(a.get("hand_index", -1)))
			if c2 != null:
				point = c2.global_position
		"king_swap":
			var c3 = _slot(int(a.get("opponent_seat", -1)), int(a.get("opponent_index", -1)))
			if c3 != null:
				point = c3.global_position
	if point == Vector3.INF:
		return
	var fig: Node3D = _figures[seat].node
	var dir := point - fig.global_position
	dir.y = 0.0
	dir = dir.normalized()
	var xf := Transform3D(Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, -0.25), point - dir * 0.14 + Vector3(0, 0.05, 0))
	_figures[seat].person.reach(xf)


func _slot(seat: int, index: int):
	var list: Array = _slots.get(seat, [])
	return list[index] if index >= 0 and index < list.size() else null


func _update_figure(seat: int, p: Dictionary) -> void:
	if not _figures.has(seat):
		return
	var f: Dictionary = _figures[seat]
	var tags: Array = []
	if bool(p.is_ai):
		tags.append({"easy": "KI leicht", "medium": "KI mittel", "hard": "KI schwer"}.get(str(p.difficulty), "KI"))
	tags.append("%d Pkt" % int(p.total_score))
	if int(p.penalty_count) > 0:
		tags.append("Strafe +%d" % int(p.penalty_count))
	var title := ("▶ " if bool(p.is_current) else "") + str(p.name)
	if bool(p.locked):
		title += "  DAME!"
	var label: Label3D = f.label
	label.text = title + "\n" + " · ".join(PackedStringArray(tags))
	label.modulate = accent if bool(p.is_current) else (Color(1, 1, 1, 0.4) if bool(p.eliminated) else Color(0.92, 0.9, 0.86))
	(f.glow as OmniLight3D).light_energy = 0.9 if bool(p.is_current) else 0.0
	(f.node as Node3D).visible = true


func _pulse_figure(seat: int) -> void:
	if not _figures.has(seat) or not animate:
		return
	var label: Label3D = _figures[seat].label
	var tw := label.create_tween()
	tw.tween_property(label, "scale", Vector3.ONE * 1.5, 0.15)
	tw.tween_property(label, "scale", Vector3.ONE, 0.35)


# ---------------------------------------------------------------- Bewegung

func _move(n: Node3D, target: Transform3D, dur: float, delay: float = 0.0, from = null) -> void:
	if n.has_meta("tw"):
		var old = n.get_meta("tw")
		if old is Tween and old.is_valid():
			old.kill()
		n.remove_meta("tw")
	if not n.is_inside_tree():
		n.transform = target
		return
	if from != null:
		n.global_transform = from
	var start := n.global_transform
	if not animate or dur <= 0.0 or (start.origin.distance_to(target.origin) < 0.0005 and start.basis.is_equal_approx(target.basis)):
		n.global_transform = target
		return
	# Weite Wege fliegen im Bogen.
	var arc := clampf(start.origin.distance_to(target.origin) * 0.25, 0.0, 0.08)
	var tw := n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(f: float) -> void:
		var xf := start.interpolate_with(target, f)
		xf.origin.y += sin(f * PI) * arc
		n.global_transform = xf, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	n.set_meta("tw", tw)


func _bump(n: Node3D) -> void:
	if not animate:
		return
	var base := n.global_transform
	var up := base
	up.origin.y += 0.06
	var tw := n.create_tween()
	tw.tween_interval(0.38)
	tw.tween_method(func(f: float) -> void: n.global_transform = base.interpolate_with(up, f), 0.0, 1.0, 0.18)
	tw.tween_interval(0.45)
	tw.tween_method(func(f: float) -> void: n.global_transform = up.interpolate_with(base, f), 0.0, 1.0, 0.2)


# Gehaltene Karte vor der Kamera, Gesicht zum Spieler.
func _held_pose() -> Transform3D:
	var local := Transform3D(Basis(Vector3.BACK, -0.14) * Basis(Vector3.RIGHT, PI / 2.0 - 0.12), Vector3(0.115, -0.045, -0.31))
	return camera.global_transform * local


func _hand_rest() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, -0.05), Vector3(0.33, TABLE_Y + 0.032, 0.66))


# Hand schwebt ueber einem Punkt, Fingerspitzen darauf, Blickrichtung wie die Kamera.
func _hand_over(point: Vector3) -> Transform3D:
	var cam := camera.global_position
	var f := Vector3(point.x - cam.x, 0.0, point.z - cam.z).normalized()
	var basis := Basis.looking_at(f, Vector3.UP) * Basis(Vector3.RIGHT, -0.3)
	var wrist := point - f * 0.15 + Vector3(0, 0.07, 0)
	return Transform3D(basis, wrist)


# Hand haelt die Karte von rechts unten: Handruecken zum Spieler, Daumen vorn.
func _hand_hold() -> Transform3D:
	var card := _held_pose()
	var cam_basis := camera.global_transform.basis
	var dir := cam_basis * Vector3(-0.3, 0.85, -0.45)
	var zf := -dir.normalized()
	var y0 := cam_basis * Vector3(0, 0, 1)
	var x := y0.cross(zf).normalized()
	var y := zf.cross(x)
	var wrist := card.origin + cam_basis * Vector3(0.045, -0.105, 0.0)
	return Transform3D(Basis(x, y, zf), wrist)


func _key_transform(key: String) -> Transform3D:
	if key == "deck":
		return _deck_top.global_transform
	if key == "discard":
		return _discard_top.global_transform
	var parts := key.split(":")
	if parts.size() == 3:
		var c = _slot(int(parts[1]), int(parts[2]))
		if c != null:
			# Ziel der laufenden Bewegung ist die Ruheposition des Platzes.
			var root: Node3D = _seat_roots.get(int(parts[1]))
			var list: Array = _slots[int(parts[1])]
			var n := list.size()
			var gap := CARD_GAP if n <= 5 else CARD_GAP * 5.0 / float(n)
			if root != null:
				return root.global_transform * Transform3D(Basis(), Vector3((int(parts[2]) - (n - 1) / 2.0) * gap, TABLE_Y, CARD_R))
			return c.global_transform
	return _deck_top.global_transform


func _plan_hand(plan: String, key: String) -> void:
	var holding: bool = _held.visible and _held_seat == _viewer
	var want := "hold" if holding else "rest"
	if plan == "" and want == _hand_state:
		return
	if _hand_tw != null and _hand_tw.is_valid():
		_hand_tw.kill()
	_hand_state = want
	var final_xf := _hand_hold() if holding else _hand_rest()
	if not animate:
		hand.transform = final_xf
		hand.set_pose(want)
		return
	_hand_tw = hand.create_tween()
	_hand_cursor = hand.transform
	var target_xf := _key_transform(key) if key != "" else final_xf
	match plan:
		"draw":
			_hand_step(_hand_over(target_xf.origin), "reach", 0.2)
			_hand_step(final_xf, want, 0.4)
		"place":
			_hand_step(_hand_over(target_xf.origin), "pinch", 0.36)
			_hand_step(_hand_over(target_xf.origin).translated(Vector3(0, 0.03, 0)), "reach", 0.12)
			_hand_step(final_xf, want, 0.35)
		"tap":
			_hand_step(_hand_over(target_xf.origin), "reach", 0.28)
			_hand_step(_hand_over(target_xf.origin).translated(Vector3(0, 0.025, 0)), "reach", 0.16)
			_hand_step(final_xf, want, 0.35)
		_:
			_hand_step(final_xf, want, 0.3)


func _hand_step(xf: Transform3D, pose: String, dur: float) -> void:
	_hand_tw.tween_callback(func() -> void: hand.set_pose(pose))
	var a := _hand_cursor
	_hand_cursor = xf
	_hand_tw.tween_method(func(f: float) -> void:
		hand.transform = a.interpolate_with(xf, f), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------------------------------------------------------------- Auswahl mit der Maus

# Ergebnis: {"kind": "card", "seat", "index"} | {"kind": "deck"} | {"kind": "discard"} | {"kind": "drawn"} | {}.
func pick(screen_pos: Vector2) -> Dictionary:
	if not _built:
		return {}
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var best := {}
	var best_d := INF
	var cands: Array = []
	if _held.visible and _held_seat == _viewer:
		cands.append([_held, {"kind": "drawn"}])
	cands.append([_discard_top, {"kind": "discard"}])
	cands.append([_deck_top, {"kind": "deck"}])
	for seat in _slots:
		var list: Array = _slots[seat]
		for i in range(list.size()):
			cands.append([list[i], {"kind": "card", "seat": int(seat), "index": i}])
	for c in cands:
		var d: float = c[0].hit(origin, dir)
		if d >= 0.0 and d < best_d:
			best_d = d
			best = c[1]
	return best


func set_hover(info: Dictionary) -> void:
	_hover = info
	_apply_hover()


func _apply_hover() -> void:
	var hk := _hover_key(_hover)
	for seat in _slots:
		var list: Array = _slots[seat]
		for i in range(list.size()):
			var key := "slot:%d:%d" % [seat, i]
			var mode := str(_markers.get(key, ""))
			if key == hk and mode == "target":
				mode = "hover"
			list[i].set_marker(mode)
	for pair in [["deck", _deck_top], ["discard", _discard_top], ["drawn", _held]]:
		var mode2 := str(_markers.get(pair[0], ""))
		if pair[0] == hk and mode2 == "target":
			mode2 = "hover"
		pair[1].set_marker(mode2)


static func _hover_key(info: Dictionary) -> String:
	match str(info.get("kind", "")):
		"card":
			return "slot:%d:%d" % [int(info.seat), int(info.index)]
		"deck", "discard", "drawn":
			return str(info.kind)
	return ""


# Fuer Tests: Anzahl aller Kartenobjekte im Raum.
func card_node_count() -> int:
	var n := 0
	for c in get_children():
		if c.get_script() == Card3DScript and not c.is_queued_for_deletion():
			n += 1
	return n


func is_target(info: Dictionary) -> bool:
	var k := _hover_key(info)
	return k != "" and str(_markers.get(k, "")) != ""


# Hot-Seat-Uebergabe: nichts Verdecktes darf offen bleiben.
func clear_faces() -> void:
	for seat in _slots:
		for c in _slots[seat]:
			c.set_card(c.card, false, false)
	_held.set_card(_held.card, false, false)
