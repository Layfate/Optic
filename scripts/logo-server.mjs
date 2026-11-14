// Local, single-asset server used only to register the supplied logo with Studio.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { root } from './modules.mjs';
const data = await readFile(path.join(root, 'assets/optic-logo.png'));
createServer((request, response) => {
  if (request.url !== '/optic-logo.png') { response.writeHead(404).end(); return; }
  response.writeHead(200, { 'Content-Type': 'image/png', 'Content-Length': data.length });
  response.end(data);
}).listen(8766, '127.0.0.1', () => console.log('Optic logo ready at http://127.0.0.1:8766/optic-logo.png'));
