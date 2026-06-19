/* eslint-disable react-refresh/only-export-components */
import { createContext, useContext, useEffect, useState, useCallback, type ReactNode } from 'react';

export type Language = 'de' | 'en';

const STORAGE_KEY = 'dame-language';

function getNested(obj: Record<string, unknown>, path: string): string | undefined {
  const parts = path.split('.');
  let current: unknown = obj;
  for (const part of parts) {
    if (current === null || typeof current !== 'object') return undefined;
    current = (current as Record<string, unknown>)[part];
  }
  if (typeof current === 'string') return current;
  return undefined;
}

const de = {
  app: {
    title: 'Dame',
    subtitle: 'Gedächtnis, Risiko & Bluff',
    tagline: 'Ein Spiel für 2–6 Spieler • Mit KI-Gegnern!',
  },
  menu: {
    startGame: 'Spiel starten',
    newGame: 'Neues Spiel',
    addHuman: 'Mensch',
    addAI: 'KI',
    players: 'Spieler',
    player: 'Spieler',
    difficulty: {
      easy: 'Einfach',
      medium: 'Mittel',
      hard: 'Schwer',
    },
    rules: 'Regeln',
    settings: 'Einstellungen',
    language: 'Sprache',
  },
  game: {
    round: 'Runde {{round}}',
    safePhase: 'Safe Phase',
    aiThinking: '{{name}} denkt...',
    aiMustTakeQueen: '{{name}} muss die offene Dame nehmen...',
    drawPile: 'Ziehstapel',
    discardPile: 'Ablagestapel',
    currentPlayer: 'Aktueller Spieler',
    drawnCard: 'Gezogene Karte',
    points: 'pts',
    penaltyCards: 'Strafkarten',
    eliminated: 'OUT',
    yourTurn: '{{name}} ist am Zug.',
    startedDraw: 'Spiel gestartet! Ziehe eine Karte.',
    drawHint: 'Ziehe eine Karte vom Zieh- oder Ablagestapel.',
    extraDiscardSuccess: 'Extra-Karte abgelegt!',
    extraDiscardFail: 'Falsche Karte! Strafkarte gezogen.',
    autoDameCall: '{{name}} hat keine Karten mehr und ruft Dame!',
    swapped: 'Karten getauscht!',
    gameStarted: 'Spiel gestartet! Ziehe eine Karte.',
    drawnCardPrompt: 'Du hast {{rank}} gezogen. Was möchtest du tun?',
    drawnFromDiscard: 'Du nimmst {{rank}} vom Ablagestapel.',
    queenDiscarded: 'Dame abgelegt! Du ziehst eine Strafkarte.',
    jackDiscarded: 'Bube abgelegt! Wähle eine Karte zum Anschauen.',
    kingDiscarded: 'König abgelegt! Wähle einen Spieler zum Tauschen.',
    cardDiscarded: 'Du hast {{rank}} abgelegt.',
    cardDiscardedGeneric: 'Karte abgelegt.',
    cardSeen: 'Du kannst jetzt diese Karte sehen.',
    mustTakeQueen: 'Du musst die offene Dame nehmen!',
    welcome: 'Willkommen bei Dame!',
    dameCalled: '{{name}} hat Dame gerufen! Letzte Runde!',
    dameWrong: '{{name}} lag mit "Dame" falsch! Strafkarte.',
    dameCorrect: '{{name}} hat "Dame" richtig gerufen! Runde gewonnen.',
    roundStarts: 'Runde {{round}} beginnt! {{name}} startet.',
    gameOver: 'Spiel vorbei',
    gameOverWinner: 'Gewinner: {{name}}',
    youAreEliminated: 'Du bist ausgeschieden!',
    eliminatedWatch: 'Schau zu, wie die KI-Gegner weiterspielen...',
    isEliminated: '{{name}} ist ausgeschieden!',
    yourCards: 'Deine Karten:',
    chooseOpponent: 'Wähle einen Gegner:',
    chooseOpponentCard: 'Wähle eine Karte des Gegners:',
    endTurn: 'Zug beenden',
    discard: 'Ablegen',
    callDame: 'Dame rufen!',
    jack: 'Bube',
    king: 'König',
    swapConfirm: 'Tauschen bestätigen',
    restart: 'Neustart',
    backToMenu: 'Menü',
    tutorial: 'Anleitung',
    stats: 'Statistiken',
    peekTitle: 'Merke dir deine Karten',
    peekDescription: 'Du darfst dir 2 Karten anschauen. Sobald du bereit bist, werden sie wieder verdeckt.',
    ready: 'Bereit',
    memoryIndicator: 'Gesehene Karte',
    tutorialTitle: 'Wie spielt man Dame?',
    tutorialObjective: 'Sammle so wenige Punkte wie möglich. Wer über 50 Punkte kommt, scheidet aus. Wer genau 50 Punkte erreicht, fällt auf 0 zurück!',
    tutorialSetup: 'Jeder Spieler bekommt 4 verdeckte Karten. Du siehst nur die ersten 2 Karten. Die anderen beiden bleiben verdeckt — merk sie dir!',
    tutorialSteps: {
      draw: 'Ziehe vom <strong>Ziehstapel</strong> oder vom <strong>Ablagestapel</strong>',
      swap: 'Tausche die gezogene Karte mit einer deiner Hand-Karten',
      discard: 'Oder lege die gezogene Karte direkt ab',
      end: 'Beende deinen Zug',
    },
    tutorialSpecialCards: 'Besondere Karten',
    tutorialJack: '<strong>Bube (J):</strong> Schaue eine verdeckte Karte an — deine eigene oder die eines Gegners',
    tutorialKing: '<strong>König (K):</strong> Schaue eine gegnerische Karte kurz an und tausche dann blind eine deiner Karten damit',
    tutorialQueen: '<strong>Dame (Q):</strong> Wenn du eine Dame ablegst, ziehst du selbst eine Strafkarte. Liegt eine Dame oben auf dem Ablagestapel, muss der nächste Spieler sie ziehen.',
    tutorialDameCall: 'Ab Runde 3 kannst du „Dame" rufen, wenn du glaubst, die wenigsten Punkte zu haben. Liegst du falsch, startest du die nächste Runde mit 5 Karten als Strafe!',
    tutorialExtraDiscard: 'Wenn die oberste Ablagekarte z.B. eine 7 ist und du auch eine 7 in der Hand hast, kannst du diese direkt ablegen — ohne zu ziehen!',
    tutorialShortcuts: 'Tastatur-Shortcuts',
    shortcutDraw: '<strong>Leertaste</strong> — Ziehen oder Ablegen',
    shortcutSelect: '<strong>1–4</strong> — Hand-Karte auswählen',
    shortcutConfirm: '<strong>Enter</strong> — Tausch bestätigen',
    shortcutCallDame: '<strong>D</strong> — Dame rufen',
    shortcutEndTurn: '<strong>Z / E</strong> — Zug beenden',
    shortcutClose: '<strong>Escape</strong> — Offenen Dialog schließen',
    startDialogTitle: 'Dame',
    startDialogSubtitle: 'Kartenspiel mit Bluff und Strategie',
    startDialogRules: 'Schnellstart',
    aiOpponents: 'Mit KI-Gegnern!',
    startDialogRuleList: {
      cards: 'Jeder hat 4 verdeckte Karten (sieht nur 2)',
      goal: 'Ziel: Möglichst wenige Punkte sammeln',
      over50: 'Über 50 Punkte = Ausgeschieden',
      exact50: 'Genau 50 Punkte = Reset auf 0!',
      jack: 'Bube: Eigene oder gegnerische Karte anschauen',
      king: 'König: Mit einem Gegner tauschen',
      queen: 'Dame: Strafkarte beim Ablegen; offene Dame muss vom nächsten Spieler genommen werden',
    },
    aiOpponentsDescription: '{{count}} KI-Gegner mit verschiedenen Schwierigkeitsgraden!',
    continueGame: 'Spiel fortsetzen',
    turnTimerExpired: 'Zeit abgelaufen! Strafkarte für {{name}}.',
    aceProphecy: 'Ass-Prophezeiung',
    tenStun: 'Zehn lässt den nächsten Spieler aussetzen',
    jackEffect: 'Bube-Effekt',
    jackEffectDescription: 'Wähle eine verdeckte Karte (eigene oder gegnerische), um sie anzuschauen:',
    jackEffectActivated: 'Bube-Effekt aktiviert',
    jackEffectHint: 'Du kannst eine deiner Karten anschauen.',
    kingEffect: 'König-Effekt',
    kingEffectDescription: 'Wähle eine deiner Karten, einen Gegner und dessen Karte. Du siehst die gegnerische Karte vor dem Tausch.',
    kingEffectActivated: 'König-Effekt aktiviert',
    kingEffectHint: 'Tausche eine Karte mit einem Gegner.',
    opponentCards: 'Karten von {{name}}',
    youReceive: 'Du erhältst:',
    cancel: 'Abbrechen',
    swap: 'Tauschen',
    score: 'Punktestand: {{score}}',
    roundEnded: 'Runde {{round}} beendet!',
    total: 'Gesamt: {{score}}',
    nextRound: 'Nächste Runde',
    penaltyCardReceived: 'Strafkarte erhalten!',
    dameCallWrong: 'Dame-Call falsch!',
    dameCallCorrect: 'Dame-Call richtig!',
    playerEliminated: 'Spieler ausgeschieden!',
    roundEndedToast: 'Runde beendet!',
    gotIt: 'Alles klar!',
    selectCard: 'Karte auswählen',
    selectStack: 'Stapel auswählen',
    tutorialObjectiveTitle: '🎯 Ziel des Spiels',
    tutorialSetupTitle: '🃏 Kartenverteilung',
    tutorialStepsTitle: '🎮 Dein Zug',
    tutorialDameCallTitle: '📢 Dame Call',
    tutorialExtraDiscardTitle: '🚀 Extra-Ablegen',
  },
  stats: {
    title: 'Spielstatistiken',
    games: 'Spiele',
    wins: 'Siege',
    rounds: 'Runden',
    bestRound: 'Beste Runde',
    dameCalls: 'Dame-Ansagen',
    successfulDameCalls: 'Erfolgreiche Ansagen',
    reset: 'Statistiken zurücksetzen',
    resetConfirm: 'Alle Statistiken wirklich zurücksetzen?',
  },
  settings: {
    title: 'Einstellungen',
    gameRules: 'Spielregeln',
    powerEffects: 'Power-Effekte',
    powerEffectsHint: 'Aktiviert erweiterte Karten-Effekte wie Ass und Zehn.',
    blitzMode: 'Blitz-Modus',
    turnTimer: 'Zug-Timer',
    ai: 'KI',
    aiDefault: 'Standard KI-Schwierigkeit',
    audioAndLanguage: 'Audio & Sprache',
    sound: 'Sound-Effekte',
    soundDescription: 'Karten, Gewinn, Strafen',
    music: 'Hintergrundmusik',
    musicDescription: 'Ambient Casino-Sounds',
    animations: 'Animationen',
    animationsDescription: 'Karten-Bewegungen, Effekte',
    aiSpeed: 'KI-Geschwindigkeit',
    aiSpeedDescription: 'Wartezeit auf KI-Züge',
    close: 'Schließen',
    on: 'An',
    off: 'Aus',
    speedFast: 'Schnell',
    speedNormal: 'Normal',
    speedSlow: 'Langsam',
  },
  rules: {
    title: 'Spielregeln',
    intro: 'DAME ist ein taktisches Memory-Kartenspiel mit Bluff-Element.',
    setup: 'Jeder Spieler bekommt 4 verdeckte Karten und darf sich nur 2 anschauen.',
    turn: 'Ziehe vom Zieh- oder Ablagestapel. Entscheide: behalten, tauschen oder ablegen.',
    extraDiscard: 'Passende Karten darfst du direkt mit ablegen. Hast du danach keine Karten mehr, wird automatisch Dame gerufen.',
    queen: 'Dame (Q): Strafkarte beim Ablegen; offene Dame muss vom nächsten Spieler genommen werden.',
    jack: 'Bube (J): Eigene oder gegnerische Karte anschauen.',
    king: 'König (K): Gegnerische Karte anschauen und gezielt tauschen — danach bleiben beide verdeckt.',
    dameCall: 'Dame rufen: Wer glaubt, die wenigsten Punkte zu haben, ruft „Dame". Bei falscher Ansage startet er die nächste Runde mit 5 statt 4 Karten.',
    points: 'Punkte: Über 50 = ausgeschieden. Genau 50 = Reset auf 0.',
    close: 'Schließen',
  },
};

