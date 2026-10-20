# DAME — Finale Konzeptentscheidungen

Basierend auf dem Dossier werden die offenen Fragen wie folgt verbindlich festgelegt:

## 1. Echtzeit-Reaktionsregel ("Mitwerfen")

> **Überholt am 2026-10-19 durch §13.** Der Nutzer hat klargestellt: Mitwerfen außerhalb des eigenen Zugs ist Kern des Spiels. Der folgende Absatz gilt nicht mehr.

**Entscheidung:** Keine physische Echtzeit-Reaktion. Das digitale Spiel arbeitet rundenbasiert.  
Stattdessen gilt die **Extra-Ablegen-Regel**: Hat ein Spieler während seines eigenen Zuges eine Karte auf der Hand, die zum aktuell obersten Ablagestapel passt, darf er diese zusätzlich ablegen.  
Dadurch bleibt der Information-/Timing-Vorteil erhalten, ohne Netzwerk-Latenz oder Klick-Wettrennen einzuführen.

## 2. Anzahl Strafkarten

**Entscheidung:** Jeder regelwidrige Fehler kostet genau **eine Strafkarte**.  
Diese wird aus dem Nachziehstapel gezogen und verdeckt an die Auslage angehängt. Gleiches gilt für das Ablegen einer Dame (Strafkarte ziehen) und eine falsche Dame-Ansage (Strafkarte in der nächsten Runde).

## 3. Sichtbarkeit der Dame

**Entscheidung:** Eine abgelegte Dame liegt immer **offen** auf dem Ablagestapel.  
Sie ist damit für alle Spieler sichtbar. **Seit 2026-10-20 gibt es keinen Zwangszug mehr** (vom Nutzer klargestellt): Die Dame ist 0 Punkte wert, sie von der Ablage zu nehmen ist erlaubt und meist klug, aber nie Pflicht.

## 4. Mitwerfen identischer Karten

> **Überholt am 2026-10-19 durch §13.**

**Entscheidung:** Siehe Abschnitt 1. "Extra-Ablegen" innerhalb des eigenen Zuges.  
Es gibt keine "Schnappreaktion" anderer Spieler außerhalb ihres Zuges.

## 5. Letzte Runde formal absichern

**Entscheidung:** Nach einer Dame-Ansage:
- Die Karten des Ansagers werden gelockt (keine Manipulation mehr möglich).
- Jeder andere Spieler erhält noch **genau einen vollständigen Zug**.
- Danach werden alle Karten aufgedeckt, Punkte berechnet und der Verlierer ermittelt.
- Hat ein anderer Spieler gleich viele oder weniger Punkte als der Ansager, erhält der Ansager in der nächsten Runde eine Strafkarte (5 statt 4 Karten).

## 6. Sonderkarten (Godot-Fassung, verbindlich)

- **Bube:** Beim Ablegen eine beliebige verdeckte Karte ansehen (eigene oder fremde). Kein Tausch.
- **König:** Überholt durch §14: zwei beliebige verdeckte Karten blind tauschen.
- **Ass und Zehn:** Keine Sonderwirkung.
- **Dame-Ansage:** Ansager gewinnt nur mit strikt weniger Punkten als jeder andere. Gleichstand = falsch.
- **Safe Phase:** Die ersten zwei Umläufe jeder Ausgabe. Keine Dame-Ansage.

## 7. Spielende

- Über 50 Punkte = ausgeschieden. Genau 50 = zurück auf 0.
- Spielende, wenn höchstens ein Spieler übrig ist oder kein menschlicher Spieler mehr im Spiel ist.
- Sieger: der verbliebene Spieler mit den wenigsten Gesamtpunkten.

## 8. Ökonomie

- Spielwährung „Chips“, nur durch Spielen verdient, nur für Kosmetik. Keine kaufbaren Spielvorteile.
- Echtgeld kommt später über die Schnittstelle `PurchaseProvider`. Im aktuellen Build nur ein Stub.

## 9. Entscheidungen vom 2026-10-06 (verbindlich)

- **Ass und Zehn:** In V1 ohne Wirkung (wie §6). Power-Effekte werden als **deaktiviertes Feature-Flag** vorbereitet (`power_effects`, Standard aus, nicht in den Einstellungen sichtbar).
- **Sprache:** Deutsch und Englisch, umschaltbar in den Einstellungen. Alle Texte über Locale-Keys.
- **Zugtimer:** Läuft die Zeit ab, zieht der Spieler **eine Strafkarte**, danach endet der Zug. Während der Zielauswahl von Bube und König pausiert der Timer.
- **Spieleranzahl:** 2–6. Anzahl Decks = ⌈Spieler / 4⌉: 2–4 Spieler 1 Deck (52 Karten), 5–6 Spieler 2 Decks (104 Karten).
- **3D-Tisch:** Bis zu 6 Plätze, radial im 60°-Abstand.
- **Look:** Modern-Dark-Casino (siehe `docs/superpowers/specs/2026-06-06-professional-polish-design.md`). Der Terminal-/Phosphor-Look ist überholt und wird entfernt.
- **Assets:** Beste kostenlose Option, Figuren und Animationen von Quaternius (CC0).

