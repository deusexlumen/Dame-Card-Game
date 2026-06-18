import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import { type GameStats } from '@/lib/stats';
import { BarChart3 } from 'lucide-react';

interface StatsPanelProps {
  stats: GameStats;
  onReset?: () => void;
}

export function StatsPanel({ stats, onReset }: StatsPanelProps) {
  const winRate =
    stats.gamesPlayed > 0 ? Math.round((stats.gamesWon / stats.gamesPlayed) * 100) : 0;

  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm" className="gap-2">
          <BarChart3 className="h-4 w-4" />
          Statistiken
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Spielstatistiken</DialogTitle>
        </DialogHeader>
        <div className="grid grid-cols-2 gap-4 py-4 text-sm">
          <div className="rounded border p-3">
            <div className="text-muted-foreground">Spiele</div>
            <div className="text-2xl font-bold">{stats.gamesPlayed}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-muted-foreground">Siege</div>
            <div className="text-2xl font-bold">{winRate}%</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-muted-foreground">Runden</div>
            <div className="text-2xl font-bold">{stats.roundsPlayed}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-muted-foreground">Beste Runde</div>
            <div className="text-2xl font-bold">{stats.bestRoundScore ?? '—'}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-muted-foreground">Dame-Ansagen</div>
            <div className="text-2xl font-bold">{stats.dameCalls}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-muted-foreground">Erfolgreiche Ansagen</div>
            <div className="text-2xl font-bold">{stats.successfulDameCalls}</div>
          </div>
        </div>
        {onReset && (
          <Button
            variant="destructive"
            size="sm"
            onClick={() => {
              if (window.confirm('Alle Statistiken wirklich zurücksetzen?')) {
                onReset?.();
              }
            }}
          >
            Statistiken zurücksetzen
          </Button>
        )}
      </DialogContent>
    </Dialog>
  );
}
