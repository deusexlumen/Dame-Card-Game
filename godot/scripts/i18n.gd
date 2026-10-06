extends RefCounted

# Deutsch und Englisch (CONCEPT_DECISIONS §9). Deutscher Text ist der Schluessel.
# install() meldet die Tabelle bei Godots TranslationServer an: Labels und Buttons
# uebersetzen sich dann selbst. Formatierte Texte laufen ueber tr()/t() vor dem
# Einsetzen der Werte; Protokollzeilen der Regeln ueber line() (Muster mit %s/%d).

static var lang := "de"
static var _patterns: Array = []

const EN := {
	# Allgemein und Menues
	"Das Kartenspiel mit Gedächtnis und Bluff": "The card game of memory and bluff",
	"Spiel fortsetzen": "Continue game",
	"Gegen die KI spielen": "Play against the AI",
	"Hot-Seat (mehrere Menschen)": "Hot seat (several people)",
	"Regeln": "Rules",
	"Shop": "Shop",
	"Statistik": "Statistics",
	"Einstellungen": "Settings",
	"Beenden": "Quit",
	"Version %s": "Version %s",
	"%d Chips": "%d chips",
	"Zurück [Esc]": "Back [Esc]",
	"Menü [Esc]": "Menu [Esc]",
	"Hilfe [H]": "Help [H]",
	"Anleitung": "How to play",
	"Schließen [H]": "Close [H]",
	# Einstellungen
	"Langsam": "Slow",
	"Normal": "Normal",
	"Schnell": "Fast",
	"Ton": "Sound",
	"Soundeffekte": "Sound effects",
	"Lautstärke Effekte": "Effects volume",
	"Musik": "Music",
	"Lautstärke Musik": "Music volume",
	"Spiel": "Game",
	"KI-Tempo": "AI speed",
	"Standard-KI-Stufe": "Default AI level",
	"Einfach": "Easy",
	"Mittel": "Medium",
	"Schwer": "Hard",
	"Gedächtnishilfe (bekannte Karten bleiben offen)": "Memory aid (known cards stay face up)",
	"Zugtimer": "Turn timer",
	"Zeit pro Zug": "Time per turn",
	"15 Sekunden": "15 seconds",
	"30 Sekunden": "30 seconds",
	"60 Sekunden": "60 seconds",
	"Dein Name": "Your name",
	"Darstellung": "Display",
	"3D-Tisch (Egoperspektive)": "3D table (first person)",
	"Animationen": "Animations",
	"Vollbild": "Fullscreen",
	"Sprache": "Language",
	"Deutsch": "German",
	"Englisch": "English",
	"AN": "ON",
	"AUS": "OFF",
	# Setup
	"Hot-Seat": "Hot seat",
	"Hot-Seat: mehrere Menschen teilen sich ein Gerät. Vor jedem Zug wird der Tisch abgedeckt.": "Hot seat: several people share one device. The table is covered before every turn.",
	"Du spielst gegen KI-Gegner. Schwer gibt doppelte Sieg-Chips.": "You play against AI opponents. Hard gives double win chips.",
	"Spiel einrichten": "Set up game",
	"2 Plätze": "2 seats",
	"3 Plätze": "3 seats",
	"4 Plätze": "4 seats",
	"5 Plätze": "5 seats",
	"6 Plätze": "6 seats",
	"Anzahl Plätze": "Number of seats",
	"Spiel starten": "Start game",
	"Mensch": "Human",
	"KI": "AI",
	"Platz %d": "Seat %d",
	"Spieler %d": "Player %d",
	"Platz %d braucht einen Namen.": "Seat %d needs a name.",
	"Der Name „%s“ ist doppelt.": "The name “%s” is used twice.",
	"Mindestens ein Mensch muss mitspielen.": "At least one human has to play.",
	# Shop
	"Kartenrücken": "Card backs",
	"Kartenvorderseite": "Card faces",
	"Tischfilz": "Table felt",
	"Klassisch": "Classic",
	"Vierfarben": "Four colours",
	"Art déco": "Art deco",
	"Smaragd": "Emerald",
	"Karo": "Diamonds",
	"Casino-Grün": "Casino green",
	"Mitternachtsblau": "Midnight blue",
	"Anthrazit": "Charcoal",
	"Chips verdienst du durch Spielen: %d pro Ausgabe, %d für eine richtige Dame-Ansage, %d für einen Sieg (doppelt gegen KI Schwer). Alles hier ist rein optisch.": "You earn chips by playing: %d per deal, %d for a correct Dame call, %d for a win (double against hard AI). Everything here is cosmetic only.",
	"Chip-Pakete mit Echtgeld – bald verfügbar": "Chip packs for real money – coming soon",
	"Kontostand: %d Chips": "Balance: %d chips",
	"Ausgerüstet": "Equipped",
	"Ausrüsten": "Equip",
	"Kaufen": "Buy",
	"Ausgerüstet: %s": "Equipped: %s",
	"Abbrechen": "Cancel",
	"„%s“ für %d Chips kaufen?": "Buy “%s” for %d chips?",
	"%d Chips kaufen": "%d chips",
	"Kein Kaufweg verfügbar": "No way to buy available",
	"Schon im Besitz": "Already owned",
	"Nicht genug Chips": "Not enough chips",
	"Gekauft: %s": "Bought: %s",
	"Echtgeld-Käufe sind in dieser Version nicht verfügbar": "Real-money purchases are not available in this version",
	# Statistik
	"Gezählt werden Partien gegen die KI. Hot-Seat-Partien zählen nicht.": "Only games against the AI count. Hot seat games do not.",
	"Statistik zurücksetzen": "Reset statistics",
	"Wirklich alles löschen?": "Really delete everything?",
	"Ja, zurücksetzen": "Yes, reset",
	"Partien gespielt": "Games played",
	"Partien gewonnen": "Games won",
	"Siegquote": "Win rate",
	"Ausgaben gespielt": "Deals played",
	"Dame gerufen": "Dame called",
	"davon richtig": "of which correct",
	"Strafkarten": "Penalty cards",
	"Beste Ausgabe": "Best deal",
	"%d Punkte": "%d points",
	"Zuletzt gespielt": "Last played",
	# Tisch: Hinweise und Knoepfe
	"Spiel fortgesetzt.": "Game resumed.",
	"Nächste Ausgabe [Enter]": "Next deal [Enter]",
	"Neues Spiel": "New game",
	"Hauptmenü": "Main menu",
	"Pause": "Pause",
	"Weiterspielen": "Continue",
	"Hauptmenü (Spiel wird gespeichert)": "Main menu (game is saved)",
	"Gerät an %s weitergeben.\nNiemand sonst schaut hin.": "Pass the device to %s.\nNobody else looks.",
	"Ich bin %s – Karten zeigen [Enter]": "I am %s – show cards [Enter]",
	"Nicht bereit": "Not ready",
	"König: angesehen %s, dann blind getauscht.": "King: looked at %s, then swapped blind.",
	"Erst eine eigene Karte wählen.": "Pick one of your own cards first.",
	"Zeit abgelaufen – Strafkarte, Zug beendet.": "Time is up – penalty card, turn ended.",
	"Stapel (%d)": "Deck (%d)",
	"Ablage (%d)": "Discard (%d)",
	"Stapel %d": "Deck %d",
	"Ablage %d": "Discard %d",
	"Stapel": "Deck",
	"Ablage": "Discard",
	"Gezogen": "Drawn",
	"Ausgabe %d": "Deal %d",
	"Runde %d": "Round %d",
	"Safe Phase (Dame ab Runde 3)": "Safe phase (Dame from round 3)",
	"DAME gerufen – noch %d Züge": "DAME called – %d turns left",
	"Ausgabe vorbei. Alle Karten liegen offen.": "Deal over. All cards are face up.",
	"Spiel vorbei.": "Game over.",
	"%s ist am Zug …": "%s is playing …",
	"%s ist am Zug.": "It is %s's turn.",
	"Offene Dame! Du musst sie von der Ablage nehmen.": "Open queen! You must take it from the discard pile.",
	"Ziehe vom Stapel [Leertaste] oder nimm die Ablage.": "Draw from the deck [Space] or take the discard.",
	" Oder rufe Dame [D].": " Or call Dame [D].",
	"Klicke eine eigene Karte zum Tauschen oder lege die gezogene ab [A].": "Click one of your cards to swap, or discard the drawn card [A].",
	"Bube: Klicke eine verdeckte Karte zum Ansehen.": "Jack: click a face-down card to look at it.",
	"König: Wähle eine eigene Karte (du siehst sie, dann wird sie getauscht).": "King: pick one of your cards (you see it, then it is swapped).",
	"König: Wähle jetzt eine Karte eines Gegners.": "King: now pick an opponent's card.",
	"Gleicher Rang wie die Ablage? Karte klicken (falsch = Strafkarte). Sonst Zug beenden [Enter].": "Same rank as the discard? Click the card (wrong = penalty card). Otherwise end turn [Enter].",
	"Vom Stapel ziehen": "Draw from deck",
	"Ablage nehmen": "Take discard",
	"Dame rufen": "Call Dame",
	"Aussetzen (nichts zu ziehen)": "Pass (nothing to draw)",
	"Gezogene ablegen": "Discard drawn card",
	"Auswahl aufheben": "Clear selection",
	"Zug beenden": "End turn",
	"[b]Du hast dich verrechnet![/b] Strafkarte in der nächsten Ausgabe.": "[b]You miscounted![/b] Penalty card in the next deal.",
	"[b]%s hat sich verrechnet![/b] Strafkarte in der nächsten Ausgabe.": "[b]%s miscounted![/b] Penalty card in the next deal.",
	"[b]Du hast Dame richtig gerufen![/b]": "[b]You called Dame correctly![/b]",
	"[b]%s hat Dame richtig gerufen.[/b]": "[b]%s called Dame correctly.[/b]",
	"Spieler          Ausgabe  Gesamt": "Player           Deal     Total",
	"  raus": "  out",
	"Über 50 scheidet aus, genau 50 setzt auf 0.": "Over 50 is out, exactly 50 resets to 0.",
	"[b]Du gewinnst![/b]": "[b]You win![/b]",
	"[b]%s gewinnt![/b]": "[b]%s wins![/b]",
	"%d. %-16s %4d Punkte%s": "%d. %-16s %4d points%s",
	"  (raus)": "  (out)",
	"Verdient in dieser Partie: %d Chips": "Earned this game: %d chips",
	"+%d Chips": "+%d chips",
	"%s  ·  Gesamt %d": "%s  ·  Total %d",
	"  ·  Strafe +%d": "  ·  Penalty +%d",
	"  ·  DAME!": "  ·  DAME!",
	"KI leicht": "AI easy",
	"KI mittel": "AI medium",
	"KI schwer": "AI hard",
	"%d Pkt": "%d pts",
	"Strafe +%d": "Penalty +%d",
	"Gesamt %d": "Total %d",
	"Verdeckte Karte": "Face-down card",
	"%s %s (%d Punkte)": "%s %s (%d points)",
	"denkt nach …": "thinking …",
	"DAME!": "DAME!",
	"Letzter Zug!": "Final turn!",
	"Zug von %s": "%s's turn",
	"%s ruft Dame – jeder hat noch einen Zug!": "%s calls Dame – everyone gets one more turn!",
	# Karten
	"Herz": "Hearts",
	"Pik": "Spades",
	"Kreuz": "Clubs",
	"Bube": "Jack",
	"Dame": "Queen",
	"König": "King",
	"Ass": "Ace",
	"Zehn": "Ten",
	# Regeln: Protokoll und Gruende
	"Runde gestartet. %d Plätze.": "Round started. %d seats.",
	"%d Plätze. Ausgabe 1, Runde 1, Safe Phase.": "%d seats. Deal 1, round 1, safe phase.",
	"Runde ist vorbei": "Round is over",
	"Extra-Ablegen nur im eigenen Zug": "Extra discard only on your own turn",
	"Nicht am Zug": "Not your turn",
	"Karten des Ansagers sind gelockt": "The caller's cards are locked",
	"Unbekannte Aktion": "Unknown action",
	"Ziehen ist jetzt nicht dran": "You cannot draw now",
	"Es liegt schon eine gezogene Karte": "There is already a drawn card",
	"Zwangszug: die offene Dame muss genommen werden": "Forced move: the open queen must be taken",
	"Ablage ist leer": "Discard pile is empty",
	"Keine Karten mehr im Stapel": "No cards left in the deck",
	"%s nimmt %s von der Ablage.": "%s takes %s from the discard.",
	"%s zieht vom Stapel.": "%s draws from the deck.",
	"Kein Tausch ohne gezogene Karte": "No swap without a drawn card",
	"Ungültiger Kartenindex": "Invalid card",
	"%s tauscht und legt %s ab": "%s swaps and discards %s",
	"Keine gezogene Karte zum Ablegen": "No drawn card to discard",
	"%s legt %s ab": "%s discards %s",
	"Extra-Ablegen nur im eigenen Zug nach dem Ablegen": "Extra discard only on your own turn after discarding",
	"Keine Ablage": "No discard",
	"Passt nicht. Genau eine Strafkarte": "No match. Exactly one penalty card",
	"%s legt extra %s ab": "%s extra-discards %s",
	"Dame ist jetzt nicht rufbar": "Dame cannot be called now",
	"%s hat Dame gerufen. Jeder andere Spieler hat noch genau einen Zug.": "%s called Dame. Every other player has exactly one more turn.",
	"%s kann nicht ziehen und setzt aus.": "%s cannot draw and passes.",
	"Der Zug ist noch nicht fertig": "The turn is not finished yet",
	"Zug kann jetzt nicht beendet werden": "The turn cannot be ended now",
	"Letzter Zug nach der Ansage. Karten aufgedeckt.": "Last turn after the call. Cards revealed.",
	"Zug beendet. Am Zug: %s": "Turn ended. Next: %s",
	"%s lag falsch. Nächste Ausgabe: 5 statt 4 Karten.": "%s was wrong. Next deal: 5 instead of 4 cards.",
	"%s hat Dame richtig gerufen.": "%s called Dame correctly.",
	"Spielende. %s gewinnt mit %d Punkten.": "Game over. %s wins with %d points.",
	"Spielende. Niemand ist übrig.": "Game over. Nobody is left.",
	"Keine abgeschlossene Runde": "No finished round",
	"Neue Ausgabe. Am Zug: %s": "New deal. Next: %s",
	"Bube: Anschauen ist jetzt nicht dran": "Jack: you cannot look now",
	"Ungültiger Platz": "Invalid seat",
	"Spieler ist ausgeschieden": "Player is out",
	"Nur eine verdeckte Karte": "Only a face-down card",
	"Bube: verdeckte Karte angesehen. Kein Tausch.": "Jack: looked at a face-down card. No swap.",
	"König: Tausch ist jetzt nicht dran": "King: you cannot swap now",
	"König tauscht blind mit einer gegnerischen Karte": "King swaps blind with an opponent's card",
	"Keine eigene Karte gewählt": "No own card chosen",
	"Keine gegnerische Karte": "No opponent card",
	"König tauscht nur verdeckte Karten": "King only swaps face-down cards",
	"König: eigene Karte angesehen und blind getauscht. Beide bleiben verdeckt.": "King: looked at own card and swapped blind. Both stay face down.",
	"%s: Zeit abgelaufen. Genau eine Strafkarte.": "%s: time is up. Exactly one penalty card.",
	"Zeit abgelaufen – Strafkarte für %s.": "Time is up – penalty card for %s.",
	"Dame offen. Genau eine Strafkarte.": "Open queen. Exactly one penalty card.",
	"Keine Strafkarte mehr verfügbar (%s).": "No penalty card left (%s).",
	"Extra-Karte abgelegt, Hand leer. Dame automatisch gerufen.": "Extra card discarded, hand empty. Dame called automatically.",
	"Spieler": "Player",
	"Ausgabe": "Deal",
	"Gesamt": "Total",
	"Gegenüber": "Opposite",
	"Links": "Left",
	"Rechts": "Right",
}


