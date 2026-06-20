import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as React from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { act } from 'react';
import { I18nProvider } from '@/lib/i18n';
import { useGameEngine, type PlayerConfig } from './useGameEngine';

(globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

interface RenderHookResult<T> {
  result: { current: T };
  rerender: () => Promise<void>;
  unmount: () => Promise<void>;
}

let cleanupFns: Array<() => Promise<void>> = [];

afterEach(async () => {
  for (const cleanup of cleanupFns) {
    await cleanup();
  }
  cleanupFns = [];
});

function renderHook<T>(callback: () => T): RenderHookResult<T> {
  const result = { current: null as T };

  function HookComponent() {
    result.current = callback();
    return null;
  }

  function Wrapper() {
    return React.createElement(I18nProvider, null, React.createElement(HookComponent));
  }

  const container = document.createElement('div');
  document.body.appendChild(container);
  const root: Root = createRoot(container);

  act(() => {
    root.render(React.createElement(Wrapper));
  });

  const rerender = async () => {
    await act(async () => {
      root.render(React.createElement(Wrapper));
    });
  };

  const unmount = async () => {
    await act(async () => {
      root.unmount();
    });
    container.remove();
  };

  cleanupFns.push(unmount);

  return {
    result,
    rerender,
    unmount,
  };
}

describe('useGameEngine', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('exportiert den Hook und die PlayerConfig', () => {
    expect(useGameEngine).toBeInstanceOf(Function);
  });

  it('startet ein Spiel mit den übergebenen Spieler-Konfigurationen', async () => {
    const configs: PlayerConfig[] = [
      { name: 'Mensch', isAI: false, isHuman: true },
      { name: 'KI', isAI: true, isHuman: false, difficulty: 'easy' },
    ];
    const { result } = renderHook(() => useGameEngine(configs));

    await act(async () => {
      result.current.startGame(configs);
    });

    expect(result.current.gameState).not.toBeNull();
    expect(result.current.gameState!.players).toHaveLength(2);
    expect(result.current.gameState!.players[0].name).toBe('Mensch');
    expect(result.current.gameState!.players[0].isHuman).toBe(true);
    expect(result.current.gameState!.players[0].isAI).toBe(false);
    expect(result.current.gameState!.players[1].name).toBe('KI');
    expect(result.current.gameState!.players[1].isAI).toBe(true);
    expect(result.current.gameState!.players[1].isHuman).toBe(false);
    expect(result.current.isCurrentPlayerHuman).toBe(true);
    expect(result.current.winner).toBeNull();
  });

  it('erkennt menschliche und KI-Spieler anhand der Konfiguration', async () => {
    const configs: PlayerConfig[] = [
      { name: 'Spieler 1', isAI: false, isHuman: true },
      { name: 'Spieler 2', isAI: false, isHuman: true },
      { name: 'KI-Hard', isAI: true, isHuman: false, difficulty: 'hard' },
    ];
    const { result } = renderHook(() => useGameEngine(configs));

    await act(async () => {
      result.current.startGame(configs);
    });

    const humanCount = result.current.gameState!.players.filter((p) => p.isHuman && !p.isAI).length;
    const aiCount = result.current.gameState!.players.filter((p) => p.isAI).length;

    expect(humanCount).toBe(2);
    expect(aiCount).toBe(1);
    expect(result.current.currentAIDifficulty).toBeNull();
  });

  it('setzt das Spiel zurück', async () => {
    const { result } = renderHook(() =>
      useGameEngine([
        { name: 'Mensch', isAI: false, isHuman: true },
        { name: 'KI', isAI: true, isHuman: false, difficulty: 'medium' },
      ])
    );

    await act(async () => {
      result.current.startGame([
        { name: 'Mensch', isAI: false, isHuman: true },
        { name: 'KI', isAI: true, isHuman: false, difficulty: 'medium' },
      ]);
    });

    expect(result.current.gameState).not.toBeNull();

    await act(async () => {
      result.current.resetGame();
    });

    expect(result.current.gameState).toBeNull();
    expect(result.current.drawnCard).toBeNull();
    expect(result.current.isCurrentPlayerHuman).toBe(false);
    expect(result.current.turnOverlayOpen).toBe(false);
  });
});
