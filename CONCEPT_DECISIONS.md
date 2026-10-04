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

## 6. Online-Spiel: Nur live, kein Langzeitmodus

**Entscheidung:** Online-Partien werden **live** gespielt, alle sitzen gleichzeitig am Tisch. Es gibt keinen asynchronen Modus nach dem Prinzip „ich spiele, wenn ich aufs Handy schaue": Dame lebt von Tempo und frischem Gedächtnis, und Wartezeiten würden die Partie für alle ruinieren.
- Der Zug-Timer ist online **immer aktiv** (Standard 30 s, der Host wählt 20/30/45 s).
- Läuft der Timer ab, wird ein **neutraler Auto-Zug** ausgeführt (siehe unten).

## 7. Online-Spiel: Verbindungsabbruch & Wiedereinstieg

**Ziel:** Ein kurzes Funkloch kostet nichts. Wer absichtlich geht oder lange wegbleibt, verändert die Partie für alle und wird dafür bestraft.

Als „abwesend" gilt: Verbindung getrennt **oder** App/Tab im Hintergrund.

**Stufe 1 – Funkloch (bis 60 s am Stück, max. 2 Min. pro Partie insgesamt): straffrei**
- Die anderen spielen normal weiter.
- Ist der abwesende Spieler am Zug, wartet der Tisch zusätzlich zum Zug-Timer bis zu **15 s Verbindungsreserve**.
- Kommt er nicht zurück, folgt ein **neutraler Auto-Zug**: Der Spieler setzt aus, die Hand bleibt unverändert, es wird keine Karte gezogen und kein Effekt ausgelöst. Einzige Ausnahme: Liegt eine offene Dame (Zwangszug), wird sie wie offline regulär genommen.
- Kehrt er zurück, spielt er sofort mit seiner unveränderten Hand weiter.

**Stufe 2 – Längere Abwesenheit (über 60 s am Stück oder Reserve von 2 Min. aufgebraucht): KI übernimmt, Wiedereinstieg mit Strafe**
- Eine **vorsichtige KI** übernimmt den Platz. Sie ruft nie „Dame" und nutzt keine Effekte gezielt, damit Weggehen niemals ein Vorteil ist.
- Wiedereinstieg ist bis **5 Minuten** nach Beginn der Abwesenheit möglich.
- Strafe beim Wiedereinstieg: **1 Strafkarte** in der nächsten Runde (gleiches System wie in Abschnitt 2).

**Stufe 3 – Abbruch (über 5 Min. abwesend): Platz verloren**
- Der Platz bleibt bis zum Partieende bei der KI, ein Wiedereinstieg ist nicht mehr möglich.
- Die Partie zählt für diesen Spieler als **Aufgabe** (Niederlage in Statistik/Rangliste).
- Wiederholte Abbrüche führen in öffentlichen Partien (Matchmaking, v2) zu einer Wartesperre.

**Sonderfälle**
- Sind alle menschlichen Spieler abwesend, wird die Partie pausiert und nach 5 Minuten beendet (ohne Wertung).
- Während einer Dame-Ansage gelten dieselben Regeln. Der Ansager ist ohnehin gelockt, sein Platz braucht keine Aktion.
- Alle Zeitwerte sind Startwerte und werden nach ersten Testpartien justiert.
