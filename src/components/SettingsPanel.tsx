import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Switch } from '@/components/ui/switch';
import { Label } from '@/components/ui/label';
import { useSettings, type AIDifficulty, type AISpeed, type TurnTimerSeconds } from '@/hooks/useSettings';
import { useI18n } from '@/lib/i18n';
import { ArrowLeft, Zap, Brain, Target, Clock, Dices, Volume2, Music, Sparkles, Globe } from 'lucide-react';
import { cn } from '@/lib/utils';

interface SettingsPanelProps {
  onClose: () => void;
}

export function SettingsPanel({ onClose }: SettingsPanelProps) {
  const {
    settings,
    toggleSound,
    toggleMusic,
    toggleAnimations,
    setAiSpeed,
    setDefaultAIDifficulty,
    toggleTurnTimer,
    setTurnTimerSeconds,
    togglePowerEffects,
  } = useSettings();
  const { t, language, setLanguage } = useI18n();

  const aiDifficulties: AIDifficulty[] = ['easy', 'medium', 'hard'];
  const aiSpeeds: AISpeed[] = ['fast', 'normal', 'slow'];
  const timerOptions: TurnTimerSeconds[] = [15, 30, 60];

  return (
    <div className="min-h-screen terminal-grid relative flex items-center justify-center p-4">
      <div className="max-w-2xl w-full">
        <Card className="shadow-2xl bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))]">
          <CardHeader>
            <CardTitle className="text-2xl flex items-center gap-2 font-mono terminal-glow">
              <Dices className="w-6 h-6" />
              {t('settings.title')}
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            {/* Spielregeln */}
            <section className="space-y-3">
              <h3 className="text-sm font-bold uppercase tracking-wider text-[hsl(var(--terminal-cyan))]">
                {t('settings.gameRules')}
              </h3>
              <div className="flex items-start justify-between p-3 bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.15)] rounded-lg">
                <div className="space-y-1">
                  <div className="flex items-center gap-2">
                    <Sparkles className="w-4 h-4 text-[hsl(var(--terminal-amber))]" />
                    <Label htmlFor="power-effects" className="text-sm font-medium text-[hsl(var(--terminal-green))]">
                      {t('settings.powerEffects')}
                    </Label>
                  </div>
                  <p className="text-xs text-[hsl(var(--terminal-green)/0.6)]">
                    {t('settings.powerEffectsHint')}
                  </p>
                </div>
                <Switch
                  id="power-effects"
                  checked={settings.powerEffects}
                  onCheckedChange={togglePowerEffects}
                  aria-label={t('settings.powerEffects')}
                />
              </div>
            </section>

            {/* Blitz-Modus */}
            <section className="space-y-3">
              <h3 className="text-sm font-bold uppercase tracking-wider text-[hsl(var(--terminal-cyan))]">
                {t('settings.blitzMode')}
              </h3>
              <div className="flex items-center justify-between p-3 bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.15)] rounded-lg">
                <div className="flex items-center gap-2">
                  <Clock className="w-4 h-4 text-[hsl(var(--terminal-red))]" />
                  <Label htmlFor="turn-timer" className="text-sm font-medium text-[hsl(var(--terminal-green))]">
                    {t('settings.turnTimer')}
                  </Label>
                </div>
                <Switch
                  id="turn-timer"
                  checked={settings.turnTimer}
                  onCheckedChange={toggleTurnTimer}
                  aria-label={t('settings.turnTimer')}
                />
              </div>
              {settings.turnTimer && (
                <div className="flex gap-2 pl-4">
                  {timerOptions.map((seconds) => (
                    <Button
                      key={seconds}
                      variant={settings.turnTimerSeconds === seconds ? 'default' : 'outline'}
                      size="sm"
                      onClick={() => setTurnTimerSeconds(seconds)}
                      className={cn(
                        'flex-1 text-xs',
                        settings.turnTimerSeconds !== seconds && 'border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))] hover:bg-[hsl(var(--terminal-green)/0.1)]'
                      )}
                    >
                      {seconds}s
                    </Button>
                  ))}
                </div>
              )}
            </section>

            {/* KI */}
            <section className="space-y-3">
              <h3 className="text-sm font-bold uppercase tracking-wider text-[hsl(var(--terminal-cyan))]">
                {t('settings.ai')}
              </h3>
              <div className="p-3 bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.15)] rounded-lg space-y-2">
                <Label className="text-sm font-medium text-[hsl(var(--terminal-green))]">
                  {t('settings.aiDefault')}
                </Label>
                <div className="flex gap-2">
                  {aiDifficulties.map((diff) => (
                    <Button
                      key={diff}
                      variant={settings.defaultAIDifficulty === diff ? 'default' : 'outline'}
                      size="sm"
                      onClick={() => setDefaultAIDifficulty(diff)}
                      className={cn(
                        'flex-1 text-xs',
                        settings.defaultAIDifficulty !== diff && 'border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))] hover:bg-[hsl(var(--terminal-green)/0.1)]'
                      )}
                    >
                      {diff === 'easy' && <Zap className="w-3 h-3 mr-1" />}
                      {diff === 'medium' && <Brain className="w-3 h-3 mr-1" />}
                      {diff === 'hard' && <Target className="w-3 h-3 mr-1" />}
                      {t(`menu.difficulty.${diff}`)}
                    </Button>
                  ))}
                </div>
              </div>

              <div className="p-3 bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.15)] rounded-lg space-y-2">
                <Label className="text-sm font-medium text-[hsl(var(--terminal-green))]">
                  {t('settings.aiSpeed')}
                </Label>
                <div className="flex gap-2">
                  {aiSpeeds.map((speed) => (
                    <Button
                      key={speed}
                      variant={settings.aiSpeed === speed ? 'default' : 'outline'}
                      size="sm"
                      onClick={() => setAiSpeed(speed)}
                      className={cn(
                        'flex-1 text-xs',
                        settings.aiSpeed !== speed && 'border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))] hover:bg-[hsl(var(--terminal-green)/0.1)]'
                      )}
                    >
                      {t(`settings.speed${speed.charAt(0).toUpperCase() + speed.slice(1)}`)}
                    </Button>
                  ))}
                </div>
              </div>
            </section>

            {/* Audio & Sprache */}
            <section className="space-y-3">
              <h3 className="text-sm font-bold uppercase tracking-wider text-[hsl(var(--terminal-cyan))]">
                {t('settings.audioAndLanguage')}
              </h3>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div className="flex items-center justify-between p-3 bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.15)] rounded-lg">
                  <div className="flex items-center gap-2">
                    <Volume2 className="w-4 h-4 text-[hsl(var(--terminal-green))]" />
                    <Label htmlFor="sound" className="text-sm font-medium text-[hsl(var(--terminal-green))]">
                      {t('settings.sound')}
                    </Label>
                  </div>
                  <Switch
                    id="sound"
                    checked={settings.soundEnabled}
                    onCheckedChange={toggleSound}
                    aria-label={t('settings.sound')}
                  />
                </div>

                <div className="flex items-center justify-between p-3 bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.15)] rounded-lg">
                  <div className="flex items-center gap-2">
                    <Music className="w-4 h-4 text-[hsl(var(--terminal-cyan))]" />
                    <Label htmlFor="music" className="text-sm font-medium text-[hsl(var(--terminal-green))]">
                      {t('settings.music')}
                    </Label>
                  </div>
                  <Switch
                    id="music"
                    checked={settings.musicEnabled}
                    onCheckedChange={toggleMusic}
                    aria-label={t('settings.music')}
                  />
                </div>

                <div className="flex items-center justify-between p-3 bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.15)] rounded-lg">
                  <div className="flex items-center gap-2">
                    <Sparkles className="w-4 h-4 text-[hsl(var(--terminal-amber))]" />
                    <Label htmlFor="animations" className="text-sm font-medium text-[hsl(var(--terminal-green))]">
                      {t('settings.animations')}
                    </Label>
                  </div>
                  <Switch
                    id="animations"
                    checked={settings.animationsEnabled}
                    onCheckedChange={toggleAnimations}
                    aria-label={t('settings.animations')}
                  />
                </div>

                <div className="flex items-center justify-between p-3 bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.15)] rounded-lg">
                  <div className="flex items-center gap-2">
                    <Globe className="w-4 h-4 text-[hsl(var(--terminal-cyan))]" />
                    <Label htmlFor="language" className="text-sm font-medium text-[hsl(var(--terminal-green))]">
                      {t('menu.language')}
                    </Label>
                  </div>
                  <select
                    id="language"
                    value={language}
                    onChange={(e) => setLanguage(e.target.value as 'de' | 'en')}
                    className="h-8 px-2 rounded-sm bg-[hsl(var(--terminal-dark))] border border-[hsl(var(--terminal-green)/0.25)] text-[hsl(var(--terminal-green))] text-xs font-mono focus:outline-none focus:ring-1 focus:ring-[hsl(var(--terminal-green)/0.5)]"
                  >
                    <option value="de">Deutsch</option>
                    <option value="en">English</option>
                  </select>
                </div>
              </div>
            </section>

            {/* Zurück-Button */}
            <Button
              onClick={onClose}
              variant="outline"
              className="w-full h-11 font-mono border-[hsl(var(--terminal-green)/0.4)] text-[hsl(var(--terminal-green))] hover:bg-[hsl(var(--terminal-green)/0.1)] hover:text-[hsl(var(--terminal-green))]"
            >
              <ArrowLeft className="w-4 h-4 mr-2" />
              {t('settings.close')}
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
