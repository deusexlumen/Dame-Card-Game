import { useMemo, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { type PlayerConfig } from '@/hooks/useGameEngine';
import { type AIDifficulty } from '@/lib/aiPlayer';
import { useI18n } from '@/lib/i18n';

export interface HotSeatSetupProps {
  onStart: (players: PlayerConfig[]) => void;
  onCancel: () => void;
}

type PlayerType = 'human' | 'ai';

interface SetupPlayer {
  name: string;
  type: PlayerType;
  difficulty: AIDifficulty;
}

const DEFAULT_DIFFICULTY: AIDifficulty = 'medium';
const PLAYER_COUNTS = [2, 3, 4] as const;

export function HotSeatSetup({ onStart, onCancel }: HotSeatSetupProps) {
  const { t } = useI18n();

  const [players, setPlayers] = useState<SetupPlayer[]>([
    { name: 'Spieler 1', type: 'human', difficulty: DEFAULT_DIFFICULTY },
    { name: 'Spieler 2', type: 'human', difficulty: DEFAULT_DIFFICULTY },
  ]);

  const title = t('hotSeat.setupTitle');
  const playersLabel = t('hotSeat.players');
  const playerNameLabel = t('hotSeat.playerName');
  const playerTypeLabel = t('hotSeat.playerType');
  const difficultyLabel = t('hotSeat.difficulty');
  const humanLabel = t('hotSeat.human');
  const aiLabel = t('hotSeat.ai');
  const startLabel = t('hotSeat.start');
  const cancelLabel = t('common.cancel');
  const easyLabel = t('menu.difficulty.easy');
  const mediumLabel = t('menu.difficulty.medium');
  const hardLabel = t('menu.difficulty.hard');

  const isValid = useMemo(() => {
    const allNamesNonEmpty = players.every((p) => p.name.trim().length > 0);
    const hasHuman = players.some((p) => p.type === 'human');
    return allNamesNonEmpty && hasHuman;
  }, [players]);

  const handlePlayerCountChange = (count: number) => {
    setPlayers((prev) => {
      if (count === prev.length) return prev;
      if (count > prev.length) {
        const additional: SetupPlayer[] = Array.from(
          { length: count - prev.length },
          (_, i) => ({
            name: `Spieler ${prev.length + i + 1}`,
            type: 'human',
            difficulty: DEFAULT_DIFFICULTY,
          })
        );
        return [...prev, ...additional];
      }
      return prev.slice(0, count);
    });
  };

  const updatePlayer = (index: number, updates: Partial<SetupPlayer>) => {
    setPlayers((prev) =>
      prev.map((p, i) => {
        if (i !== index) return p;
        return { ...p, ...updates };
      })
    );
  };

  const handleStart = () => {
    if (!isValid) return;

    const configs: PlayerConfig[] = players.map((p) => ({
      name: p.name.trim(),
      isAI: p.type === 'ai',
      isHuman: p.type === 'human',
      difficulty: p.type === 'ai' ? p.difficulty : undefined,
    }));

    onStart(configs);
  };

  return (
    <Card className="w-full max-w-md border-border/50 bg-card/95 shadow-lg">
      <CardHeader className="pb-4">
        <CardTitle className="text-center text-xl">{title}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        <div className="space-y-2">
          <label className="text-sm font-medium">{playersLabel}</label>
          <div className="flex gap-2">
            {PLAYER_COUNTS.map((count) => (
              <Button
                key={count}
                type="button"
                variant={players.length === count ? 'default' : 'outline'}
                size="sm"
                onClick={() => handlePlayerCountChange(count)}
                aria-pressed={players.length === count}
              >
                {count}
              </Button>
            ))}
          </div>
        </div>

        <div className="space-y-4">
          {players.map((player, index) => {
            const nameInputId = `hotseat-player-name-${index}`;
            return (
              <div
                key={index}
                className="rounded-lg border border-border/50 bg-background/50 p-4"
              >
                <div className="mb-3 flex items-center justify-between">
                  <label
                    htmlFor={nameInputId}
                    className="text-sm font-semibold"
                  >
                    {playerNameLabel} {index + 1}
                  </label>
                </div>

                <div className="space-y-3">
                  <Input
                    id={nameInputId}
                    value={player.name}
                    onChange={(e) =>
                      updatePlayer(index, { name: e.target.value })
                    }
                    placeholder={`${playerNameLabel} ${index + 1}`}
                    aria-label={`${playerNameLabel} ${index + 1}`}
                  />

                  <Select
                    value={player.type}
                    onValueChange={(value: PlayerType) =>
                      updatePlayer(index, { type: value })
                    }
                  >
                    <SelectTrigger className="w-full" aria-label={playerTypeLabel}>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="human">{humanLabel}</SelectItem>
                      <SelectItem value="ai">{aiLabel}</SelectItem>
                    </SelectContent>
                  </Select>

                  {player.type === 'ai' && (
                    <Select
                      value={player.difficulty}
                      onValueChange={(value: AIDifficulty) =>
                        updatePlayer(index, { difficulty: value })
                      }
                    >
                      <SelectTrigger className="w-full" aria-label={difficultyLabel}>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="easy">{easyLabel}</SelectItem>
                        <SelectItem value="medium">{mediumLabel}</SelectItem>
                        <SelectItem value="hard">{hardLabel}</SelectItem>
                      </SelectContent>
                    </Select>
                  )}
                </div>
              </div>
            );
          })}
        </div>

        <div className="flex gap-3 pt-2">
          <Button
            type="button"
            variant="outline"
            className="flex-1"
            onClick={onCancel}
          >
            {cancelLabel}
          </Button>
          <Button
            type="button"
            className="flex-1"
            disabled={!isValid}
            onClick={handleStart}
          >
            {startLabel}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
