// Minimaler statischer Server fuer den Godot-Web-Export (ohne Abhaengigkeiten).
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';

const root = process.argv[2] ?? 'build/web';
const port = Number(process.argv[3] ?? 8060);
const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.json': 'application/json',
};

createServer(async (req, res) => {
  const url = decodeURIComponent((req.url ?? '/').split('?')[0]);
  const rel = normalize(url === '/' ? '/index.html' : url).replace(/^([/\])+/, '');
  if (rel.startsWith('..')) {
    res.writeHead(403).end();
    return;
  }
  try {
    const body = await readFile(join(root, rel));
    res.writeHead(200, { 'Content-Type': types[extname(rel)] ?? 'application/octet-stream' });
    res.end(body);
  } catch {
    res.writeHead(404).end('Nicht gefunden');
  }
}).listen(port, () => console.log(`Serving ${root} on http://localhost:${port}`));
