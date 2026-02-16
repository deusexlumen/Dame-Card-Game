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
  Trophy, 
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
    color: 'bg-green-500',
    description: 'Zufällige Züge, wenig Strategie'
  },
  medium: { 
    label: 'Mittel', 
    icon: <Brain className="w-4 h-4" />, 
    color: 'bg-yellow-500',
    description: 'Grundlegende Strategie, schlechte Karten vermeiden'
  },
  hard: { 
    label: 'Schwer', 
    icon: <Target className="w-4 h-4" />, 
    color: 'bg-red-500',
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
      <div className="min-h-screen bg-gradient-to-br from-slate-900 to-slate-800 p-4">
        <div className="max-w-2xl mx-auto">
          <Card className="shadow-2xl">
            <CardHeader>
              <CardTitle className="text-3xl text-center flex items-center justify-center gap-2">
                <BookOpen className="w-8 h-8" />
                Spielregeln
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
              <section>
                <h3 className="text-xl font-bold mb-2 text-blue-600">Ziel des Spiels</h3>
                <p className="text-slate-700">
                  Sammle möglichst wenige Punkte! Wer über 50 Punkte kommt, scheidet aus. 
                  Aber Achtung: Wer genau 50 Punkte erreicht, fällt auf 0 zurück!
                </p>
              </section>

              <section>
                <h3 className="text-xl font-bold mb-2 text-blue-600">Spielablauf</h3>
                <ul className="list-disc list-inside space-y-2 text-slate-700">
                  <li>Jeder Spieler bekommt 4 verdeckte Karten</li>
                  <li>Du darfst dir nur 2 deiner Karten anschauen</li>
                  <li>Ziehe eine Karte vom Ziehstapel oder Ablagestapel</li>
                  <li>Tausche die gezogene Karte mit einer deiner Handkarten</li>
                  <li>Die abgelegte Karte kommt auf den Ablagestapel</li>
                </ul>
              </section>

              <section>
                <h3 className="text-xl font-bold mb-2 text-blue-600">Besondere Karten</h3>
                <div className="space-y-3">
                  <div className="bg-yellow-50 p-3 rounded-lg">
                    <p className="font-bold text-yellow-700">Bube (10 Punkte)</p>
                    <p className="text-slate-700">Wenn abgelegt: Du darfst dir eine deiner verdeckten Karten anschauen.</p>
                  </div>
                  <div className="bg-purple-50 p-3 rounded-lg">
                    <p className="font-bold text-purple-700">König (10 Punkte)</p>
                    <p className="text-slate-700">Wenn abgelegt: Tausche blind eine deiner Karten mit einem Gegner.</p>
                  </div>
                  <div className="bg-red-50 p-3 rounded-lg">
                    <p className="font-bold text-red-700">Dame (0 Punkte)</p>
                    <p className="text-slate-700">Wenn abgelegt: Du musst eine Strafkarte ziehen! Die Dame ist verflucht...</p>
                  </div>
                </div>
              </section>

              <section>
                <h3 className="text-xl font-bold mb-2 text-blue-600">Dame Call</h3>
                <p className="text-slate-700">
                  Ab Runde 3 kannst du "Dame" rufen, wenn du glaubst, die wenigsten Punkte zu haben. 
                  Nach einer letzten Runde werden alle Karten aufgedeckt. Wenn du recht hattest, 
                  gewinnst du die Runde. Wenn nicht, bekommst du eine Strafkarte!
                </p>
              </section>

              <section>
                <h3 className="text-xl font-bold mb-2 text-blue-600">KI-Gegner</h3>
                <div className="space-y-2">
                  <div className="flex items-center gap-2">
                    <span className="w-3 h-3 rounded-full bg-green-500"></span>
                    <span className="font-medium">Einfach:</span>
                    <span className="text-slate-600 text-sm">Zufällige Züge, wenig Strategie</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="w-3 h-3 rounded-full bg-yellow-500"></span>
                    <span className="font-medium">Mittel:</span>
                    <span className="text-slate-600 text-sm">Grundlegende Strategie, schlechte Karten vermeiden</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="w-3 h-3 rounded-full bg-red-500"></span>
                    <span className="font-medium">Schwer:</span>
                    <span className="text-slate-600 text-sm">Fortgeschrittene Strategie mit Bluff und Risikobewertung</span>
                  </div>
                </div>
              </section>

              <Button onClick={backToMenu} className="w-full">
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
    <div className="min-h-screen bg-gradient-to-br from-slate-900 to-slate-800 flex items-center justify-center p-4">
      <div className="max-w-lg w-full">
        {/* Logo */}
        <div className="text-center mb-8">
          <h1 className="text-6xl font-bold text-white mb-2 tracking-tight">
            <span className="text-red-500">D</span>
            <span className="text-white">a</span>
            <span className="text-red-500">m</span>
            <span className="text-white">e</span>
          </h1>
          <p className="text-slate-400">Das Kartenspiel mit Bluff und Strategie</p>
        </div>

        <Card className="shadow-2xl">
          <CardHeader>
            <CardTitle className="text-xl flex items-center gap-2">
              <Users className="w-5 h-5" />
              Spieler ({players.length}/6)
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {/* Spieler-Liste */}
            <div className="space-y-2 max-h-[300px] overflow-y-auto">
              {players.map((player, index) => (
                <div
                  key={index}
                  className={cn(
                    "p-3 rounded-lg border-2",
                    player.isAI 
                      ? "bg-purple-50 border-purple-200" 
                      : "bg-blue-50 border-blue-200"
                  )}
                >
                  <div className="flex items-center gap-2 mb-2">
                    {player.isAI ? (
                      <Bot className="w-4 h-4 text-purple-600" />
                    ) : (
                      <User className="w-4 h-4 text-blue-600" />
                    )}
                    <Input
                      value={player.name}
                      onChange={(e) => updatePlayerName(index, e.target.value)}
                      className="flex-1 h-8 text-sm"
                    />
                    {players.length > 2 && (
                      <button
                        onClick={() => removePlayer(index)}
                        className="text-red-500 hover:text-red-700 transition-colors"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    )}
                  </div>
                  
                  {/* KI-Schwierigkeit */}
                  {player.isAI && (
                    <div className="flex gap-1">
                      {(Object.keys(DIFFICULTY_CONFIG) as AIDifficulty[]).map((diff) => (
                        <button
                          key={diff}
                          onClick={() => updateAIDifficulty(index, diff)}
                          className={cn(
                            "flex-1 py-1 px-2 rounded text-xs font-medium transition-all",
                            player.difficulty === diff
                              ? cn(DIFFICULTY_CONFIG[diff].color, "text-white")
                              : "bg-slate-200 text-slate-600 hover:bg-slate-300"
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
                  className="flex-1"
                  size="sm"
                >
                  <User className="w-4 h-4 mr-1" />
                  Mensch
                </Button>
                <Button 
                  onClick={addAIPlayer} 
                  variant="outline" 
                  className="flex-1"
                  size="sm"
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
                className="w-full"
                size="lg"
                disabled={players.length < 2}
              >
                <Play className="w-5 h-5 mr-2" />
                Spiel starten
              </Button>
              
              <div className="flex gap-2">
                <Button
                  onClick={() => setGameMode('rules')}
                  variant="outline"
                  className="flex-1"
                >
                  <BookOpen className="w-4 h-4 mr-2" />
                  Regeln
                </Button>
                <Button
                  variant="outline"
                  className="flex-1"
                  disabled
                >
                  <Trophy className="w-4 h-4 mr-2" />
                  Statistik
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Footer */}
        <p className="text-center text-slate-500 text-sm mt-8">
          Ein Spiel für 2-6 Spieler • Mit KI-Gegnern!
        </p>
      </div>
    </div>
  );
}

export default App;
