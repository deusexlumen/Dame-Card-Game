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
  Target
} from 'lucide-react';
import { cn } from '@/lib/utils';
import type { AIDifficulty } from '@/lib/aiPlayer';

type GameMode = 'menu' | 'game' | 'rules' | 'stats';

interface PlayerConfig {
  name: string;
  isAI: boolean;
  difficulty?: AIDifficulty;
}

const DIFFICULTY_CONFIG: Record<AIDifficulty, { label: string; icon: React.ReactNode; color: string; description: string }> = {
  easy: { 
    label: 'Einfach', 
    icon: <Zap className="w-4 h-4" />, 
    color: 'bg-[hsl(var(--terminal-green))] text-black',
    description: 'Zufällige Züge, wenig Strategie'
  },
  medium: { 
    label: 'Mittel', 
    icon: <Brain className="w-4 h-4" />, 
    color: 'bg-[hsl(var(--terminal-amber))] text-black',
    description: 'Grundlegende Strategie, schlechte Karten vermeiden'
  },
  hard: { 
    label: 'Schwer', 
    icon: <Target className="w-4 h-4" />, 
    color: 'bg-[hsl(var(--terminal-red))] text-black',
    description: 'Fortgeschrittene Strategie, Bluff, Risikobewertung'
  },
};

