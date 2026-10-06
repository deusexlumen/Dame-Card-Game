extends "res://scripts/screens/screen_base.gd"

# Spielregeln. Inhalt folgt CONCEPT_DECISIONS.md und dame_rules.gd.

const RULES_TEXT := """[b]Ziel[/b]
Möglichst wenige Punkte sammeln. Wer über 50 Gesamtpunkte kommt, scheidet aus. Genau 50 setzt dich auf 0 zurück. Wer am Ende übrig bleibt, gewinnt.

[b]Ausgabe[/b]
Jeder bekommt 4 verdeckte Karten. Die ersten zwei darfst du dir ansehen, die anderen zwei kennst du nicht. Merk dir gut, was wo liegt.

[b]Dein Zug[/b]
1. Ziehe eine Karte vom Stapel oder nimm die oberste Karte der Ablage.
2. Tausche sie gegen eine eigene Karte (die alte kommt offen auf die Ablage) oder lege sie direkt ab.
3. Danach darfst du eine eigene Karte mit gleichem Rang wie die Ablage zusätzlich ablegen. Liegst du falsch, bekommst du eine Strafkarte.
4. Zug beenden.

[b]Kartenwerte[/b]
Ass 1 · Zwei bis Zehn nach Augen · Bube 10 · König 10 · Dame 0

[b]Sonderkarten (beim Ablegen)[/b]
[b]Bube:[/b] Sieh dir eine beliebige verdeckte Karte an – deine oder eine fremde. Kein Tausch.
[b]König:[/b] Sieh dir eine eigene verdeckte Karte an und tausche sie dann blind gegen eine Karte eines Gegners. Beide bleiben verdeckt.
[b]Dame:[/b] Wer eine Dame ablegt, bekommt eine Strafkarte. Eine offene Dame auf der Ablage muss der nächste Spieler nehmen.
Ass und Zehn haben keine Sonderwirkung.

[b]Safe Phase[/b]
In den ersten zwei Runden jeder Ausgabe darf niemand „Dame“ rufen, und die offene Dame zwingt niemanden.

[b]Dame rufen[/b]
Ab Runde 3 darfst du zu Beginn deines Zuges „Dame“ rufen, wenn du glaubst, die wenigsten Punkte zu haben. Deine Karten sind dann gesperrt, jeder andere hat noch genau einen Zug. Danach wird aufgedeckt.
Hast du strikt weniger Punkte als alle anderen, war die Ansage richtig. Bei Gleichstand oder mehr liegst du falsch und startest die nächste Ausgabe mit 5 statt 4 Karten.

[b]Strafkarten[/b]
Jeder Fehler kostet genau eine Strafkarte vom Stapel. Sie zählt zu deinen Punkten. Läuft der Zugtimer ab, gibt es ebenfalls eine Strafkarte.

[b]Spieler[/b]
2 bis 6 Plätze. Ab 5 Spielern wird mit zwei Decks gespielt.

[b]Hot-Seat[/b]
Mehrere Menschen an einem Gerät: Vor jedem Zug wird der Tisch abgedeckt. Gib das Gerät weiter und bestätige erst, wenn nur der richtige Spieler hinsieht.

[b]Tasten[/b]
1–6 Karte wählen · Leertaste ziehen · Enter bestätigen · A ablegen · X extra ablegen · D Dame rufen · H Hilfe · Esc Menü"""

const RULES_TEXT_EN := """[b]Goal[/b]
Collect as few points as possible. Anyone above 50 total points is out. Exactly 50 resets you to 0. Whoever is left at the end wins.

[b]Deal[/b]
Everyone gets 4 face-down cards. You may look at the first two; the other two stay unknown. Remember well what lies where.

[b]Your turn[/b]
1. Draw a card from the deck or take the top card of the discard pile.
2. Swap it for one of your cards (the old one goes face up onto the discard) or discard it directly.
3. Then you may additionally discard one of your cards with the same rank as the discard. If you are wrong, you get a penalty card.
4. End your turn.

[b]Card values[/b]
Ace 1 · Two to Ten by pips · Jack 10 · King 10 · Queen 0

[b]Special cards (when discarded)[/b]
[b]Jack:[/b] Look at any face-down card – yours or someone else's. No swap.
[b]King:[/b] Look at one of your face-down cards, then swap it blind with an opponent's card. Both stay face down.
[b]Queen:[/b] Whoever discards a queen gets a penalty card. An open queen on the discard must be taken by the next player.
Ace and Ten have no special effect.

[b]Safe phase[/b]
In the first two rounds of every deal nobody may call “Dame”, and the open queen forces nobody.

[b]Calling Dame[/b]
From round 3 you may call “Dame” at the start of your turn if you think you have the fewest points. Your cards are then locked and everyone else gets exactly one more turn. Then all cards are revealed.
If you have strictly fewer points than everyone else, the call was right. With a tie or more you are wrong and start the next deal with 5 instead of 4 cards.

[b]Penalty cards[/b]
Every mistake costs exactly one penalty card from the deck. It counts towards your points. If the turn timer runs out, you also get one penalty card.

[b]Players[/b]
2 to 6 seats. From 5 players on, two decks are used.

[b]Hot seat[/b]
Several people on one device: the table is covered before every turn. Pass the device and only confirm when the right player is looking.

[b]Keys[/b]
1–6 pick card · Space draw · Enter confirm · A discard · X extra discard · D call Dame · H help · Esc menu"""

var text_label: RichTextLabel

func build() -> void:
	frame("Regeln", 860)
	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.scroll_active = false
	text_label.custom_minimum_size = Vector2(840, 0)
	text_label.add_theme_font_size_override("normal_font_size", 17)
	text_label.add_theme_font_size_override("bold_font_size", 18)
	# Deutsch ist Schluessel-Sprache; der Regeltext ist zu lang fuer die Tabelle.
	var app := app_node()
	text_label.text = RULES_TEXT_EN if app != null and app.language() == "en" else RULES_TEXT
	content.add_child(text_label)
	back_button.grab_focus()
