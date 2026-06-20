import { useI18n } from '@/lib/i18n';
import { Button } from '@/components/ui/button';

interface PlayerTurnOverlayProps {
  playerName: string;
  onReady: () => void;
}

export function PlayerTurnOverlay({ playerName, onReady }: PlayerTurnOverlayProps) {
  const { t } = useI18n();

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80">
      <div className="text-center space-y-6 p-8 rounded-xl bg-slate-900 border border-slate-700">
        <h2 className="text-2xl font-bold text-white">
          {t('hotSeat.playerTurn', { name: playerName })}
        </h2>
        <p className="text-slate-400">{t('hotSeat.lookAway')}</p>
        <Button size="lg" onClick={onReady}>
          {t('hotSeat.ready')}
        </Button>
      </div>
    </div>
  );
}
