import { useState, useCallback, useEffect } from 'react';

export type AISpeed = 'fast' | 'normal' | 'slow';

interface GameSettings {
  soundEnabled: boolean;
  animationsEnabled: boolean;
  aiSpeed: AISpeed;
  musicEnabled: boolean;
}

const STORAGE_KEY = 'dame-game-settings';

const DEFAULT_SETTINGS: GameSettings = {
  soundEnabled: true,
  animationsEnabled: true,
  aiSpeed: 'normal',
  musicEnabled: true,
};

function loadSettings(): GameSettings {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      return { ...DEFAULT_SETTINGS, ...JSON.parse(raw) };
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

  const setAiSpeed = useCallback((speed: AISpeed) => {
    setSettings((prev) => ({ ...prev, aiSpeed: speed }));
  }, []);

  return {
    settings,
    toggleSound,
    toggleAnimations,
    toggleMusic,
    setAiSpeed,
  };
}

export type { GameSettings };
