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
Jeder Fehler kostet genau eine Strafkarte vom Stapel. Sie zählt zu deinen Punkten.

[b]Hot-Seat[/b]
Mehrere Menschen an einem Gerät: Vor jedem Zug wird der Tisch abgedeckt. Gib das Gerät weiter und bestätige erst, wenn nur der richtige Spieler hinsieht.

[b]Tasten[/b]
1–6 Karte wählen · Leertaste ziehen · Enter bestätigen · A ablegen · X extra ablegen · D Dame rufen · Esc Menü"""

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
	text_label.text = RULES_TEXT
	content.add_child(text_label)
	back_button.grab_focus()
