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
  // Ein Skriptfehler bricht nur die laufende Testfunktion ab; die Marker kommen
  // trotzdem. Deshalb zaehlt jeder SCRIPT ERROR / Parse Error als Fehlschlag.
  const errorLines = output.split(/\r?\n/).filter((l) => /SCRIPT ERROR|Parse Error/.test(l));
  if (errorLines.length > 0) {
    console.error(`TEST_FAIL runner: ${errorLines.length} Skriptfehler trotz Erfolgsmarker (${args.join(' ')})`);
    for (const l of errorLines.slice(0, 10)) console.error(`  ${l.trim()}`);
  }
  if (!marker.test(run.stdout ?? '')) {
    console.error(`TEST_FAIL runner: Marker ${marker} fehlt (${args.join(' ')})`);
  }
  if (run.status !== 0 || errorLines.length > 0 || !marker.test(run.stdout ?? '')) {
    console.error(`Fehlgeschlagen: ${args.join(' ')} (Exit ${run.status})`);
    failed = true;
  }
}
process.exit(failed ? 1 : 0);
