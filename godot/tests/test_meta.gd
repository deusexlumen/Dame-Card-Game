extends RefCounted

# M4-M6: Dienste (Einstellungen, Statistik, Spielstand, Profil), Shop, Audio, Bildschirme.

const SettingsServiceScript = preload("res://scripts/services/settings_service.gd")
const StatsServiceScript = preload("res://scripts/services/stats_service.gd")
const SaveServiceScript = preload("res://scripts/services/save_service.gd")
const ProfileServiceScript = preload("res://scripts/services/profile_service.gd")
const CatalogScript = preload("res://scripts/services/catalog.gd")
const PurchaseProviderScript = preload("res://scripts/services/purchase_provider.gd")
const AudioServiceScript = preload("res://scripts/services/audio_service.gd")
const DameRulesScript = preload("res://scripts/dame_rules.gd")

var t
var app

func run(ctx) -> void:
	t = ctx
	app = ctx.root.get_node_or_null("/root/App")
	_check_settings_service()
	_check_stats_service()
	_check_save_service()
	_check_profile_and_shop()
	_check_audio()
	if app != null:
		_check_screens()


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _clean(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func _check_settings_service() -> void:
	var path := "user://t_meta_settings.json"
	_clean(path)
	var s = SettingsServiceScript.new(path)
	t.expect(bool(s.get_value("memory_aid")), "Standard Gedaechtnishilfe nicht an")
	t.expect(s.set_value("ai_speed", "fast"), "gueltiger Wert abgelehnt")
	t.expect(not s.set_value("ai_speed", "turbo"), "ungueltiger Wert angenommen")
	t.expect(not s.set_value("turn_timer_seconds", 17), "ungueltige Zugzeit angenommen")
	t.expect(not s.set_value("unbekannt", 1), "unbekannter Schluessel angenommen")
	t.expect(s.set_value("music_volume", 250) and int(s.get_value("music_volume")) == 100, "Lautstaerke nicht begrenzt")
	var again = SettingsServiceScript.new(path)
	t.expect(str(again.get_value("ai_speed")) == "fast", "Einstellung nicht gespeichert")
	t.expect(is_equal_approx(again.ai_delay(), 0.3), "KI-Tempo falsch")
	_write(path, "{kaputt")
	var broken = SettingsServiceScript.new(path)
	t.expect(str(broken.get_value("ai_speed")) == "normal", "kaputte Datei liefert keine Standardwerte")
	t.expect(FileAccess.file_exists(path + ".bak"), "kaputte Einstellungen nicht gesichert")
	_write(path, '{"ai_speed": 5, "memory_aid": "ja", "player_name": "   "}')
	var odd = SettingsServiceScript.new(path)
	t.expect(str(odd.get_value("ai_speed")) == "normal" and bool(odd.get_value("memory_aid")), "falsche Typen nicht verworfen")
	t.expect(str(odd.get_value("player_name")) == "Spieler", "leerer Name angenommen")
	_clean(path)


func _check_stats_service() -> void:
	var path := "user://t_meta_stats.json"
	_clean(path)
	var s = StatsServiceScript.new(path)
	s.record_round(12, true, true, 1)
	s.record_round(8, true, false, 2)
	s.record_game(true)
	s.record_game(false)
	var again = StatsServiceScript.new(path)
	t.expect(int(again.values.rounds_played) == 2, "Ausgaben nicht gezaehlt")
	t.expect(int(again.values.dame_calls) == 2 and int(again.values.successful_dame_calls) == 1, "Ansagen falsch gezaehlt")
	t.expect(int(again.values.total_penalty_cards) == 3, "Strafkarten falsch")
	t.expect(int(again.values.best_round_score) == 8, "beste Ausgabe falsch")
	t.expect(is_equal_approx(again.win_rate(), 0.5), "Siegquote falsch")
	t.expect(str(again.values.last_played_at) != "", "Zeitstempel fehlt")
	again.reset()
	t.expect(int(StatsServiceScript.new(path).values.games_played) == 0, "Zuruecksetzen wirkt nicht")
	_clean(path)


func _check_save_service() -> void:
	var path := "user://t_meta_save.dat"
	_clean(path)
	var s = SaveServiceScript.new(path)
	t.expect(not s.has_save(), "leerer Speicher meldet Spielstand")
	var rules = DameRulesScript.new()
	rules.start_match({"seed": 5})
	t.expect(s.save_match(rules.to_dict(), {"config": {"seed": 5}}), "Speichern scheitert")
	var data: Dictionary = s.load_match()
	var copy = DameRulesScript.new()
	t.expect(copy.from_dict(data.rules), "gespeicherter Stand nicht ladbar")
	t.expect(int(copy.state.players[0].hand[0].value) == int(rules.state.players[0].hand[0].value), "Typen nach Laden falsch")
	t.expect(typeof(copy.state.players[0].known[0]) == TYPE_INT, "int wurde zu float")
	_write(path, "Unsinn")
	t.expect(s.load_match().is_empty() and not s.has_save(), "kaputter Spielstand gilt als gueltig")
	s.clear()
	t.expect(not FileAccess.file_exists(path), "Spielstand nicht geloescht")
	_clean(path)


func _check_profile_and_shop() -> void:
	var path := "user://t_meta_profile.json"
	_clean(path)
	var p = ProfileServiceScript.new(path)
	for cat in CatalogScript.CATEGORIES:
		var def: String = CatalogScript.default_for(cat)
		t.expect(def != "" and p.owns(def) and p.equipped(cat) == def, "Gratis-Standard fehlt: " + cat)
	t.expect(p.award("e1", 30), "Belohnung nicht gutgeschrieben")
	t.expect(not p.award("e1", 30), "Belohnung doppelt gutgeschrieben")
	t.expect(p.chips() == 30, "Kontostand falsch")
	var chip = PurchaseProviderScript.ChipProvider.new()
	var item: Dictionary = CatalogScript.item("back_diagonal")
	var r1: Dictionary = chip.buy(item, p)
	t.expect(not bool(r1.ok) and p.chips() == 30 and not p.owns("back_diagonal"), "Kauf ohne genug Chips moeglich")
	t.expect(not p.equip("back_diagonal"), "nicht gekaufter Artikel ausruestbar")
	p.award("e2", 200)
	var r2: Dictionary = chip.buy(item, p)
	t.expect(bool(r2.ok) and p.owns("back_diagonal") and p.chips() == 230 - int(item.price), "Kauf fehlgeschlagen")
	t.expect(not bool(chip.buy(item, p).ok), "doppelter Kauf moeglich")
	t.expect(p.equip("back_diagonal") and p.equipped("card_back") == "back_diagonal", "Ausruesten scheitert")
	var real = PurchaseProviderScript.RealMoneyProviderStub.new()
	var before: int = p.chips()
	var r3: Dictionary = real.buy(CatalogScript.item("accent_magenta"), p)
	t.expect(not bool(r3.ok) and not real.available() and p.chips() == before and not p.owns("accent_magenta"), "Echtgeld-Stub kauft etwas")
	var again = ProfileServiceScript.new(path)
	t.expect(again.chips() == p.chips() and again.equipped("card_back") == "back_diagonal", "Profil nicht gespeichert")
	t.expect(not again.award("e1", 30), "Ereignis-ID nach Neustart vergessen")
	_write(path, '{"chips": -50, "owned": ["gibtsnicht", "accent_magenta"], "equipped": {"accent": "accent_bernstein", "table": "back_raster"}}')
	var odd = ProfileServiceScript.new(path)
	t.expect(odd.chips() == 0, "negative Chips angenommen")
	t.expect(not odd.owns("gibtsnicht"), "unbekannter Artikel im Besitz")
	t.expect(odd.equipped("accent") == "accent_gruen", "nicht besessener Artikel ausgeruestet")
	t.expect(odd.equipped("table") == "table_schwarz", "Artikel aus falscher Kategorie ausgeruestet")
	_write(path, "nicht json")
	var broken = ProfileServiceScript.new(path)
	t.expect(broken.chips() == 0 and FileAccess.file_exists(path + ".bak"), "kaputtes Profil nicht gesichert")
	for it in CatalogScript.ITEMS:
		t.expect(int(it.price) >= 0 and CatalogScript.CATEGORIES.has(str(it.category)), "Katalogeintrag ungueltig: " + str(it.id))
	_clean(path)


func _check_audio() -> void:
	var audio = AudioServiceScript.new()
	t.root.add_child(audio)
	for name in AudioServiceScript.SOUNDS:
		t.expect(audio._streams.has(name), "Sound fehlt: " + name)
	t.expect(audio._music.stream != null, "Musik fehlt")
	t.expect(audio._music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Musik laeuft nicht in Schleife")
	t.expect(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0, "Audiobusse fehlen")
	audio.play("draw")
	audio.play("gibtsnicht")
	t.root.remove_child(audio)
	audio.free()


func _scene(path: String):
	var s = load(path).instantiate()
	t.root.add_child(s)
	return s


func _drop(s) -> void:
	t.root.remove_child(s)
	s.free()


func _check_screens() -> void:
	app.saves.clear()
	var menu = _scene(app.MAIN_MENU)
	t.expect(not menu.resume_button.visible, "Fortsetzen ohne Spielstand sichtbar")
	t.expect(menu.buttons.size() >= 7, "Menue unvollstaendig")
	_drop(menu)
	var rules = DameRulesScript.new()
	rules.start_match({"seed": 3})
	app.saves.save_match(rules.to_dict(), {"config": {}})
	menu = _scene(app.MAIN_MENU)
	t.expect(menu.resume_button.visible, "Fortsetzen trotz Spielstand unsichtbar")
	_drop(menu)
	app.saves.clear()

	app.pending = {"setup_mode": "hotseat"}
	var setup = _scene(app.SETUP)
	t.expect(setup.mode == "hotseat" and setup.seat_count() == 2, "Hot-Seat-Setup falsch")
	var cfg: Dictionary = setup.build_config()
	t.expect(cfg.ai_seats.is_empty() and cfg.names.size() == 2, "Hot-Seat ohne zwei Menschen")
	setup.seat_option.select(2)
	setup._rebuild_rows()
	setup.rows[1].kind.select(1)
	setup.rows[1].name.text = setup.rows[0].name.text
	t.expect(setup.build_config().is_empty() and "doppelt" in setup.error_label.text, "doppelter Name angenommen")
	setup.rows[1].name.text = "  "
	t.expect(setup.build_config().is_empty(), "leerer Name angenommen")
	setup.rows[1].name.text = "Robo"
	setup.rows[1].difficulty.select(2)
	cfg = setup.build_config()
	t.expect(cfg.seat_count == 4 and cfg.ai_seats == [1, 2, 3] and str(cfg.difficulties[1]) == "hard", "Setup-Konfiguration falsch: " + str(cfg))
	setup.start_game()
	t.expect(app.last_goto == app.TABLE and str(app.pending.mode) == "new", "Start fuehrt nicht zum Tisch")
	app.pending = {}
	_drop(setup)

	var settings = _scene(app.SETTINGS)
	var memo: Button = settings.controls["memory_aid"]
	memo.button_pressed = false
	t.expect(not bool(app.settings.get_value("memory_aid")), "Schalter speichert nicht")
	t.expect(memo.text == "AUS", "Schalter zeigt falschen Text")
	settings.controls["ai_speed"].select(2)
	settings.controls["ai_speed"].item_selected.emit(2)
	t.expect(str(app.settings.get_value("ai_speed")) == "fast", "Auswahl speichert nicht")
	memo.button_pressed = true
	_drop(settings)

	var stats = _scene(app.STATS)
	app.stats.record_game(true)
	stats.refresh()
	stats.reset_stats()
	t.expect(int(app.stats.values.games_played) == 0, "Statistik-Reset wirkt nicht")
	_drop(stats)

	var shop = _scene(app.SHOP)
	var accent_before: Color = app.accent()
	t.expect(shop.item_buttons["accent_bernstein"].disabled, "Kaufen ohne Chips moeglich")
	app.profile.award("shoptest", 500)
	shop.refresh()
	shop.buy("accent_bernstein")
	t.expect(app.profile.owns("accent_bernstein") and app.profile.equipped("accent") == "accent_bernstein", "Shop-Kauf scheitert")
	t.expect(app.accent() != accent_before, "Akzentfarbe aendert sich nicht")
	t.expect(app.get_tree().root.theme != null, "kein Theme gesetzt")
	shop.equip("accent_gruen")
	t.expect(app.profile.equipped("accent") == "accent_gruen", "Zurueckwechseln scheitert")
	_drop(shop)

	var rules_screen = _scene(app.RULES)
	t.expect("König" in rules_screen.text_label.text and "Strafkarte" in rules_screen.text_label.text, "Regeltext unvollstaendig")
	_drop(rules_screen)
