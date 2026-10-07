// Laedt webrtc-native (GDExtension, MIT) nach godot/addons/webrtc/.
// Wird nicht ins Repo eingecheckt. Noetig fuer WebRTC unter Windows/Linux
// (im Browser-Export ist WebRTC eingebaut). Aufruf: npm run fetch:webrtc
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import {
  copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync,
  rmSync, writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const VERSION = '1.2.2-stable';
const ASSET = 'godot-extension-webrtc_native.zip';
const SHA256 = '98e9446921740d995bd9ca1be48798dc3c2ceed51e044a25ce18b3cff11f56e5';
const URL = `https://github.com/godotengine/webrtc-native/releases/download/${VERSION}/${ASSET}`;

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const target = join(root, 'godot', 'addons', 'webrtc');
const marker = join(target, '.version');
const force = process.argv.includes('--force');

// Nur diese Bibliotheken werden uebernommen (Windows + Linux, x86_64).
const LIBS = [
  'libwebrtc_native.windows.template_debug.x86_64.dll',
  'libwebrtc_native.windows.template_release.x86_64.dll',
  'libwebrtc_native.linux.template_debug.x86_64.so',
  'libwebrtc_native.linux.template_release.x86_64.so',
];

function fail(msg) {
  console.error(`fetch-webrtc: ${msg}`);
  process.exit(1);
}

function complete() {
  return existsSync(marker)
    && readFileSync(marker, 'utf8').trim() === `${VERSION} ${SHA256}`
    && existsSync(join(target, 'webrtc_native.gdextension'))
    && LIBS.every((l) => existsSync(join(target, 'lib', l)));
}

if (!force && complete()) {
  console.log(`fetch-webrtc: webrtc-native ${VERSION} vorhanden, uebersprungen.`);
  process.exit(0);
}

const tmp = mkdtempSync(join(tmpdir(), 'webrtc-native-'));
try {
  const zip = join(tmp, ASSET);
  const out = join(tmp, 'x');
  mkdirSync(out);

  console.log(`fetch-webrtc: lade ${URL}`);
  const dl = spawnSync('curl', ['-fL', '--retry', '3', '-sS', '-o', zip, URL], { stdio: 'inherit' });
  if (dl.status !== 0) fail('Download fehlgeschlagen (curl).');

  const sha = createHash('sha256').update(readFileSync(zip)).digest('hex');
  if (sha !== SHA256) fail(`SHA-256 stimmt nicht.\n  erwartet ${SHA256}\n  erhalten ${sha}`);
  console.log('fetch-webrtc: SHA-256 ok.');

  let ex = spawnSync('unzip', ['-q', zip, '-d', out], { stdio: 'inherit' });
  if (ex.error || ex.status !== 0) {
    ex = spawnSync('tar', ['-xf', zip, '-C', out], { stdio: 'inherit' });
  }
  if (ex.error || ex.status !== 0) fail('Entpacken fehlgeschlagen (unzip/tar).');

  const src = join(out, 'addons', 'webrtc_native');
  if (!existsSync(src)) fail('Unerwartetes Archivlayout (addons/webrtc_native fehlt).');
  const license = join(src, 'LICENSE.webrtc-native');
  if (!/^MIT License/.test(readFileSync(license, 'utf8'))) fail('Lizenz ist nicht MIT, abgebrochen.');

  // README.md bleibt (eingecheckt); alles andere wird ersetzt.
  for (const n of existsSync(target) ? readdirSync(target) : []) {
    if (n !== 'README.md') rmSync(join(target, n), { recursive: true, force: true });
  }
  mkdirSync(join(target, 'lib'), { recursive: true });
  for (const l of LIBS) {
    if (!existsSync(join(src, 'lib', l))) fail(`Bibliothek fehlt im Archiv: ${l}`);
    copyFileSync(join(src, 'lib', l), join(target, 'lib', l));
  }
  for (const f of readdirSync(src).filter((n) => n.startsWith('LICENSE'))) {
    copyFileSync(join(src, f), join(target, f));
  }

  // .gdextension auf die kopierten Bibliotheken kuerzen (Pfade bleiben gleich).
  const kept = readFileSync(join(src, 'webrtc_native.gdextension'), 'utf8')
    .split(/\r?\n/)
    .filter((line) => {
      const m = line.match(/"lib\/([^"]+)"/);
      return !m || LIBS.includes(m[1]);
    })
    .join('\n')
    .replace(/\n{3,}/g, '\n\n');
  writeFileSync(join(target, 'webrtc_native.gdextension'), kept);

  writeFileSync(marker, `${VERSION} ${SHA256}\n`);
  console.log(`fetch-webrtc: webrtc-native ${VERSION} nach godot/addons/webrtc/ kopiert.`);
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