## 10. Online-Spiel: Nur live, kein Langzeitmodus (Entscheidung 2026-10-04)

Online-Partien werden **live** gespielt, alle sitzen gleichzeitig am Tisch. Es gibt keinen asynchronen Modus nach dem Prinzip „ich spiele, wenn ich aufs Handy schaue": Dame lebt von Tempo und frischem Gedächtnis, und Wartezeiten würden die Partie für alle ruinieren.
- Der Zugtimer ist online **immer aktiv** (Standard 30 s, der Host wählt 20/30/45 s).
- Ein anwesender Spieler, dessen Zeit abläuft, zieht wie in §9 **eine Strafkarte**.
- Anders als offline pausiert der Timer online **nicht** bei der Ziel-Auswahl von Bube und König. Sonst könnte ein Spieler die Partie für alle anhalten.
- Zwischen zwei Ausgaben warten alle höchstens 10 s. Sind alle anwesenden Spieler vorher bereit, geht es sofort weiter.

## 11. Online-Spiel: Verbindungsabbruch & Wiedereinstieg

**Ziel:** Ein kurzes Funkloch kostet nichts. Wer absichtlich geht oder lange wegbleibt, verändert die Partie für alle und wird dafür bestraft.

Als „abwesend" gilt: Verbindung getrennt **oder** App/Tab im Hintergrund.

**Stufe 1 – Funkloch (bis 60 s am Stück, max. 2 Min. pro Partie insgesamt): straffrei**
- Die anderen spielen normal weiter.
- Ist der abwesende Spieler am Zug, wartet der Tisch zusätzlich zum Zugtimer bis zu **15 s Verbindungsreserve**.
- Kommt er nicht zurück, setzt er aus (**keine** Strafkarte nach §9): Die Hand bleibt unverändert, es wird nichts gezogen und kein Effekt ausgelöst. Ausnahme: Ein Dame-Zwangszug wird regulär ausgeführt. Die Dame wird genommen und gegen die höchste bekannte eigene Karte getauscht (ohne bekannte Karte gegen die erste Karte).
- Bricht die Verbindung mitten im Zug ab (Karte schon gezogen), legt der Server die gezogene Karte ab und beendet den Zug, ebenfalls ohne Strafkarte. Eine gezogene Dame wird dabei eingetauscht statt abgelegt, denn Ablegen kostet eine Strafkarte.
- Kehrt er zurück, spielt er sofort mit seiner unveränderten Hand weiter.

**Stufe 2 – Längere Abwesenheit (über 60 s am Stück oder Reserve von 2 Min. aufgebraucht): KI übernimmt, Wiedereinstieg mit Strafe**
- Eine **vorsichtige KI** übernimmt den Platz. Sie ruft nie „Dame" und nutzt Bube/König nicht gezielt, damit Weggehen niemals ein Vorteil ist.
- Wiedereinstieg ist bis **5 Minuten** nach Beginn der Abwesenheit möglich.
- Strafe beim Wiedereinstieg: **1 Strafkarte** in der nächsten Ausgabe (gleiches System wie §2).

**Stufe 3 – Abbruch (über 5 Min. abwesend): Platz verloren**
- Der Platz bleibt bis zum Partieende bei der KI, ein Wiedereinstieg ist nicht mehr möglich.
- Die Partie zählt für diesen Spieler als **Aufgabe** (Niederlage in Statistik/Rangliste, keine Chips).
- Wiederholte Abbrüche führen in öffentlichen Partien (Matchmaking) zu einer Wartesperre.

**Sonderfälle**
- Sind alle menschlichen Spieler abwesend, wird die Partie pausiert und nach 5 Minuten ohne Wertung beendet (passt zu §7: ohne Menschen kein Weiterspielen).
- Während einer Dame-Ansage gelten dieselben Regeln. Der Ansager ist ohnehin gelockt.
- Alle Zeitwerte sind Startwerte und werden nach ersten Testpartien justiert.