const en = {
  app: {
    title: 'DAME',
    subtitle: 'Memory, Risk & Bluff',
    tagline: 'A game for 2–6 players • With AI opponents!',
  },
  menu: {
    startGame: 'Start Game',
    newGame: 'New Game',
    addHuman: 'Human',
    addAI: 'AI',
    players: 'Players',
    player: 'Player',
    difficulty: {
      easy: 'Easy',
      medium: 'Medium',
      hard: 'Hard',
    },
    rules: 'Rules',
    settings: 'Settings',
    language: 'Language',
  },
  game: {
    round: 'Round {{round}}',
    safePhase: 'Safe Phase',
    aiThinking: '{{name}} is thinking...',
    aiMustTakeQueen: '{{name}} must take the open Queen...',
    drawPile: 'Draw Pile',
    discardPile: 'Discard Pile',
    currentPlayer: 'Current Player',
    drawnCard: 'Drawn Card',
    points: 'pts',
    penaltyCards: 'Penalty cards',
    eliminated: 'OUT',
    yourTurn: "{{name}}'s turn.",
    startedDraw: 'Game started! Draw a card.',
    drawHint: 'Draw a card from the draw or discard pile.',
    extraDiscardSuccess: 'Extra card discarded!',
    extraDiscardFail: 'Wrong card! Penalty drawn.',
    autoDameCall: '{{name}} has no cards left and calls Dame!',
    swapped: 'Cards swapped!',
    gameStarted: 'Game started! Draw a card.',
    drawnCardPrompt: 'You drew {{rank}}. What do you want to do?',
    drawnFromDiscard: 'You take {{rank}} from the discard pile.',
    queenDiscarded: 'Queen discarded! You draw a penalty card.',
    jackDiscarded: 'Jack discarded! Choose a card to look at.',
    kingDiscarded: 'King discarded! Choose a player to swap with.',
    cardDiscarded: 'You discarded {{rank}}.',
    cardDiscardedGeneric: 'Card discarded.',
    cardSeen: 'You can now see this card.',
    mustTakeQueen: 'You must take the open Queen!',
    welcome: 'Welcome to DAME!',
    dameCalled: '{{name}} called Dame! Final round!',
    dameWrong: '{{name}} called Dame wrongly! Penalty card.',
    dameCorrect: '{{name}} called Dame correctly! Round won.',
    roundStarts: 'Round {{round}} starts! {{name}} begins.',
    gameOver: 'Game Over',
    gameOverWinner: 'Winner: {{name}}',
    youAreEliminated: 'You are eliminated!',
    eliminatedWatch: 'Watch the AI opponents play on...',
    isEliminated: '{{name}} is eliminated!',
    yourCards: 'Your cards:',
    chooseOpponent: 'Choose an opponent:',
    chooseOpponentCard: "Choose an opponent's card:",
    endTurn: 'End Turn',
    discard: 'Discard',
    callDame: 'Call Dame!',
    jack: 'Jack',
    king: 'King',
    swapConfirm: 'Confirm Swap',
    restart: 'Restart',
    backToMenu: 'Menu',
    tutorial: 'Tutorial',
    stats: 'Statistics',
    peekTitle: 'Memorize your cards',
    peekDescription: 'You may look at 2 cards. Once ready, they will be turned face-down again.',
    ready: 'Ready',
    memoryIndicator: 'Seen card',
    tutorialTitle: 'How to play DAME',
    tutorialObjective: 'Collect as few points as possible. Over 50 points = eliminated. Exactly 50 points = reset to 0!',
    tutorialSetup: 'Each player gets 4 face-down cards. You only see the first 2 cards. The other two stay face-down — memorize them!',
    tutorialSteps: {
      draw: 'Draw from the <strong>draw pile</strong> or the <strong>discard pile</strong>',
      swap: 'Swap the drawn card with one of your hand cards',
      discard: 'Or discard the drawn card directly',
      end: 'End your turn',
    },
    tutorialSpecialCards: 'Special cards',
    tutorialJack: '<strong>Jack (J):</strong> Look at a face-down card — your own or an opponent\'s',
    tutorialKing: '<strong>King (K):</strong> Briefly reveal an opponent card, then blindly swap one of your cards with it',
    tutorialQueen: '<strong>Queen (Q):</strong> When you discard a Queen, you draw a penalty card. If a Queen is on top of the discard pile, the next player must take it.',
    tutorialDameCall: 'From round 3 on you can call "Dame" if you believe you have the fewest points. If wrong, you start the next round with 5 cards as penalty!',
    tutorialExtraDiscard: 'If the top discard card is e.g. a 7 and you also have a 7 in hand, you can discard it directly — without drawing!',
    tutorialShortcuts: 'Keyboard shortcuts',
    shortcutDraw: '<strong>Space</strong> — Draw or discard',
    shortcutSelect: '<strong>1–4</strong> — Select hand card',
    shortcutConfirm: '<strong>Enter</strong> — Confirm swap',
    shortcutCallDame: '<strong>D</strong> — Call Dame',
    shortcutEndTurn: '<strong>Z / E</strong> — End turn',
    shortcutClose: '<strong>Escape</strong> — Close open dialog',
    startDialogTitle: 'DAME',
    startDialogSubtitle: 'Card game with bluff and strategy',
    startDialogRules: 'Quick start',
    aiOpponents: 'With AI opponents!',
    startDialogRuleList: {
      cards: 'Everyone has 4 face-down cards (sees only 2)',
      goal: 'Goal: Collect as few points as possible',
      over50: 'Over 50 points = eliminated',
      exact50: 'Exactly 50 points = reset to 0!',
      jack: 'Jack: Look at your own or an opponent card',
      king: 'King: Swap with an opponent',
      queen: 'Queen: Penalty card when discarded; open Queen must be taken by next player',
    },
    aiOpponentsDescription: '{{count}} AI opponents with different difficulty levels!',
    continueGame: 'Continue Game',
    turnTimerExpired: 'Time expired! Penalty card for {{name}}.',
    aceProphecy: 'Ace Prophecy',
    tenStun: 'Ten skips the next player',
    jackEffect: 'Jack Effect',
    jackEffectDescription: 'Choose a face-down card (your own or an opponent\'s) to look at:',
    jackEffectActivated: 'Jack Effect activated',
    jackEffectHint: 'You can look at one of your cards.',
    kingEffect: 'King Effect',
    kingEffectDescription: 'Choose one of your cards, an opponent, and their card. You see the opponent\'s card before swapping.',
    kingEffectActivated: 'King Effect activated',
    kingEffectHint: 'Swap a card with an opponent.',
    opponentCards: '{{name}}\'s cards',
    youReceive: 'You receive:',
    cancel: 'Cancel',
    swap: 'Swap',
    score: 'Score: {{score}}',
    roundEnded: 'Round {{round}} ended!',
    total: 'Total: {{score}}',
    nextRound: 'Next Round',
    penaltyCardReceived: 'Penalty card received!',
    dameCallWrong: 'Dame call wrong!',
    dameCallCorrect: 'Dame call correct!',
    playerEliminated: 'Player eliminated!',
    roundEndedToast: 'Round ended!',
    gotIt: 'Got it!',
    selectCard: 'Select card',
    selectStack: 'Select stack',
    tutorialObjectiveTitle: '🎯 Objective',
    tutorialSetupTitle: '🃏 Setup',
    tutorialStepsTitle: '🎮 Your Turn',
    tutorialDameCallTitle: '📢 Dame Call',
    tutorialExtraDiscardTitle: '🚀 Extra Discard',
  },
  stats: {
    title: 'Game Statistics',
    games: 'Games',
    wins: 'Wins',
    rounds: 'Rounds',
    bestRound: 'Best Round',
    dameCalls: 'Dame Calls',
    successfulDameCalls: 'Successful Calls',
    reset: 'Reset Statistics',
    resetConfirm: 'Really reset all statistics?',
  },
  settings: {
    title: 'Settings',
    gameRules: 'Game Rules',
    powerEffects: 'Power Effects',
    powerEffectsHint: 'Enables advanced card effects like Ace and Ten.',
    blitzMode: 'Blitz Mode',
    turnTimer: 'Turn Timer',
    ai: 'AI',
    aiDefault: 'Default AI Difficulty',
    audioAndLanguage: 'Audio & Language',
    sound: 'Sound effects',
    soundDescription: 'Cards, win, penalties',
    music: 'Background music',
    musicDescription: 'Ambient casino sounds',
    animations: 'Animations',
    animationsDescription: 'Card movements, effects',
    aiSpeed: 'AI speed',
    aiSpeedDescription: 'Delay between AI moves',
    close: 'Close',
    on: 'On',
    off: 'Off',
    speedFast: 'Fast',
    speedNormal: 'Normal',
    speedSlow: 'Slow',
  },
  rules: {
    title: 'Rules',
    intro: 'DAME is a tactical memory card game with bluffing elements.',
    setup: 'Each player gets 4 face-down cards and may look at only 2 of them.',
    turn: 'Draw from the draw or discard pile. Decide: keep, swap, or discard.',
    extraDiscard: 'Matching cards may be discarded immediately. If you have no cards left after, Dame is called automatically.',
    queen: 'Queen (Q): Penalty card when discarded; an open Queen must be taken by the next player.',
    jack: 'Jack (J): Look at your own or an opponent card.',
    king: 'King (K): Reveal an opponent card and swap it deliberately — both cards stay face-down.',
    dameCall: 'Call Dame: Whoever believes they have the lowest points calls "Dame". If wrong, they start the next round with 5 instead of 4 cards.',
    points: 'Points: Over 50 = eliminated. Exactly 50 = reset to 0.',
    close: 'Close',
  },
};

