import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import { type GameStats } from '@/lib/stats';
import { useI18n } from '@/lib/i18n';
import { BarChart3 } from 'lucide-react';

interface StatsPanelProps {
  stats: GameStats;
  onReset?: () => void;
}

export function StatsPanel({ stats, onReset }: StatsPanelProps) {
  const { t } = useI18n();
  const winRate =
    stats.gamesPlayed > 0 ? Math.round((stats.gamesWon / stats.gamesPlayed) * 100) : 0;

  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm" className="gap-2">
          <BarChart3 className="h-4 w-4" />
          {t('game.stats')}
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-md max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{t('stats.title')}</DialogTitle>
        </DialogHeader>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4 py-4 text-sm">
          <div className="rounded border p-3">
            <div className="text-muted-foreground">{t('stats.games')}</div>
            <div className="text-2xl font-bold">{stats.gamesPlayed}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-muted-foreground">{t('stats.wins')}</div>
            <div className="text-2xl font-bold">{winRate}%</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-muted-foreground">{t('stats.rounds')}</div>
            <div className="text-2xl font-bold">{stats.roundsPlayed}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-muted-foreground">{t('stats.bestRound')}</div>
            <div className="text-2xl font-bold">{stats.bestRoundScore ?? '—'}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-muted-foreground">{t('stats.dameCalls')}</div>
            <div className="text-2xl font-bold">{stats.dameCalls}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-muted-foreground">{t('stats.successfulDameCalls')}</div>
            <div className="text-2xl font-bold">{stats.successfulDameCalls}</div>
          </div>
        </div>
        {onReset && (
          <Button
            variant="destructive"
            size="default"
            className="w-full h-11"
            onClick={() => {
              if (window.confirm(t('stats.resetConfirm'))) {
                onReset?.();
              }
            }}
          >
            {t('stats.reset')}
          </Button>
        )}
      </DialogContent>
    </Dialog>
  );
}
