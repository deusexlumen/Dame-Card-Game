// Startet die Godot-Headless-Tests und prüft das Ergebnis.
import { spawnSync } from 'node:child_process';

const bin = process.env.GODOT_BIN
  ?? 'C:/Users/Buxe/tools/Godot/Godot_v4.7.2-stable_win64_console.exe';
const scene = process.argv[2] ?? 'res://tests/run_all.tscn';

const run = spawnSync(bin, ['--headless', '--path', 'godot', scene], {
  encoding: 'utf8',
});
process.stdout.write(run.stdout ?? '');
process.stderr.write(run.stderr ?? '');

if (run.error) {
  console.error(`Godot nicht startbar: ${run.error.message}`);
  process.exit(1);
}
// Skriptfehler beenden Godot nicht immer mit Exit != 0, daher Marker prüfen.
const scriptError = /SCRIPT ERROR|Parse Error/.test(`${run.stdout}${run.stderr}`);
const ok = run.status === 0 && !scriptError && /ALL_TESTS_OK/.test(run.stdout ?? '');
process.exit(ok ? 0 : 1);
