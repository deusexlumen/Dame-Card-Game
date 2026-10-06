extends "res://scripts/screens/screen_base.gd"

# Shop: nur Kosmetik. Kauft ueber PurchaseProvider (aktiv: Chips).
# Echtgeld ist als Platzhalter sichtbar, aber ohne Funktion.

const CatalogScript = preload("res://scripts/services/catalog.gd")
const PurchaseProviderScript = preload("res://scripts/services/purchase_provider.gd")
const CardViewScript = preload("res://scripts/ui/card_view.gd")

var provider = PurchaseProviderScript.ChipProvider.new()
var real_money = PurchaseProviderScript.RealMoneyProviderStub.new()
var chips_label: Label
var message: Label
var lists := {}
var item_buttons := {}
var confirm_panel: PanelContainer
var _confirm_label: Label
var _confirm_ok: Button
var _pending_id := ""

func build() -> void:
	frame("Shop", 980)
	chips_label = label("", 22)
	content.add_child(chips_label)
	content.add_child(label("Chips verdienst du durch Spielen: %d pro Ausgabe, %d für eine richtige Dame-Ansage, %d für einen Sieg (doppelt gegen KI Schwer). Alles hier ist rein optisch." % [CatalogScript.REWARD_ROUND, CatalogScript.REWARD_CORRECT_CALL, CatalogScript.REWARD_WIN], 14))
	message = label("", 16)
	content.add_child(message)
	for cat in CatalogScript.CATEGORIES:
		content.add_child(label(str(CatalogScript.CATEGORIES[cat]), 20))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 12)
		content.add_child(flow)
		lists[cat] = flow
	var rm := Button.new()
	rm.text = "Chip-Pakete mit Echtgeld – bald verfügbar"
	rm.disabled = not real_money.available()
	content.add_child(rm)
	_build_confirm()
	refresh()
	back_button.grab_focus()


func refresh() -> void:
	var app := app_node()
	if app == null:
		return
	var profile = app.profile
	chips_label.text = "Kontostand: %d Chips" % profile.chips()
	item_buttons.clear()
	for cat in lists:
		var flow: HFlowContainer = lists[cat]
		for c in flow.get_children():
			flow.remove_child(c)
			c.queue_free()
		for it in CatalogScript.items_in(cat):
			flow.add_child(_item_card(it, profile, app))


func _item_card(it: Dictionary, profile, app) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(170, 0)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	vb.add_child(_preview(it, app))
	var name := label(str(it.name), 16)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(name)
	var id := str(it.id)
	var b := Button.new()
	if profile.equipped(str(it.category)) == id:
		b.text = "Ausgerüstet"
		b.disabled = true
	elif profile.owns(id):
		b.text = "Ausrüsten"
		b.pressed.connect(func() -> void: equip(id))
	else:
		b.text = "%d Chips" % int(it.price)
		b.disabled = profile.chips() < int(it.price)
		b.tooltip_text = "Kaufen"
		b.pressed.connect(func() -> void: ask_buy(id))
	item_buttons[id] = b
	vb.add_child(b)
	return panel


func _preview(it: Dictionary, app) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(150, 110)
	match str(it.category):
		"card_back", "card_face":
			var cv = CardViewScript.new()
			cv.setup(true)
			cv.accent = app.accent()
			cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cv.focus_mode = Control.FOCUS_NONE
			if str(it.category) == "card_back":
				cv.back_style = str(it.data.skin)
				cv.set_card({"known": false}, false)
			else:
				cv.face_skin = str(it.data.skin)
				cv.lang = app.language()
				cv.set_card({"known": true, "rank": "Q", "suit": "hearts", "value": 0}, true)
			holder.add_child(cv)
		_:
			var sw := ColorRect.new()
			sw.custom_minimum_size = Vector2(120, 70)
			sw.color = Color(str(it.data.color))
			holder.add_child(sw)
	return holder


func buy(id: String) -> void:
	var app := app_node()
	if app == null:
		return
	var it := CatalogScript.item(id)
	var result: Dictionary = provider.buy(it, app.profile)
	message.text = str(result.reason)
	app.audio.play("win" if bool(result.ok) else "error")
	if bool(result.ok):
		app.profile.equip(id)
	refresh()


func equip(id: String) -> void:
	var app := app_node()
	if app == null:
		return
	app.profile.equip(id)
	message.text = "Ausgerüstet: %s" % str(CatalogScript.item(id).name)
	refresh()


# Kaufbestaetigung: erst nachfragen, dann ueber den PurchaseProvider abbuchen.
func _build_confirm() -> void:
	confirm_panel = PanelContainer.new()
	confirm_panel.visible = false
	confirm_panel.position = Vector2(440, 270)
	confirm_panel.custom_minimum_size = Vector2(400, 0)
	add_child(confirm_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	confirm_panel.add_child(vb)
	_confirm_label = label("", 18)
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_confirm_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	vb.add_child(row)
	_confirm_ok = button("Kaufen", confirm_buy)
	row.add_child(_confirm_ok)
	row.add_child(button("Abbrechen", cancel_buy))


func ask_buy(id: String) -> void:
	var it := CatalogScript.item(id)
	if it.is_empty():
		return
	_pending_id = id
	_confirm_label.text = "„%s“ für %d Chips kaufen?" % [str(it.name), int(it.price)]
	confirm_panel.visible = true
	confirm_panel.reset_size()
	_confirm_ok.grab_focus()


func confirm_buy() -> void:
	var id := _pending_id
	cancel_buy()
	if id != "":
		buy(id)


func cancel_buy() -> void:
	_pending_id = ""
	if confirm_panel != null:
		confirm_panel.visible = false
