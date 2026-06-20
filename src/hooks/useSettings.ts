import { useState, useCallback, useEffect } from 'react';
import {
  setMusicVolume as setSoundMusicVolume,
  setEffectsVolume as setSoundEffectsVolume,
} from '@/lib/sounds';
import { setGlobalSettings } from '@/lib/settings';

export type AISpeed = 'fast' | 'normal' | 'slow';
export type AIDifficulty = 'easy' | 'medium' | 'hard';
export type TurnTimerSeconds = 15 | 30 | 60;

interface GameSettings {
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

const STORAGE_KEY = 'dame-game-settings';

const DEFAULT_SETTINGS: GameSettings = {
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

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function loadSettings(): GameSettings {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      if (isPlainObject(parsed)) {
        return { ...DEFAULT_SETTINGS, ...parsed };
      }
    }
  } catch {
    // ignore
  }
  return DEFAULT_SETTINGS;
}

function saveSettings(settings: GameSettings): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
  } catch {
    // ignore
  }
}

export function useSettings() {
  const [settings, setSettings] = useState<GameSettings>(loadSettings);

  useEffect(() => {
    saveSettings(settings);
  }, [settings]);

  const toggleSound = useCallback(() => {
    setSettings((prev) => ({ ...prev, soundEnabled: !prev.soundEnabled }));
  }, []);

  const toggleAnimations = useCallback(() => {
    setSettings((prev) => ({ ...prev, animationsEnabled: !prev.animationsEnabled }));
  }, []);

  const toggleMusic = useCallback(() => {
    setSettings((prev) => ({ ...prev, musicEnabled: !prev.musicEnabled }));
  }, []);

  const setMusicVolume = useCallback((value: number) => {
    const clamped = Math.max(0, Math.min(100, value));
    setSettings((prev) => {
      const next = { ...prev, musicVolume: clamped };
      setGlobalSettings(next);
      return next;
    });
    setSoundMusicVolume(clamped / 100);
  }, []);

  const setEffectsVolume = useCallback((value: number) => {
    const clamped = Math.max(0, Math.min(100, value));
    setSettings((prev) => {
      const next = { ...prev, effectsVolume: clamped };
      setGlobalSettings(next);
      return next;
    });
    setSoundEffectsVolume(clamped / 100);
  }, []);

  const setAiSpeed = useCallback((speed: AISpeed) => {
    setSettings((prev) => ({ ...prev, aiSpeed: speed }));
  }, []);

  const setDefaultAIDifficulty = useCallback((difficulty: AIDifficulty) => {
    setSettings((prev) => ({ ...prev, defaultAIDifficulty: difficulty }));
  }, []);

  const toggleTurnTimer = useCallback(() => {
    setSettings((prev) => ({ ...prev, turnTimer: !prev.turnTimer }));
  }, []);

  const setTurnTimerSeconds = useCallback((seconds: TurnTimerSeconds) => {
    setSettings((prev) => ({ ...prev, turnTimerSeconds: seconds }));
  }, []);

  const togglePowerEffects = useCallback(() => {
    setSettings((prev) => ({ ...prev, powerEffects: !prev.powerEffects }));
  }, []);

  const toggleTable3d = useCallback(() => {
    setSettings((prev) => {
      const next = { ...prev, table3d: !prev.table3d };
      setGlobalSettings(next);
      return next;
    });
  }, []);

  return {
    settings,
    toggleSound,
    toggleAnimations,
    toggleMusic,
    setMusicVolume,
    setEffectsVolume,
    setAiSpeed,
    setDefaultAIDifficulty,
    toggleTurnTimer,
    setTurnTimerSeconds,
    togglePowerEffects,
    toggleTable3d,
  };
}

export type { GameSettings };
