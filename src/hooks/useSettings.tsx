/* eslint-disable react-refresh/only-export-components */
import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from 'react';
import type { GameSettings, AISpeed, AIDifficulty, TurnTimerSeconds } from '@/lib/settings';
import { DEFAULT_SETTINGS } from '@/lib/settings';
import {
  setMusicVolume as setSoundMusicVolume,
  setEffectsVolume as setSoundEffectsVolume,
} from '@/lib/sounds';

const STORAGE_KEY = 'dame-game-settings';

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
  return { ...DEFAULT_SETTINGS };
}

function saveSettings(settings: GameSettings): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
  } catch {
    // ignore
  }
}

interface SettingsContextValue {
  settings: GameSettings;
  toggleSound: () => void;
  toggleAnimations: () => void;
  toggleMusic: () => void;
  setMusicVolume: (value: number) => void;
  setEffectsVolume: (value: number) => void;
  setAiSpeed: (speed: AISpeed) => void;
  setDefaultAIDifficulty: (difficulty: AIDifficulty) => void;
  toggleTurnTimer: () => void;
  setTurnTimerSeconds: (seconds: TurnTimerSeconds) => void;
  togglePowerEffects: () => void;
  toggleTable3d: () => void;
}

const SettingsContext = createContext<SettingsContextValue | null>(null);

export function SettingsProvider({ children }: { children: ReactNode }) {
  const [settings, setSettings] = useState<GameSettings>(() => {
    const loaded = loadSettings();
    // Geladene Lautstärken direkt an Sound-Engine übergeben
    setSoundMusicVolume(loaded.musicVolume / 100);
    setSoundEffectsVolume(loaded.effectsVolume / 100);
    return loaded;
  });

  useEffect(() => {
    saveSettings(settings);
    setSoundMusicVolume(settings.musicVolume / 100);
    setSoundEffectsVolume(settings.effectsVolume / 100);
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
    setSettings((prev) => ({ ...prev, musicVolume: clamped }));
  }, []);

  const setEffectsVolume = useCallback((value: number) => {
    const clamped = Math.max(0, Math.min(100, value));
    setSettings((prev) => ({ ...prev, effectsVolume: clamped }));
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
    setSettings((prev) => ({ ...prev, table3d: !prev.table3d }));
  }, []);

  return (
    <SettingsContext.Provider
      value={{
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
      }}
    >
      {children}
    </SettingsContext.Provider>
  );
}

export function useSettings(): SettingsContextValue {
  const ctx = useContext(SettingsContext);
  if (!ctx) {
    throw new Error('useSettings must be used within a SettingsProvider');
  }
  return ctx;
}

export type { GameSettings, AISpeed, AIDifficulty, TurnTimerSeconds };
