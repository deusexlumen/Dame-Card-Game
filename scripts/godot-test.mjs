// Startet die Godot-Headless-Tests und prüft das Ergebnis.
// 1) Suites in tests/run_all.tscn  2) echter Szenenfluss tools/flow_smoke.gd
import { spawnSync } from 'node:child_process';

const bin = process.env.GODOT_BIN
  ?? 'C:/Users/Buxe/tools/Godot/Godot_v4.7.2-stable_win64_console.exe';

const runs = [
  { args: ['--headless', '--path', 'godot', 'res://tests/run_all.tscn'], marker: /ALL_TESTS_OK/ },
  { args: ['--headless', '--path', 'godot', '--script', 'res://tools/flow_smoke.gd'], marker: /FLOW_OK/ },
];

let failed = false;
for (const { args, marker } of runs) {
  const run = spawnSync(bin, args, { encoding: 'utf8' });
  process.stdout.write(run.stdout ?? '');
  process.stderr.write(run.stderr ?? '');
  if (run.error) {
    console.error(`Godot nicht startbar: ${run.error.message}`);
    process.exit(1);
  }
  // Skriptfehler beenden Godot nicht immer mit Exit != 0, daher Marker prüfen.
  const output = `${run.stdout}${run.stderr}`;
  const scriptError = /SCRIPT ERROR|Parse Error/.test(output);
  if (run.status !== 0 || scriptError || !marker.test(run.stdout ?? '')) {
    console.error(`Fehlgeschlagen: ${args.join(' ')}`);
    failed = true;
  }
}
process.exit(failed ? 1 : 0);
