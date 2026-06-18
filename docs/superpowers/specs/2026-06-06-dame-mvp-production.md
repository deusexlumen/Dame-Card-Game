# BUXE_OS v24.X -- DAME MVP Production-Ready Design

## Ziel

Das funktional vorhandene Dame-Card-Game wird auf Production-Niveau gebracht: es folgt dem Konzept-Dossier (`DAME_Handbuch_Dossier-2.pdf`), läuft lint-frei, baut fehlerfrei, ist robust gegen Savegame-Korruption, visuell als Terminal-/Cybernetic-Archive-System erkennbar und für Screenreader/Tastatur grundlegend zugänglich.

## Ausgangslage

- React 19 + TypeScript + Vite + Tailwind + shadcn/ui
- Spiellogik, KI, Sounds, Settings, Save/Load, Tutorial bereits implementiert
- Build funktioniert, aber `pnpm lint` schlägt fehl und es gibt einen flakigen Test
- Visuelles Design ist klassisch royal (rote/schwarze Karten), nicht das geforderte Terminal-Ästhetik
- Einige Regeln weichen vom Konzept ab (Bube nur eigene Karte, König blinder Tausch, Dame-Call-Strafe wird nicht in die nächste Runde übernommen)

## Scope für diesen Production-MVP

1. **Regel-Alignment mit dem Konzept**
   - Bube: Eine verdeckte Karte anschauen (eigene oder gegnerische). Für den menschlichen Spieler als Modal; für die KI wird der gesehene Wert in `visibleCardIndices` (eigene) oder temporär berücksichtigt.
   - König: Zielkarte kurz aufdecken, dann gezielt mit einer eigenen Karte tauschen.
   - Dame-Call: Wenn der Caller falsch liegt, startet er die nächste Runde mit 5 Karten (Strafkarte wird beim Kartenverteilen hinzugefügt).
   - Flakiger Test in `discardExtraCard` stabilisieren.

2. **Visuelles Redesign (Terminal / Cybernetic Archive)**
   - Schwarzer Hintergrund, grüner Phosphor-Glow, geometrische Symbole, Monospace-Typografie.
   - Kartenrücken: Gitter/Circuit-Muster mit Glow.
   - Kartenfront: dunkles Terminal-Panel mit Rahmen, Scanlines, Symbol + Wert in Monospace.
   - Spieltisch und UI-Elemente passen sich dem Look an.

3. **Production-Qualität**
   - ESLint grün: eigene Hooks/Logik sauber, shadcn-Generatoren durch gezielte Override-Konfiguration oder lokale Fixes ruhiggestellt.
   - Debug-Relikte entfernt (`Alle anzeigen`-Button, deaktivierter Statistik-Button).
   - `kimi-plugin-inspect-react` nur im Dev-Build aktiv.
   - Save/Load validiert JSON mit einem Schema und fällt auf Menü zurück, wenn das Savegame beschädigt ist.
   - Grundlegende Accessibility: `aria-label`, `role`, `aria-live`, Fokus-Management in Dialogen.

4. **Tests & Dokumentation**
   - Vorhandene Tests anpassen; neue Tests für Bube/König/Dame-Call-Strafe.
   - README auf SOTA-Niveau aktualisieren (Regeln, Tech-Stack, Tastenkürzel, Deployment).

## Architektur

- **State**: Weiterhin React-Hooks + pure Funktionen in `src/lib/gameLogic.ts`.
- **KI**: `src/lib/aiPlayer.ts` nutzt die erweiterten Sonderkarten-Regeln.
- **UI**: `Card.tsx`/`PlayerHand.tsx`/`GameBoard.tsx` werden für Terminal-Look und neue Interaktionen angepasst.
- **Persistenz**: Save/Load in `useGameWithAI.ts` mit Validierung.
- **Build**: Vite-Config unterscheidet Dev/Production für das Inspect-Plugin.

## Nicht im Scope

- Echtzeit-Reaktionen / Mitwerfen identischer Karten (konzeptionell offen, post-MVP).
- Backend oder Multiplayer.
- PWA / Service-Worker.
- Umfangreiche E2E-Tests.

## Akzeptanzkriterien

- `pnpm lint` läuft ohne Fehler.
- `pnpm vitest run` läuft ohne Fehler.
- `pnpm build` läuft ohne Fehler.
- Das Spiel ist visuell als Terminal-System erkennbar.
- Bube/König/Dame-Call-Strafe verhalten sich laut Konzept.
- Savegames werden validiert; defekte Savegames führen nicht zu Crashs.
- README ist aktuell und vollständig.
