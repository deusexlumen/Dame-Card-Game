# DAME — Finale Konzeptentscheidungen

Basierend auf dem Dossier werden die offenen Fragen wie folgt verbindlich festgelegt:

## 1. Echtzeit-Reaktionsregel ("Mitwerfen")

**Entscheidung:** Keine physische Echtzeit-Reaktion. Das digitale Spiel arbeitet rundenbasiert.  
Stattdessen gilt die **Extra-Ablegen-Regel**: Hat ein Spieler während seines eigenen Zuges eine Karte auf der Hand, die zum aktuell obersten Ablagestapel passt, darf er diese zusätzlich ablegen.  
Dadurch bleibt der Information-/Timing-Vorteil erhalten, ohne Netzwerk-Latenz oder Klick-Wettrennen einzuführen.

## 2. Anzahl Strafkarten

**Entscheidung:** Jeder regelwidrige Fehler kostet genau **eine Strafkarte**.  
Diese wird aus dem Nachziehstapel gezogen und verdeckt an die Auslage angehängt. Gleiches gilt für das Ablegen einer Dame (Strafkarte ziehen) und eine falsche Dame-Ansage (Strafkarte in der nächsten Runde).

## 3. Sichtbarkeit der Dame

**Entscheidung:** Eine abgelegte Dame liegt immer **offen** auf dem Ablagestapel.  
Sie ist damit für alle Spieler sichtbar und löst den Zwangszug für den nächsten Spieler aus (außer in Safe Phase / Rundenende).

## 4. Mitwerfen identischer Karten

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
- **König:** Eine eigene verdeckte Karte ansehen, dann blind mit einer gegnerischen Karte tauschen. Die Gegnerkarte bleibt ungesehen, beide liegen danach verdeckt.
- **Ass und Zehn:** Keine Sonderwirkung.
- **Dame-Ansage:** Ansager gewinnt nur mit strikt weniger Punkten als jeder andere. Gleichstand = falsch.
- **Safe Phase:** Die ersten zwei Umläufe jeder Ausgabe. Keine Ansage, kein Dame-Zwangszug.

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

## 11. Online-Spiel: Verbindungsabbruch & Wiedereinstieg

**Ziel:** Ein kurzes Funkloch kostet nichts. Wer absichtlich geht oder lange wegbleibt, verändert die Partie für alle und wird dafür bestraft.

Als „abwesend" gilt: Verbindung getrennt **oder** App/Tab im Hintergrund.

**Stufe 1 – Funkloch (bis 60 s am Stück, max. 2 Min. pro Partie insgesamt): straffrei**
- Die anderen spielen normal weiter.
- Ist der abwesende Spieler am Zug, wartet der Tisch zusätzlich zum Zugtimer bis zu **15 s Verbindungsreserve**.
- Kommt er nicht zurück, setzt er aus (**keine** Strafkarte nach §9): Die Hand bleibt unverändert, es wird nichts gezogen und kein Effekt ausgelöst. Ausnahme: Ein Dame-Zwangszug wird regulär ausgeführt.
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

## 12. Plattformen (Entscheidung 2026-10-06)

Wo und wie gespielt wird, ist egal (Browser, als App installiert, Windows, später weitere). **Das Spiel muss überall gleich sein:** gleiche Regeln, gleicher Look, gleicher Ablauf. Plattformen dürfen nur Bedienung und Technik anpassen, nie das Spiel.