**Host-Abbruch (Online per P2P, Entscheidung 2026-10-06)**
- In Partien ohne Server führt ein Spieler als Host die Regeln aus. Verlässt er die Partie oder bricht seine Verbindung dauerhaft ab (nach den Stufen oben), endet die Partie für alle **ohne Wertung**: keine Niederlage, keine Chips, keine Aufgabe-Zählung.
- Host-Wechsel mitten in der Partie gibt es in V1 nicht. Die Stufen 1 bis 3 gelten unverändert für alle anderen Spieler.
- Technik: `docs/online-p2p-plan.md`.

## 12. Plattformen (Entscheidung 2026-10-06)

Wo und wie gespielt wird, ist egal (Browser, als App installiert, Windows, später weitere). **Das Spiel muss überall gleich sein:** gleiche Regeln, gleicher Look, gleicher Ablauf. Plattformen dürfen nur Bedienung und Technik anpassen, nie das Spiel.

## 12. Merkphase vor dem ersten Zug (Entscheidung 2026-10-19, verbindlich)

Das Spiel lebt davon, Informationen zu beschaffen und sich zu merken. Darum beginnt jede Ausgabe so:

- Jeder bekommt 4 verdeckte Karten. **Vor dem ersten Zug** darf sich jeder Mensch **zwei** seiner Karten ansehen. Welche, entscheidet er selbst (antippen). Die Karten sind sonst verdeckt.
- Solange die Merkphase läuft, also bis **alle** Menschen „Fertig“ bestätigt haben (KI sofort), darf er seine zwei Karten **beliebig oft wieder ansehen**. Es gibt keine Sperre nach „Fertig“.
- Eine **dritte** Karte anzusehen ist ein Regelverstoß: **eine Strafkarte**, die Karte bleibt unbekannt.
- Bis alle fertig sind, sind alle Spielaktionen gesperrt. Das gilt für jede neue Ausgabe.
- **Hardcore-Modus** (Option im Setup): kein Blick auf die Startkarten, das Spiel beginnt sofort, jeder spielt blind.
- **Anfängerhilfe** (Einstellung, Standard aus): bekannte Karten bleiben auch nach der Merkphase offen. Vorher hieß sie „Gedächtnishilfe“ und war an, wodurch Karten dauerhaft offen lagen.
- **Hot-Seat:** Jeder Mensch merkt sich seine Karten hinter dem Übergabe-Schirm, einer nach dem anderen (kein erneutes Ansehen danach).
- **Online:** Der Host wartet höchstens 45 s auf Bestätigungen, danach gelten alle als bereit.
- Allgemeine Regel: **Jeder Regelverstoß kostet genau eine Strafkarte.**

## 13. Mitwerfen (Entscheidung 2026-10-19, verbindlich, ersetzt §1 und §4)

- Sobald eine Karte oben auf der Ablage liegt, darf **jeder** Spieler **jederzeit**, auch außerhalb seines Zugs, eine eigene verdeckte Karte mit **gleichem Rang** ablegen. Niemand kann das verhindern. Es zählt nur die Karte, die **gerade oben** liegt.
- **Richtig:** die Karte wandert auf die Ablage, die **Hand wird kleiner** (keine Ersatzkarte). Das Ziel ist, verdeckte Karten loszuwerden.
- **Falsch** (anderer Rang, oder der Zug eines anderen hat inzwischen eine neue Karte nach oben gelegt): **eine Strafkarte**, die Karte bleibt in der Hand. Wer schneller war, entscheidet die Reihenfolge, in der der Host die Aktionen annimmt.
- Gilt nicht für den Ansager nach „Dame“ (Karten gesperrt) und nicht für Ausgeschiedene. In der Merkphase gibt es kein Mitwerfen.
- Ein Mitwerfen außerhalb des eigenen Zugs löst **keine Sonderwirkung** (Bube/König) aus und stört den laufenden Zug nicht. Eine Dame kostet wie immer eine Strafkarte. Im eigenen Zug nach dem Ablegen gilt weiter die Sonderwirkung.
- Wirft jemand außerhalb seines Zugs die **letzte** Karte mit, ruft er damit automatisch Dame. Der laufende Zug des anderen zählt als dessen letzter Zug.
- **KI:** wirft nur mit sicherem Wissen mit (bekannte Karte, gleicher Rang, keine Dame), „Einfach“ nie, und bewusst langsamer, als ein Mensch reagieren kann.
- Offen: Die Reaktionszeit der KI nach Schwierigkeit feintunen, Mitwerfen im Hot-Seat (heute nur im eigenen Zug).

## 14. König: zwei beliebige Karten blind tauschen (Entscheidung 2026-10-20, verbindlich, ersetzt die Königsregel in §6)