# Regeln haengen Saetze aneinander: Vor- und Nachsaetze getrennt uebersetzen.
const PREFIXES := {
	"Extra-Karte abgelegt, Hand leer. ": "Extra card discarded, hand empty. ",
}
const SUFFIXES := {
	". Bube: eine verdeckte Karte ansehen, ohne Tausch.": ". Jack: look at a face-down card, no swap.",
	". König: eigene Karte ansehen, dann blind tauschen. Gegnerkarte bleibt ungesehen.": ". King: look at your own card, then swap blind. The opponent's card stays unseen.",
}


# Sprache setzen und Tabelle anmelden. Deutsch braucht keine Tabelle (Schluessel = Text).
static func install(p_lang: String) -> void:
	lang = p_lang if p_lang in ["de", "en"] else "de"
	var tr_en := Translation.new()
	tr_en.locale = "en"
	for k in EN:
		tr_en.add_message(k, EN[k])
	TranslationServer.clear()
	# Nur bei Englisch anmelden: Godots Rueckfallsprache ist "en" und wuerde Deutsch sonst ueberschreiben.
	if lang == "en":
		TranslationServer.add_translation(tr_en)
	TranslationServer.set_locale(lang)


static func t(text: String) -> String:
	if lang != "en":
		return text
	return str(EN.get(text, text))


