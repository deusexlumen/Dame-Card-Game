// Exportiert Windows- und Web-Build und prüft beide.
// Aufruf: node scripts/godot-export.mjs [--skip-smoke]
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const bin = process.env.GODOT_BIN
  ?? 'C:/Users/Buxe/tools/Godot/Godot_v4.7.2-stable_win64_console.exe';
const skipSmoke = process.argv.includes('--skip-smoke');

const presets = [
  { name: 'Windows Desktop', out: 'build/windows/Dame.exe' },
  { name: 'Web', out: 'build/web/index.html' },
];

function fail(msg) {
  console.error(`EXPORT_FAIL ${msg}`);
  process.exit(1);
}

for (const { name, out } of presets) {
  mkdirSync(join(out, '..'), { recursive: true });
  const run = spawnSync(bin, ['--headless', '--path', 'godot', '--export-release', name, `../${out}`], {
    encoding: 'utf8',
  });
  const log = `${run.stdout ?? ''}${run.stderr ?? ''}`;
  if (run.error) fail(`Godot nicht startbar: ${run.error.message}`);
  if (run.status !== 0 || /SCRIPT ERROR|Parse Error/.test(log)) {
    process.stdout.write(log);
    fail(`${name}: Export mit Status ${run.status}`);
  }
  if (!existsSync(out) || statSync(out).size === 0) fail(`${name}: ${out} fehlt`);
  console.log(`EXPORTED ${name} -> ${out} (${(statSync(out).size / 1e6).toFixed(1)} MB)`);
}

const webFiles = readdirSync('build/web');
for (const ext of ['.wasm', '.pck', '.js']) {
  if (!webFiles.some((f) => f.endsWith(ext))) fail(`Web: keine ${ext}-Datei`);
}

if (!skipSmoke && process.platform === 'win32') {
  // Release-Exe startet headless, laedt das Menue und beendet sich selbst.
  const started = Date.now();
  const run = spawnSync('build/windows/Dame.exe', ['--headless', '--quit-after', '240'], {
    encoding: 'utf8',
    timeout: 60000,
  });
  let out = `${run.stdout ?? ''}${run.stderr ?? ''}`;
  if (!out.includes('DAME_READY')) {
    // GUI-Exe schreibt evtl. nicht auf die Konsole: Godot-Log lesen.
    const logFile = join(process.env.APPDATA ?? '', 'Godot/app_userdata/Dame/logs/godot.log');
    if (existsSync(logFile) && statSync(logFile).mtimeMs >= started - 1000) {
      out += readFileSync(logFile, 'utf8');
    }
  }
  if (run.status !== 0) fail(`Windows-Exe endet mit Status ${run.status}`);
  if (/SCRIPT ERROR/.test(out)) fail('Windows-Exe meldet Skriptfehler');
  if (!out.includes('DAME_READY')) fail('Windows-Exe meldet kein DAME_READY');
  console.log('SMOKE_OK Windows');
}
console.log('EXPORT_OK');
