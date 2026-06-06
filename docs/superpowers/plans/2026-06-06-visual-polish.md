# Dame Kartenspiel — Visual Polish Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Spiel visuell und akustisch aufwerten — Animationen, Sound, Mobile-Optimierung, Gewinner-Feier.

**Architecture:** Bestehende React-Komponenten bleiben erhalten. Neue Assets (Audio, CSS-Animationen) werden hinzugefügt. Framer Motion für komplexe Animationen.

**Tech Stack:** React 19, Tailwind CSS, Framer Motion, Web Audio API (keine externe Library nötig).

---

### Task 1: Sound-Effekte (Web Audio API)

**Files:**
- Create: `src/lib/sounds.ts` — Pure Funktionen für Sound-Generierung

**Context:** Keine externen Audio-Dateien. Wir generieren Sounds programmatisch mit der Web Audio API (Kurze Oscillator-Töne für Karten-Aktionen).

- [ ] **Step 1.1:** `playCardDraw()` — sanfter "swish"-Ton (Noise + Lowpass)
- [ ] **Step 1.2:** `playCardPlace()` — kurzer "plop"-Ton (Sinus-Decay)
- [ ] **Step 1.3:** `playCardFlip()` — schneller "flip"-Ton (Sinus-Glide)
- [ ] **Step 1.4:** `playDameCall()` — Alarm-Ton (schnelle Oktaven)
- [ ] **Step 1.5:** `playWinSound()` — Sieges-Fanfare (aufsteigende Akkorde)
- [ ] **Step 1.6:** In `GameBoard.tsx` alle relevanten Actions mit Sound verknüpfen

---

### Task 2: Karten-Animationen (Framer Motion)

**Files:**
- Create: `src/components/AnimatedCard.tsx`
- Modify: `src/components/Card.tsx`
- Modify: `src/components/GameBoard.tsx`

- [ ] **Step 2.1:** `AnimatedCard` — Wrapper um `CardComponent` mit `motion.div`
  - `initial={{ scale: 0.8, opacity: 0 }}`
  - `animate={{ scale: 1, opacity: 1 }}`
  - `whileHover={{ scale: 1.05 }}`
  - `whileTap={{ scale: 0.95 }}`
- [ ] **Step 2.2:** Karten-Flip-Animation beim Aufdecken (`rotateY: 0 → 180`)
- [ ] **Step 2.3:** Gezogene Karte "fliegt" vom Stapel zur Hand (AnimatePresence + layout)
- [ ] **Step 2.4:** Ablagestapel zeigt leichte "bounce"-Animation beim Ablegen

---

### Task 3: KI-Denken-Animation & Spieler-Highlight

**Files:**
- Modify: `src/components/GameBoard.tsx`
- Modify: `src/components/PlayerHand.tsx`

- [ ] **Step 3.1:** Aktiver Spieler bekommt leuchtenden Ring (`ring-4 ring-yellow-400 animate-pulse`)
- [ ] **Step 3.2:** KI-Denken: Avatar wackelt leicht, "Denkblasen"-Overlay
- [ ] **Step 3.3:** Zug-Wechsel-Transition (Fade zwischen Spielern)

---

### Task 4: Dame-Call-Event

**Files:**
- Modify: `src/components/GameBoard.tsx`

- [ ] **Step 4.1:** Wenn `phase === 'DAME_CALLED'`: Roter Bildschirm-Rand-Puls, Countdown-Overlay
- [ ] **Step 4.2:** Alle Karten flippen synchron auf (Stagger-Animation)
- [ ] **Step 4.3:** Punkte zählen sich hoch (Animated Counter)

---

### Task 5: Gewinner-Feier

**Files:**
- Modify: `src/components/GameBoard.tsx`

- [ ] **Step 5.1:** `confetti` Effekt (Canvas-confetti Library oder eigene Partikel)
- [ ] **Step 5.2:** Gewinner-Karte zoomt groß in die Mitte
- [ ] **Step 5.3:** Scoreboard mit Animations-Balken

---

### Task 6: Mobile-Optimierung

**Files:**
- Modify: `src/components/GameBoard.tsx`
- Modify: `src/components/PlayerHand.tsx`
- Modify: `src/components/Card.tsx`

- [ ] **Step 6.1:** Karten-Größe responsiv (`w-16 h-22` → `w-12 h-18` auf Mobile)
- [ ] **Step 6.2:** Spieler-Reihe wird auf kleinen Screens vertikal gestapelt
- [ ] **Step 6.3:** Touch-Targets mindestens 44×44px
- [ ] **Step 6.4:** Buttons größer auf Mobile (`size="lg"`)

---

### Task 7: Tisch-Atmosphäre

**Files:**
- Modify: `src/index.css`
- Modify: `src/components/GameBoard.tsx`

- [ ] **Step 7.1:** Grüner Filz-Tisch Hintergrund (CSS-Radial-Gradient + Noise-Overlay)
- [ ] **Step 7.2:** Kartenstapel bekommen realistischen 3D-Shadow
- [ ] **Step 7.3:** Dark-Mode für das Spielbrett (Toggle im Menü)

---

### Task 8: Toast-Benachrichtigungen

**Files:**
- Modify: `src/components/GameBoard.tsx`
- Use: `sonner` (bereits installiert)

- [ ] **Step 8.1:** `gameMessage` nicht mehr als Text, sondern als Toast (`toast.success`, `toast.error`)
- [ ] **Step 8.2:** Spezielle Toast-Typen: "Strafkarte!", "Dame gerufen!", "Runde gewonnen!"

---

### Empfohlene Reihenfolge:

1. Task 1 (Sound) — sofortiges Feedback
2. Task 2 (Karten-Animationen) — visuelle Klarheit
3. Task 3 (KI-Denken) — Spielfluss verbessern
4. Task 6 (Mobile) — Reichweite erhöhen
5. Task 4 + 5 (Events) — Wow-Momente
6. Task 7 + 8 (Atmosphäre) — Feinschliff
