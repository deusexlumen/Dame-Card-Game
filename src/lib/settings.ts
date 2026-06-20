export type AISpeed = 'fast' | 'normal' | 'slow';
export type AIDifficulty = 'easy' | 'medium' | 'hard';
export type TurnTimerSeconds = 15 | 30 | 60;

export interface GameSettings {
  soundEnabled: boolean;
  animationsEnabled: boolean;
  aiSpeed: AISpeed;
  musicEnabled: boolean;
  musicVolume: number;
  effectsVolume: number;
  defaultAIDifficulty: AIDifficulty;
  turnTimer: boolean;
  turnTimerSeconds: TurnTimerSeconds;
  powerEffects: boolean;
  table3d: boolean;
}

export const DEFAULT_SETTINGS: GameSettings = {
  soundEnabled: true,
  animationsEnabled: true,
  aiSpeed: 'normal',
  musicEnabled: true,
  musicVolume: 50,
  effectsVolume: 50,
  defaultAIDifficulty: 'medium',
  turnTimer: false,
  turnTimerSeconds: 30,
  powerEffects: false,
  table3d: false,
};

// Globale Settings-Referenz für Nicht-React-Code (Sound-Engine)
let globalSettings: GameSettings = { ...DEFAULT_SETTINGS };

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
