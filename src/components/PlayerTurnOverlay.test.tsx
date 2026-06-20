import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { I18nProvider } from '@/lib/i18n';
import { PlayerTurnOverlay } from './PlayerTurnOverlay';

describe('PlayerTurnOverlay', () => {
  it('shows player name and calls onReady', async () => {
    const onReady = vi.fn();
    render(
      <I18nProvider language="en">
        <PlayerTurnOverlay playerName="Anna" onReady={onReady} />
      </I18nProvider>
    );

    expect(screen.getByText(/Anna/)).toBeInTheDocument();
    expect(screen.getByText(/Other players, please do not look/)).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /ready/i }));
    expect(onReady).toHaveBeenCalled();
  });
});
