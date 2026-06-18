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
