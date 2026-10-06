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
		b.pressed.connect(func() -> void: buy(id))
	item_buttons[id] = b
	vb.add_child(b)
	return panel


func _preview(it: Dictionary, app) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(150, 96)
	match str(it.category):
		"card_back":
			var cv = CardViewScript.new()
			cv.setup(true)
			cv.accent = app.accent()
			cv.back_style = str(it.data.back_style)
			cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cv.focus_mode = Control.FOCUS_NONE
			cv.set_card({"known": false}, false)
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