function App() {
  const [gameMode, setGameMode] = useState<GameMode>('menu');
  const [players, setPlayers] = useState<PlayerConfig[]>([
    { name: 'Spieler 1', isAI: false },
    { name: 'KI-Gegner', isAI: true, difficulty: 'medium' }
  ]);
// App.tsx - Dame Kartenspiel mit KI-Gegnern

  // Spieler hinzufügen (menschlich)
  const addHumanPlayer = () => {
    if (players.length < 6) {
      setPlayers([...players, { name: `Spieler ${players.filter(p => !p.isAI).length + 1}`, isAI: false }]);
    }
  };

  // KI-Spieler hinzufügen
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

  // Spieler entfernen
  const removePlayer = (index: number) => {
    if (players.length > 2) {
      setPlayers(players.filter((_, i) => i !== index));
    }
  };

  // Spieler-Namen ändern
  const updatePlayerName = (index: number, name: string) => {
    const newPlayers = [...players];
    newPlayers[index].name = name;
    setPlayers(newPlayers);
  };

  // KI-Schwierigkeit ändern
  const updateAIDifficulty = (index: number, difficulty: AIDifficulty) => {
    const newPlayers = [...players];
    newPlayers[index].difficulty = difficulty;
    setPlayers(newPlayers);
  };

  // Spiel starten
  const startGame = () => {
    if (players.length >= 2) {
      setGameMode('game');
    }
  };

  // Zurück zum Menü
  const backToMenu = () => {
    setGameMode('menu');
  };

  // Regeln anzeigen
  if (gameMode === 'rules') {
    return (
      <div className="min-h-screen terminal-grid relative flex items-center justify-center p-4">
        <div className="max-w-2xl mx-auto w-full">
          <Card className="shadow-2xl bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))]">
            <CardHeader>
              <CardTitle className="text-2xl text-center flex items-center justify-center gap-2 font-mono terminal-glow">
                <BookOpen className="w-7 h-7" />
                Spielregeln
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-6 text-sm font-mono">
              <section>
                <h3 className="text-base font-bold mb-2 text-[hsl(var(--terminal-cyan))] uppercase tracking-wider">Ziel des Spiels</h3>
                <p className="text-[hsl(var(--terminal-green)/0.85)]">
                  Sammle möglichst wenige Punkte! Wer über 50 Punkte kommt, scheidet aus. 
                  Aber Achtung: Wer genau 50 Punkte erreicht, fällt auf 0 zurück!
                </p>
              </section>

              <section>
                <h3 className="text-base font-bold mb-2 text-[hsl(var(--terminal-cyan))] uppercase tracking-wider">Spielablauf</h3>
                <ul className="list-disc list-inside space-y-2 text-[hsl(var(--terminal-green)/0.85)]">
                  <li>Jeder Spieler bekommt 4 verdeckte Karten</li>
                  <li>Du darfst dir nur 2 deiner Karten anschauen</li>
                  <li>Ziehe eine Karte vom Ziehstapel oder Ablagestapel</li>
                  <li>Tausche die gezogene Karte mit einer deiner Handkarten</li>
                  <li>Die abgelegte Karte kommt auf den Ablagestapel</li>
                </ul>
              </section>

              <section>
                <h3 className="text-base font-bold mb-2 text-[hsl(var(--terminal-cyan))] uppercase tracking-wider">Besondere Karten</h3>
                <div className="space-y-3">
                  <div className="bg-[hsl(var(--terminal-amber)/0.08)] border border-[hsl(var(--terminal-amber)/0.25)] p-3 rounded-sm">
                    <p className="font-bold text-[hsl(var(--terminal-amber))]">Bube (10 Punkte)</p>
                    <p className="text-[hsl(var(--terminal-green)/0.85)]">Wenn abgelegt: Du darfst dir eine verdeckte Karte anschauen.</p>
                  </div>
                  <div className="bg-[hsl(var(--terminal-cyan)/0.08)] border border-[hsl(var(--terminal-cyan)/0.25)] p-3 rounded-sm">
                    <p className="font-bold text-[hsl(var(--terminal-cyan))]">König (10 Punkte)</p>
                    <p className="text-[hsl(var(--terminal-green)/0.85)]">Wenn abgelegt: Tausche blind eine deiner Karten mit einem Gegner.</p>
                  </div>
                  <div className="bg-[hsl(var(--terminal-red)/0.08)] border border-[hsl(var(--terminal-red)/0.25)] p-3 rounded-sm">
                    <p className="font-bold text-[hsl(var(--terminal-red))]">Dame (0 Punkte)</p>
                    <p className="text-[hsl(var(--terminal-green)/0.85)]">Wenn abgelegt: Du musst eine Strafkarte ziehen! Die Dame ist verflucht...</p>
                  </div>
                </div>
              </section>

              <section>
                <h3 className="text-base font-bold mb-2 text-[hsl(var(--terminal-cyan))] uppercase tracking-wider">Dame Call</h3>
                <p className="text-[hsl(var(--terminal-green)/0.85)]">
                  Ab Runde 3 kannst du "Dame" rufen, wenn du glaubst, die wenigsten Punkte zu haben. 
                  Nach einer letzten Runde werden alle Karten aufgedeckt. Wenn du recht hattest, 
                  gewinnst du die Runde. Wenn nicht, bekommst du eine Strafkarte!
                </p>
              </section>

              <section>
                <h3 className="text-base font-bold mb-2 text-[hsl(var(--terminal-cyan))] uppercase tracking-wider">KI-Gegner</h3>
                <div className="space-y-2 text-[hsl(var(--terminal-green)/0.85)]">
                  <div className="flex items-center gap-2">
                    <span className="w-3 h-3 rounded-sm bg-[hsl(var(--terminal-green))]"></span>
                    <span className="font-medium">Einfach:</span>
                    <span className="text-[hsl(var(--terminal-green)/0.7)] text-xs">Zufällige Züge, wenig Strategie</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="w-3 h-3 rounded-sm bg-[hsl(var(--terminal-amber))]"></span>
                    <span className="font-medium">Mittel:</span>
                    <span className="text-[hsl(var(--terminal-green)/0.7)] text-xs">Grundlegende Strategie, schlechte Karten vermeiden</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="w-3 h-3 rounded-sm bg-[hsl(var(--terminal-red))]"></span>
                    <span className="font-medium">Schwer:</span>
                    <span className="text-[hsl(var(--terminal-green)/0.7)] text-xs">Fortgeschrittene Strategie mit Bluff und Risikobewertung</span>
                  </div>
                </div>
              </section>

              <Button onClick={backToMenu} className="w-full font-mono bg-[hsl(var(--terminal-green))] text-black hover:bg-[hsl(var(--terminal-green)/0.85)]">
                Zurück zum Menü
              </Button>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  // Spiel
  if (gameMode === 'game') {
    return <GameBoard players={players} onBackToMenu={backToMenu} />;
  }

  // Hauptmenü
  return (
    <div className="min-h-screen terminal-grid relative flex items-center justify-center p-4">
      <div className="max-w-lg w-full">
        {/* Logo */}
        <div className="text-center mb-8">
          <h1 className="text-6xl font-mono font-bold text-[hsl(var(--terminal-green))] mb-2 tracking-widest terminal-glow">
            DAME
          </h1>
          <p className="text-[hsl(var(--terminal-green)/0.7)] font-mono text-sm uppercase tracking-[0.3em]">
            Kartenspiel mit Bluff und Strategie
          </p>
        </div>

        <Card className="shadow-2xl bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.3)]">
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2 font-mono text-[hsl(var(--terminal-green))]">
              <Users className="w-5 h-5" />
              Spieler ({players.length}/6)
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {/* Spieler-Liste */}
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
                        aria-label="Spieler entfernen"
                      >
                        <Trash2 className="w-5 h-5" />
                      </button>
                    )}
                  </div>
                  
                  {/* KI-Schwierigkeit */}
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
                          title={DIFFICULTY_CONFIG[diff].description}
                        >
                          {DIFFICULTY_CONFIG[diff].label}
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              ))}
            </div>

            {/* Spieler hinzufügen */}
            {players.length < 6 && (
              <div className="flex gap-2">
                <Button 
                  onClick={addHumanPlayer} 
                  variant="outline" 
                  className="flex-1 h-11 font-mono border-[hsl(var(--terminal-green)/0.4)] text-[hsl(var(--terminal-green))] hover:bg-[hsl(var(--terminal-green)/0.1)] hover:text-[hsl(var(--terminal-green))]"
                >
                  <User className="w-4 h-4 mr-1" />
                  Mensch
                </Button>
                <Button 
                  onClick={addAIPlayer} 
                  variant="outline" 
                  className="flex-1 h-11 font-mono border-[hsl(var(--terminal-cyan)/0.4)] text-[hsl(var(--terminal-cyan))] hover:bg-[hsl(var(--terminal-cyan)/0.1)] hover:text-[hsl(var(--terminal-cyan))]"
                >
                  <Bot className="w-4 h-4 mr-1" />
                  KI
                </Button>
              </div>
            )}

            {/* Aktionen */}
            <div className="space-y-2 pt-4">
              <Button
                onClick={startGame}
                className="w-full font-mono bg-[hsl(var(--terminal-green))] text-black hover:bg-[hsl(var(--terminal-green)/0.85)]"
                size="lg"
                disabled={players.length < 2}
              >
                <Play className="w-5 h-5 mr-2" />
                Spiel starten
              </Button>
              
              <Button
                onClick={() => setGameMode('rules')}
                variant="outline"
                className="w-full h-11 font-mono border-[hsl(var(--terminal-green)/0.4)] text-[hsl(var(--terminal-green))] hover:bg-[hsl(var(--terminal-green)/0.1)] hover:text-[hsl(var(--terminal-green))]"
              >
                <BookOpen className="w-4 h-4 mr-2" />
                Regeln
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Footer */}
        <p className="text-center text-[hsl(var(--terminal-green)/0.5)] text-xs font-mono mt-8 uppercase tracking-wider">
          Ein Spiel für 2-6 Spieler • Mit KI-Gegnern!
        </p>
      </div>
    </div>
  );
}

export default App;
