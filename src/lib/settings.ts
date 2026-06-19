import type { GameSettings } from '@/hooks/useSettings';

// Globale Settings-Referenz für Nicht-React-Code (Sound-Engine)
let globalSettings: GameSettings = {
  soundEnabled: true,
  animationsEnabled: true,
  aiSpeed: 'normal',
  musicEnabled: true,
  defaultAIDifficulty: 'medium',
  turnTimer: false,
  turnTimerSeconds: 30,
  powerEffects: false,
};

export function setGlobalSettings(settings: GameSettings): void {
  globalSettings = settings;
}

export function getGlobalSettings(): GameSettings {
  return globalSettings;
}

export function isSoundEnabled(): boolean {
  return globalSettings.soundEnabled;
}

export function isAnimationsEnabled(): boolean {
  return globalSettings.animationsEnabled;
}

export function isMusicEnabled(): boolean {
  return globalSettings.musicEnabled;
}