const dictionaries: Record<Language, Record<string, unknown>> = { de, en };

function interpolate(template: string, vars?: Record<string, string | number>): string {
  if (!vars) return template;
  return template.replace(/\{\{(\w+)\}\}/g, (_, key) => String(vars[key] ?? `{{${key}}}`));
}

interface I18nContextValue {
  language: Language;
  setLanguage: (lang: Language) => void;
  t: (key: string, vars?: Record<string, string | number>) => string;
}

const I18nContext = createContext<I18nContextValue | null>(null);

function loadLanguage(): Language {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw === 'en' || raw === 'de') return raw;
  } catch {
    // ignore
  }
  const browserLang = navigator.language.slice(0, 2);
  return browserLang === 'de' ? 'de' : 'en';
}

function saveLanguage(lang: Language): void {
  try {
    localStorage.setItem(STORAGE_KEY, lang);
  } catch {
    // ignore
  }
}

export function I18nProvider({ children }: { children: ReactNode }) {
  const [language, setLanguageState] = useState<Language>(() => loadLanguage());

  const setLanguage = useCallback((lang: Language) => {
    setLanguageState(lang);
    saveLanguage(lang);
  }, []);

  const t = useCallback(
    (key: string, vars?: Record<string, string | number>) => {
      const value = getNested(dictionaries[language], key);
      return interpolate(value ?? key, vars);
    },
    [language]
  );

  useEffect(() => {
    document.documentElement.lang = language;
  }, [language]);

  return (
    <I18nContext.Provider value={{ language, setLanguage, t }}>
      {children}
    </I18nContext.Provider>
  );
}

export function useI18n(): I18nContextValue {
  const ctx = useContext(I18nContext);
  if (!ctx) {
    throw new Error('useI18n must be used within an I18nProvider');
  }
  return ctx;
}