- Wer einen König ablegt, tauscht **zwei beliebige verdeckte Karten**. Es ist egal, wem sie gehören: zwei fremde untereinander, zwei eigene oder eine eigene und eine fremde. Es müssen zwei verschiedene Karten sein.
- **Nichts wird angesehen.** Weder der Tauschende noch sonst jemand sieht eine der beiden Karten.
- **Öffentlich:** Alle sehen, **dass** getauscht wurde und **zwischen welchen Kartenplätzen** (Spieler und Kartennummer). Niemand erfährt, **welche Karten** es sind. Angezeigt wird das mit Hinweis im Bild, Protokollzeile, Ton, Aufleuchten der beiden Karten und im 3D-Tisch gleiten die beiden Karten über den Tisch.
- **Wissen folgt der Karte:** Die Kartenplätze sind öffentlich, also weiß, wer eine der beiden Karten vorher kannte (eigene Startkarte, Bube), auch, wo sie jetzt liegt. Der neue Besitzer kennt die eingetauschte Karte nicht.
- Karten von Ausgeschiedenen und vom gesperrten Ansager (nach „Dame“) dürfen nicht getauscht werden. Gibt es keine zwei tauschbaren Karten, entfällt der König-Schritt.
- **KI:** gibt ihre schlechteste bekannte (sonst eine unbekannte) eigene Karte ab und holt sich eine fremde, „Schwer“ bevorzugt bekannte niedrige Karten oder tauscht beim Führenden. „Einfach“ tauscht zufällig. Sind alle Gegner gesperrt, tauscht sie zwei eigene Karten.
- Der Joker ist in §15 festgelegt (Joker-Modus).

## 15. Spielmodi (Richtung vom 2026-10-20, verbindlich; Umsetzung folgt)

- **Das Grundspiel bleibt das Hauptspiel** und ist immer der Standard. Alle Modi sind optionale Abwandlungen, die im Aufbau gewählt werden (neben „Hardcore“, das es schon gibt). Ohne Wahl ändert sich keine Regel.
- **Joker-Modus:** Zwei Joker pro Stapel. Der Joker wiederholt beim Ablegen die Wirkung der **Karte, die darunter liegt** (Bube, König usw.), liegt nichts Wirksames darunter, passiert nichts. Er ist wenige Punkte wert (etwa 0 bis 5, genau beim Bauen festlegen), er lässt sich **nicht mitwerfen** (§13) und kostet abgelegt keine Strafkarte. Eigene Kartenbilder (`godot/tools/assets/gen_cards.py`), KI und Regeltext werden mitgebaut.
- **Custom-Modus:** Regeln frei einstellbar, auch die Kartenzahl: Handgröße, Anzahl Stapel und Joker, Strafkarten pro Fehler, Merkphase (Dauer, Anzahl ansehbarer Karten), Mitwerfen an/aus, Sonderkarten an/aus. Der Host schickt die Einstellungen als Teil der Tischkonfiguration; alle Mitspieler sehen vor dem Start, was gilt.
- **Chaos-Modus:** Zufall statt Ordnung: gemischte Regelparameter pro Runde (zum Beispiel zufällige Handgröße, zufällige Sonderwirkung je Rang). Die geltenden Regeln der Runde werden **offen angesagt**, damit es sich lustig und nicht ungerecht anfühlt. Seed kommt vom Host, damit alle dasselbe sehen.
- Umsetzung: ein Modus ist eine benannte Gruppe von Regelschaltern in der Tischkonfiguration (`DameRules`), keine eigene Spiellogik. Der Custom-Modus ist die offene Form derselben Schalter, Joker- und Chaos-Modus sind Voreinstellungen davon. Reihenfolge: Schalter einführen, Joker, Custom, Chaos.
- **Stand 2026-10-20, gebaut** (Festlegungen, die der Nutzer mit „erst mal plausibel, in der Praxis prüfen“ freigegeben hat): Joker = 3 Punkte. Chaos würfelt je Ausgabe Handgröße 3 bis 6, Joker 0 bis 2, Strafkarten 1 bis 2, Safe-Phase 0 bis 3 und zwei Ränge für Ansehen und Tauschen; Mitwerfen und Dame bleiben fest. Jeder Modus zählt getrennt: Moduspartien füttern weder Grundspiel-Statistik noch Chips, sondern `mode_games`.
- **Freischalten:** Joker nach 3, Eigene Regeln nach 6, Chaos nach 10 beendeten Grundspiel-Partien; Einstellung „Alle Spielmodi sofort freischalten“ öffnet alle. Es zählt der eigene Spielstand des Gastgebers; Mitspieler spielen jeden gewählten Modus mit.
- Offen bis zum Spieltest: ob die Zahlen (Joker 3, Chaos-Rahmen, Schwellen 3/6/10) sich richtig anfühlen; Modus-Auswahl fürs Online-Spiel (heute nur offline und Hot-Seat).
