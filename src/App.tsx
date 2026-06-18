import { useState } from 'react';
import { GameBoard } from '@/components/GameBoard';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { 
  Trash2, 
  Users, 
  Play, 
  BookOpen, 
  Bot,
  User,
  Brain,
  Zap,
  Target,
  Globe
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { useI18n } from '@/lib/i18n';
import type { AIDifficulty } from '@/lib/aiPlayer';

type GameMode = 'menu' | 'game' | 'rules' | 'stats';

interface PlayerConfig {
  name: string;
  isAI: boolean;
  difficulty?: AIDifficulty;
}

const DIFFICULTY_CONFIG: Record<AIDifficulty, { icon: React.ReactNode; color: string; descriptionKey: string }> = {
  easy: { 
    icon: <Zap className="w-4 h-4" />, 
    color: 'bg-[hsl(var(--terminal-green))] text-black',
    descriptionKey: 'Zufällige Züge, wenig Strategie'
  },
  medium: { 
    icon: <Brain className="w-4 h-4" />, 
    color: 'bg-[hsl(var(--terminal-amber))] text-black',
    descriptionKey: 'Grundlegende Strategie, schlechte Karten vermeiden'
  },
  hard: { 
    icon: <Target className="w-4 h-4" />, 
    color: 'bg-[hsl(var(--terminal-red))] text-black',
    descriptionKey: 'Fortgeschrittene Strategie, Bluff, Risikobewertung'
  },
};

function App() {
  const { t, language, setLanguage } = useI18n();
  const [gameMode, setGameMode] = useState<GameMode>('menu');
  const [players, setPlayers] = useState<PlayerConfig[]>([
    { name: 'Spieler 1', isAI: false },
    { name: 'KI-Gegner', isAI: true, difficulty: 'medium' }
  ]);

  // Add human player
  const addHumanPlayer = () => {
    if (players.length < 6) {
      setPlayers([...players, { name: `${t('menu.player')} ${players.filter(p => !p.isAI).length + 1}`, isAI: false }]);
    }
  };

  // Add AI player
  const addAIPlayer = () => {
    if (players.length < 6) {
      const aiCount = players.filter(p => p.isAI).length;
      setPlayers([...players, { 
        name: `KI-${aiCount + 1}`, 
        isAI: true, 
        difficulty: 'medium' 
      }]);
    }
  };

  // Remove player
  const removePlayer = (index: number) => {
    if (players.length > 2) {
      setPlayers(players.filter((_, i) => i !== index));
    }
  };

  // Update player name
  const updatePlayerName = (index: number, name: string) => {
    const newPlayers = [...players];
    newPlayers[index].name = name;
    setPlayers(newPlayers);
  };

  // Update AI difficulty
  const updateAIDifficulty = (index: number, difficulty: AIDifficulty) => {
    const newPlayers = [...players];
    newPlayers[index].difficulty = difficulty;
    setPlayers(newPlayers);
  };

  // Start game
  const startGame = () => {
    if (players.length >= 2) {
      setGameMode('game');
    }
  };

  // Back to menu
  const backToMenu = () => {
    setGameMode('menu');
  };

  // Rules page
  if (gameMode === 'rules') {
    return (
      <div className="min-h-screen terminal-grid relative flex items-center justify-center p-4">
        <div className="max-w-2xl mx-auto w-full">
          <Card className="shadow-2xl bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))]">
            <CardHeader>
              <CardTitle className="text-2xl text-center flex items-center justify-center gap-2 font-mono terminal-glow">
                <BookOpen className="w-7 h-7" />
                {t('rules.title')}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-6 text-sm font-mono">
              <section>
                <h3 className="text-base font-bold mb-2 text-[hsl(var(--terminal-cyan))] uppercase tracking-wider">{t('rules.title')}</h3>
                <p className="text-[hsl(var(--terminal-green)/0.85)]">{t('rules.intro')}</p>
              </section>

              <section>
                <h3 className="text-base font-bold mb-2 text-[hsl(var(--terminal-cyan))] uppercase tracking-wider">Setup</h3>
                <ul className="list-disc list-inside space-y-2 text-[hsl(var(--terminal-green)/0.85)]">
                  <li>{t('rules.setup')}</li>
                  <li>{t('rules.turn')}</li>
                  <li>{t('rules.extraDiscard')}</li>
                </ul>
              </section>

              <section>
                <h3 className="text-base font-bold mb-2 text-[hsl(var(--terminal-cyan))] uppercase tracking-wider">Special cards</h3>
                <div className="space-y-3">
                  <div className="bg-[hsl(var(--terminal-amber)/0.08)] border border-[hsl(var(--terminal-amber)/0.25)] p-3 rounded-sm">
                    <p className="font-bold text-[hsl(var(--terminal-amber))]">{t('rules.jack')}</p>
                  </div>
                  <div className="bg-[hsl(var(--terminal-cyan)/0.08)] border border-[hsl(var(--terminal-cyan)/0.25)] p-3 rounded-sm">
                    <p className="font-bold text-[hsl(var(--terminal-cyan))]">{t('rules.king')}</p>
                  </div>
                  <div className="bg-[hsl(var(--terminal-red)/0.08)] border border-[hsl(var(--terminal-red)/0.25)] p-3 rounded-sm">
                    <p className="font-bold text-[hsl(var(--terminal-red))]">{t('rules.queen')}</p>
                  </div>
                </div>
              </section>

              <section>
                <h3 className="text-base font-bold mb-2 text-[hsl(var(--terminal-cyan))] uppercase tracking-wider">Dame Call</h3>
                <p className="text-[hsl(var(--terminal-green)/0.85)]">{t('rules.dameCall')}</p>
              </section>

              <section>
                <h3 className="text-base font-bold mb-2 text-[hsl(var(--terminal-cyan))] uppercase tracking-wider">Points</h3>
                <p className="text-[hsl(var(--terminal-green)/0.85)]">{t('rules.points')}</p>
              </section>

              <Button onClick={backToMenu} className="w-full font-mono bg-[hsl(var(--terminal-green))] text-black hover:bg-[hsl(var(--terminal-green)/0.85)]">
                {t('rules.close')}
              </Button>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  // Game
  if (gameMode === 'game') {
    return <GameBoard players={players} onBackToMenu={backToMenu} />;
  }

  // Main menu
  return (
    <div className="min-h-screen terminal-grid relative flex items-center justify-center p-4">
      <div className="max-w-lg w-full">
        {/* Logo */}
        <div className="text-center mb-8">
          <h1 className="text-6xl font-mono font-bold text-[hsl(var(--terminal-green))] mb-2 tracking-widest terminal-glow">
            {t('app.title')}
          </h1>
          <p className="text-[hsl(var(--terminal-green)/0.7)] font-mono text-sm uppercase tracking-[0.3em]">
            {t('app.subtitle')}
          </p>
        </div>

        <Card className="shadow-2xl bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.3)]">
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2 font-mono text-[hsl(var(--terminal-green))]">
              <Users className="w-5 h-5" />
              {t('menu.players')} ({players.length}/6)
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {/* Player list */}
            <div className="space-y-2 max-h-[300px] overflow-y-auto pr-1">
              {players.map((player, index) => (
                <div
                  key={index}
                  className={cn(
                    "p-3 rounded-sm border",
                    player.isAI 
                      ? "bg-[hsl(var(--terminal-cyan)/0.05)] border-[hsl(var(--terminal-cyan)/0.2)]" 
                      : "bg-[hsl(var(--terminal-green)/0.05)] border-[hsl(var(--terminal-green)/0.2)]"
                  )}
                >
                  <div className="flex items-center gap-2 mb-2">
                    {player.isAI ? (
                      <Bot className="w-4 h-4 text-[hsl(var(--terminal-cyan))]" />
                    ) : (
                      <User className="w-4 h-4 text-[hsl(var(--terminal-green))]" />
                    )}
                    <Input
                      value={player.name}
                      onChange={(e) => updatePlayerName(index, e.target.value)}
                      className="flex-1 h-10 text-sm font-mono bg-[hsl(var(--terminal-dark))] border-[hsl(var(--terminal-green)/0.25)] text-[hsl(var(--terminal-green))] focus-visible:ring-[hsl(var(--terminal-green)/0.5)]"
                    />
                    {players.length > 2 && (
                      <button
                        onClick={() => removePlayer(index)}
                        className="h-10 w-10 flex items-center justify-center rounded-sm text-[hsl(var(--terminal-red))] hover:text-[hsl(var(--terminal-red)/0.7)] hover:bg-[hsl(var(--terminal-red)/0.1)] transition-colors"
                        aria-label={t('rules.close')}
                      >
                        <Trash2 className="w-5 h-5" />
                      </button>
                    )}
                  </div>
                  
                  {/* AI difficulty */}
                  {player.isAI && (
                    <div className="flex gap-1.5">
                      {(Object.keys(DIFFICULTY_CONFIG) as AIDifficulty[]).map((diff) => (
                        <button
                          key={diff}
                          onClick={() => updateAIDifficulty(index, diff)}
                          className={cn(
                            "flex-1 min-h-9 py-2 px-2 rounded-sm text-xs font-mono font-medium uppercase tracking-wider transition-all border",
                            player.difficulty === diff
                              ? cn(DIFFICULTY_CONFIG[diff].color, "border-transparent")
                              : "bg-[hsl(var(--terminal-dark))] text-[hsl(var(--terminal-green)/0.7)] border-[hsl(var(--terminal-green)/0.2)] hover:border-[hsl(var(--terminal-green)/0.4)]"
                          )}
                          title={DIFFICULTY_CONFIG[diff].descriptionKey}
                        >
                          {t(`menu.difficulty.${diff}`)}
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              ))}
            </div>

            {/* Add player */}
            {players.length < 6 && (
              <div className="flex gap-2">
                <Button 
                  onClick={addHumanPlayer} 
                  variant="outline" 
                  className="flex-1 h-11 font-mono border-[hsl(var(--terminal-green)/0.4)] text-[hsl(var(--terminal-green))] hover:bg-[hsl(var(--terminal-green)/0.1)] hover:text-[hsl(var(--terminal-green))]"
                >
                  <User className="w-4 h-4 mr-1" />
                  {t('menu.addHuman')}
                </Button>
                <Button 
                  onClick={addAIPlayer} 
                  variant="outline" 
                  className="flex-1 h-11 font-mono border-[hsl(var(--terminal-cyan)/0.4)] text-[hsl(var(--terminal-cyan))] hover:bg-[hsl(var(--terminal-cyan)/0.1)] hover:text-[hsl(var(--terminal-cyan))]"
                >
                  <Bot className="w-4 h-4 mr-1" />
                  {t('menu.addAI')}
                </Button>
              </div>
            )}

            {/* Actions */}
            <div className="space-y-2 pt-4">
              <Button
                onClick={startGame}
                className="w-full font-mono bg-[hsl(var(--terminal-green))] text-black hover:bg-[hsl(var(--terminal-green)/0.85)]"
                size="lg"
                disabled={players.length < 2}
              >
                <Play className="w-5 h-5 mr-2" />
                {t('menu.startGame')}
              </Button>
              
              <Button
                onClick={() => setGameMode('rules')}
                variant="outline"
                className="w-full h-11 font-mono border-[hsl(var(--terminal-green)/0.4)] text-[hsl(var(--terminal-green))] hover:bg-[hsl(var(--terminal-green)/0.1)] hover:text-[hsl(var(--terminal-green))]"
              >
                <BookOpen className="w-4 h-4 mr-2" />
                {t('menu.rules')}
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Footer */}
        <div className="mt-8 flex flex-col items-center gap-3">
          <div className="flex items-center gap-2">
            <Globe className="w-4 h-4 text-[hsl(var(--terminal-green)/0.7)]" />
            <select
              value={language}
              onChange={(e) => setLanguage(e.target.value as 'de' | 'en')}
              className="h-9 px-3 rounded-sm bg-[hsl(var(--terminal-panel))] border border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))] text-sm font-mono focus:outline-none focus:ring-1 focus:ring-[hsl(var(--terminal-green)/0.5)]"
              aria-label={t('menu.language')}
            >
              <option value="de">Deutsch</option>
              <option value="en">English</option>
            </select>
          </div>
          <p className="text-center text-[hsl(var(--terminal-green)/0.5)] text-xs font-mono uppercase tracking-wider">
            {t('app.tagline')}
          </p>
        </div>
      </div>
    </div>
  );
}

export default App;
