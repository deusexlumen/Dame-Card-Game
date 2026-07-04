import * as React from 'react';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeAll, describe, expect, it, vi } from 'vitest';
import { I18nProvider } from '@/lib/i18n';
import { HotSeatSetup } from './HotSeatSetup';

beforeAll(() => {
  HTMLElement.prototype.scrollIntoView = vi.fn();
  Element.prototype.setPointerCapture = vi.fn();
  Element.prototype.releasePointerCapture = vi.fn();
  Element.prototype.hasPointerCapture = vi.fn();
});

const wrapper = ({ children }: { children: React.ReactNode }) => (
  <I18nProvider language="en">{children}</I18nProvider>
);

describe('HotSeatSetup', () => {
  it('calls onStart with configured players', async () => {
    const user = userEvent.setup();
    const onStart = vi.fn();
    render(<HotSeatSetup onStart={onStart} onCancel={() => {}} />, { wrapper });

    await user.click(screen.getByRole('button', { name: 'Start game' }));

    expect(onStart).toHaveBeenCalledWith([
      expect.objectContaining({ name: 'Spieler 1', isAI: false, isHuman: true }),
      expect.objectContaining({ name: 'Spieler 2', isAI: false, isHuman: true }),
    ]);
  });

  it('changes player count from 2 to 3 and 4', async () => {
    const user = userEvent.setup();
    render(<HotSeatSetup onStart={vi.fn()} onCancel={() => {}} />, { wrapper });

    expect(screen.getAllByLabelText(/Player name/i)).toHaveLength(2);

    await user.click(screen.getByRole('button', { name: '3' }));
    expect(screen.getAllByLabelText(/Player name/i)).toHaveLength(3);

    await user.click(screen.getByRole('button', { name: '4' }));
    expect(screen.getAllByLabelText(/Player name/i)).toHaveLength(4);
  });

  it('toggles a player to AI and selects difficulty', async () => {
    const user = userEvent.setup();
    const onStart = vi.fn();
    render(<HotSeatSetup onStart={onStart} onCancel={() => {}} />, { wrapper });

    const typeSelects = screen.getAllByLabelText('Player type');
    await user.click(typeSelects[0]);
    await user.click(screen.getByRole('option', { name: 'AI' }));

    const difficultySelects = screen.getAllByLabelText('Difficulty');
    expect(difficultySelects).toHaveLength(1);

    await user.click(difficultySelects[0]);
    await user.click(screen.getByRole('option', { name: 'Hard' }));

    await user.click(screen.getByRole('button', { name: 'Start game' }));

    expect(onStart).toHaveBeenCalledWith([
      expect.objectContaining({
        name: 'Spieler 1',
        isAI: true,
        isHuman: false,
        difficulty: 'hard',
      }),
      expect.objectContaining({
        name: 'Spieler 2',
        isAI: false,
        isHuman: true,
      }),
    ]);
  });

  it('edits player names', async () => {
    const user = userEvent.setup();
    const onStart = vi.fn();
    render(<HotSeatSetup onStart={onStart} onCancel={() => {}} />, { wrapper });

    const inputs = screen.getAllByLabelText(/Player name/i);
    await user.clear(inputs[0]);
    await user.type(inputs[0], 'Anna');
    await user.clear(inputs[1]);
    await user.type(inputs[1], 'Ben');

    await user.click(screen.getByRole('button', { name: 'Start game' }));

    expect(onStart).toHaveBeenCalledWith([
      expect.objectContaining({ name: 'Anna', isAI: false, isHuman: true }),
      expect.objectContaining({ name: 'Ben', isAI: false, isHuman: true }),
    ]);
  });

  it('disables start button when a name is empty', async () => {
    const user = userEvent.setup();
    render(<HotSeatSetup onStart={vi.fn()} onCancel={() => {}} />, { wrapper });

    const inputs = screen.getAllByLabelText(/Player name/i);
    await user.clear(inputs[0]);

    expect(
      (screen.getByRole('button', { name: 'Start game' }) as HTMLButtonElement)
        .disabled
    ).toBe(true);
  });

  it('disables start button when all players are AI', async () => {
    const user = userEvent.setup();
    render(<HotSeatSetup onStart={vi.fn()} onCancel={() => {}} />, { wrapper });

    const typeSelects = screen.getAllByLabelText('Player type');
    await user.click(typeSelects[0]);
    await user.click(screen.getByRole('option', { name: 'AI' }));

    await user.click(typeSelects[1]);
    await user.click(screen.getByRole('option', { name: 'AI' }));

    expect(
      (screen.getByRole('button', { name: 'Start game' }) as HTMLButtonElement)
        .disabled
    ).toBe(true);
  });

  it('calls onCancel when cancel button clicked', async () => {
    const user = userEvent.setup();
    const onCancel = vi.fn();
    render(<HotSeatSetup onStart={vi.fn()} onCancel={onCancel} />, { wrapper });

    await user.click(screen.getByRole('button', { name: 'Cancel' }));

    expect(onCancel).toHaveBeenCalled();
  });
});
