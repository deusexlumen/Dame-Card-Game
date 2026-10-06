// Startet den Online-Server headless (Port per --port=, Standard 8910).
import { spawn } from 'node:child_process';

const bin = process.env.GODOT_BIN
  ?? 'C:/Users/Buxe/tools/Godot/Godot_v4.7.2-stable_win64_console.exe';
const port = process.argv.find((a) => a.startsWith('--port='))?.slice(7) ?? '8910';

const child = spawn(bin, ['--headless', '--path', 'godot', 'res://scenes/server.tscn', '--', `--port=${port}`], { stdio: 'inherit' });
child.on('exit', (code) => process.exit(code ?? 0));