# Protokollzeile oder Grund aus den Regeln: exakter Treffer oder Muster mit %s/%d.
static func line(text: String) -> String:
	if lang != "en":
		return text
	if EN.has(text):
		return str(EN[text])
	for pre in PREFIXES:
		if text.begins_with(pre) and text.length() > pre.length():
			return str(PREFIXES[pre]) + line(text.substr(pre.length()))
	for suf in SUFFIXES:
		if text.ends_with(suf) and text.length() > suf.length():
			return line(text.substr(0, text.length() - suf.length())) + str(SUFFIXES[suf])
	if _patterns.is_empty():
		_build_patterns()
	for p in _patterns:
		var m: RegExMatch = (p[0] as RegEx).search(text)
		if m == null:
			continue
		var args: Array = []
		for i in range(1, m.get_group_count() + 1):
			var g := m.get_string(i)
			args.append(int(g) if str(p[2][i - 1]) == "d" else card_name(g))
		return str(p[1]) % args
	return text


# "Herz Dame" -> "Queen of Hearts", sonst unveraendert.
static func card_name(text: String) -> String:
	var parts := text.split(" ")
	if lang == "en" and parts.size() == 2 and EN.has(parts[0]) and parts[0] in ["Herz", "Karo", "Kreuz", "Pik"]:
		return "%s of %s" % [t(parts[1]), t(parts[0])]
	return text


static func _build_patterns() -> void:
	for k in EN:
		var key := str(k)
		if not ("%s" in key or "%d" in key) or key.contains("%-") or key.contains("%4"):
			continue
		var kinds: Array = []
		var rx := "^"
		var i := 0
		while i < key.length():
			var c := key[i]
			if c == "%" and i + 1 < key.length() and key[i + 1] in ["s", "d"]:
				kinds.append(key[i + 1])
				rx += "(.+?)" if key[i + 1] == "s" else "(-?\\d+)"
				i += 2
				continue
			rx += _escape(c)
			i += 1
		rx += "$"
		var re := RegEx.new()
		if re.compile(rx) == OK:
			_patterns.append([re, EN[k], kinds])


static func _escape(c: String) -> String:
	if c in [".", "(", ")", "[", "]", "{", "}", "?", "*", "+", "^", "$", "|", "\\"]:
		return "\\" + c
	return c
